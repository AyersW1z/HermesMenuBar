import Foundation

final class ACPClient: HermesClientProtocol {
    private let transport = ACPTransport()

    func createSession(cwd: String) async throws -> String {
        try await transport.createSession(cwd: cwd)
    }

    func listSessions() async throws -> [ACPAvailableSession] {
        try await transport.listSessions()
    }

    func loadSession(sessionId: String, cwd: String) async throws -> Bool {
        try await transport.loadSession(sessionId: sessionId, cwd: cwd)
    }

    func sendMessage(_ payload: HermesPromptPayload, requestID: String, sessionId: String?, cwd: String, onEvent: @Sendable @escaping (HermesStreamEvent) -> Void) async throws -> HermesSendResult {
        try await transport.sendPromptOneShot(
            payload,
            requestID: requestID,
            preferredSessionId: sessionId,
            cwd: cwd,
            onStream: onEvent
        )
    }

    func cancel(requestID: String, sessionId: String?) async {
        await transport.cancel(requestID: requestID, sessionId: sessionId)
    }

    func deleteSession(sessionId: String) async throws -> Bool {
        try await transport.deletePersistentSession(sessionId: sessionId)
    }
}

private actor ACPTransport {
    typealias JSON = [String: Any]
    typealias StreamHandler = @Sendable (HermesStreamEvent) -> Void

    private let promptInactivityTimeout: TimeInterval = 180
    private var process: Process?
    private var inputHandle: FileHandle?
    private var stdoutTask: Task<Void, Never>?
    private var stderrTask: Task<Void, Never>?
    private var responseWaiters: [Int: CheckedContinuation<JSON, Error>] = [:]
    private var nextRequestID = 1
    private var isInitialized = false
    private var recentStderr: [String] = []
    private var oneShotRequests: [String: OneShotPromptState] = [:]

    deinit {
        process?.terminate()
    }

    func createSession(cwd: String) async throws -> String {
        let result = try await request(
            method: "session/new",
            params: [
                "cwd": cwd,
                "mcpServers": []
            ]
        )

        if let sessionID = result["sessionId"] as? String ?? result["session_id"] as? String {
            return sessionID
        }

        throw ACPError.invalidResponse("ACP did not return a session ID.")
    }

    func listSessions() async throws -> [ACPAvailableSession] {
        let result = try await request(method: "session/list", params: [:])
        guard let sessions = result["sessions"] as? [[String: Any]] else {
            return []
        }

        return sessions.compactMap { item in
            guard let sessionID = item["sessionId"] as? String ?? item["session_id"] as? String,
                  let cwd = item["cwd"] as? String else {
                return nil
            }
            return ACPAvailableSession(id: sessionID, cwd: cwd)
        }
    }

    func loadSession(sessionId: String, cwd: String) async throws -> Bool {
        _ = try await request(
            method: "session/load",
            params: [
                "sessionId": sessionId,
                "cwd": cwd,
                "mcpServers": []
            ]
        )
        return true
    }

    func sendPromptOneShot(
        _ payload: HermesPromptPayload,
        requestID: String,
        preferredSessionId: String?,
        cwd: String,
        onStream: @escaping StreamHandler
    ) async throws -> HermesSendResult {
        let hermesPath = try findHermesExecutable()
        let promptBlocks = buildPromptBlocks(from: payload)
        let inactivityTimeout = promptInactivityTimeout
        let requestState = OneShotPromptState()
        oneShotRequests[requestID] = requestState

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: hermesPath)
                    process.arguments = ["acp"]

                    let inputPipe = Pipe()
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.standardInput = inputPipe
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe

                    try process.run()

                    let inputHandle = inputPipe.fileHandleForWriting
                    let outputHandle = outputPipe.fileHandleForReading
                    let errorHandle = errorPipe.fileHandleForReading
                    requestState.attach(process: process, errorHandle: errorHandle)

                    var nextRequestId = 1
                    var bufferedOutput = ""
                    var aggregatedMessageText = ""
                    var finalSessionId = preferredSessionId ?? ""

                    func parseToolEvent(_ update: [String: Any]) -> HermesToolCallEvent? {
                        guard let toolCallId = update["toolCallId"] as? String ?? update["tool_call_id"] as? String else {
                            return nil
                        }

                        let title = update["title"] as? String ?? "Tool Call"
                        let kind = update["kind"] as? String ?? "other"
                        let status = update["status"] as? String
                        let rawOutput = update["rawOutput"] as? String ?? update["raw_output"] as? String

                        let content: String
                        if let rawOutput {
                            content = rawOutput
                        } else if let items = update["content"] as? [[String: Any]] {
                            content = items.compactMap { item in
                                if let nested = item["content"] as? [String: Any] {
                                    return nested["text"] as? String
                                }
                                return item["text"] as? String
                            }.joined(separator: "\n")
                        } else {
                            content = ""
                        }

                        return HermesToolCallEvent(
                            id: toolCallId,
                            title: title,
                            kind: kind,
                            content: content,
                            status: status
                        )
                    }

                    func send(_ method: String, params: [String: Any], expectsResponse: Bool = true) throws -> Int? {
                        let requestId = expectsResponse ? nextRequestId : nil
                        if expectsResponse {
                            nextRequestId += 1
                        }

                        var body: [String: Any] = [
                            "jsonrpc": "2.0",
                            "method": method,
                            "params": params
                        ]
                        if let requestId {
                            body["id"] = requestId
                        }

                        let data = try JSONSerialization.data(withJSONObject: body)
                        inputHandle.write(data)
                        inputHandle.write(Data([0x0A]))
                        return requestId
                    }

                    func emitUpdate(_ update: [String: Any]) {
                        requestState.markActivity()
                        let kind = update["sessionUpdate"] as? String ?? update["session_update"] as? String ?? ""
                        let content = update["content"] as? [String: Any] ?? [:]
                        let chunkText = content["text"] as? String ?? ""

                        switch kind {
                        case "agent_message_chunk":
                            guard !chunkText.isEmpty else { return }
                            aggregatedMessageText += chunkText
                            onStream(.messageChunk(chunkText))

                        case "agent_thought_chunk":
                            guard !chunkText.isEmpty else { return }
                            onStream(.thoughtChunk(chunkText))

                        case "tool_call":
                            if let event = parseToolEvent(update) {
                                onStream(.toolCallStarted(event))
                            }

                        case "tool_call_update":
                            if let event = parseToolEvent(update) {
                                onStream(.toolCallUpdated(event))
                            }

                        default:
                            return
                        }
                    }

                    func readLines(timeout: TimeInterval, targetResponseId: Int?) throws -> [String: Any] {
                        while true {
                            if requestState.isCancelled {
                                throw ACPError.transportError("ACP 请求已取消。")
                            }

                            let data = outputHandle.availableData
                            if data.isEmpty {
                                if process.isRunning {
                                    if requestState.secondsSinceLastActivity() > timeout {
                                        throw ACPError.transportError("ACP 响应超时")
                                    }
                                    Thread.sleep(forTimeInterval: 0.05)
                                    continue
                                }
                                break
                            }

                            requestState.markActivity()
                            if let chunk = String(data: data, encoding: .utf8) {
                                bufferedOutput += chunk
                            }

                            while let newlineIndex = bufferedOutput.firstIndex(of: "\n") {
                                let line = String(bufferedOutput[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                                bufferedOutput = String(bufferedOutput[bufferedOutput.index(after: newlineIndex)...])

                                guard !line.isEmpty,
                                      let lineData = line.data(using: .utf8),
                                      let json = try JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                                    continue
                                }

                                if let method = json["method"] as? String, method == "session/request_permission" {
                                    if let requestId = json["id"] {
                                        let response: [String: Any] = [
                                            "jsonrpc": "2.0",
                                            "id": requestId,
                                            "result": [
                                                "outcome": [
                                                    "outcome": "allow_once"
                                                ]
                                            ]
                                        ]
                                        let responseData = try JSONSerialization.data(withJSONObject: response)
                                        inputHandle.write(responseData)
                                        inputHandle.write(Data([0x0A]))
                                        requestState.markActivity()
                                    }
                                    continue
                                }

                                if let method = json["method"] as? String, method == "session/update" {
                                    let params = json["params"] as? [String: Any] ?? [:]
                                    let update = params["update"] as? [String: Any] ?? [:]
                                    emitUpdate(update)
                                    continue
                                }

                                if let targetResponseId,
                                   let responseId = json["id"] as? Int,
                                   responseId == targetResponseId {
                                    requestState.markActivity()
                                    return json["result"] as? [String: Any] ?? [:]
                                }
                            }
                        }

                        let stderr = requestState.stderrSnapshot()
                        throw ACPError.transportError(stderr.isEmpty ? "ACP 响应超时" : stderr)
                    }

                    let initializeId = try send(
                        "initialize",
                        params: [
                            "protocolVersion": 1,
                            "clientInfo": [
                                "name": "HermesMenuBar",
                                "version": "2.0.0"
                            ]
                        ]
                    )
                    _ = try readLines(timeout: 10, targetResponseId: initializeId)
                    _ = try send("initialized", params: [:], expectsResponse: false)

                    if let sessionId = preferredSessionId, !sessionId.isEmpty {
                        let loadId = try send(
                            "session/load",
                            params: [
                                "sessionId": sessionId,
                                "cwd": cwd,
                                "mcpServers": []
                            ]
                        )
                        do {
                            _ = try readLines(timeout: 10, targetResponseId: loadId)
                            finalSessionId = sessionId
                        } catch {
                            finalSessionId = ""
                        }
                    }

                    if finalSessionId.isEmpty {
                        let newId = try send(
                            "session/new",
                            params: [
                                "cwd": cwd,
                                "mcpServers": []
                            ]
                        )
                        let result = try readLines(timeout: 10, targetResponseId: newId)
                        finalSessionId = result["sessionId"] as? String ?? result["session_id"] as? String ?? ""
                    }

                    let promptId = try send(
                        "session/prompt",
                        params: [
                            "sessionId": finalSessionId,
                            "prompt": promptBlocks
                        ]
                    )
                    _ = try readLines(timeout: inactivityTimeout, targetResponseId: promptId)

                    requestState.terminateProcess()
                    guard requestState.finish() else { return }
                    Task { await self.unregisterOneShotRequest(requestID) }
                    continuation.resume(returning: HermesSendResult(text: aggregatedMessageText, sessionId: finalSessionId))
                } catch {
                    requestState.terminateProcess()
                    guard requestState.finish() else { return }
                    Task { await self.unregisterOneShotRequest(requestID) }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func cancel(requestID: String, sessionId: String?) async {
        if let requestState = oneShotRequests[requestID] {
            log("Cancelling one-shot ACP request \(requestID)")
            requestState.cancel()
            return
        }

        guard let sessionId, !sessionId.isEmpty else {
            return
        }

        do {
            _ = try await request(
                method: "cancel",
                params: [
                    "sessionId": sessionId
                ]
            )
        } catch {
            log("Cancel failed for \(sessionId): \(error.localizedDescription)")
        }
    }

    func deletePersistentSession(sessionId: String) async throws -> Bool {
        let hermesPath = try findHermesExecutable()
        func logLocal(_ message: String) {
            NSLog("[ACPClient] \(message)")
            DebugLogger.log("[ACPClient] \(message)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: hermesPath)
                    process.arguments = ["sessions", "delete", sessionId, "--yes"]

                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe

                    try process.run()
                    process.waitUntilExit()

                    let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let combined = ([stdout, stderr].filter { !$0.isEmpty }).joined(separator: "\n")

                    if process.terminationStatus == 0 {
                        logLocal("Deleted Hermes session \(sessionId)")
                        continuation.resume(returning: true)
                        return
                    }

                    if combined.localizedCaseInsensitiveContains("not found") {
                        logLocal("Hermes session \(sessionId) already absent")
                        continuation.resume(returning: true)
                        return
                    }

                    continuation.resume(throwing: ACPError.transportError(combined.isEmpty ? "Failed to delete Hermes session" : combined))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func unregisterOneShotRequest(_ requestID: String) {
        oneShotRequests.removeValue(forKey: requestID)
    }

    private func request(
        method: String,
        params: JSON,
        bootstrapRequest: Bool = false
    ) async throws -> JSON {
        if !bootstrapRequest {
            try await ensureReady()
        }

        let requestID = makeRequestID()

        return try await withCheckedThrowingContinuation { continuation in
            responseWaiters[requestID] = continuation

            do {
                let body: JSON = [
                    "jsonrpc": "2.0",
                    "id": requestID,
                    "method": method,
                    "params": params
                ]
                try write(json: body)
            } catch {
                responseWaiters.removeValue(forKey: requestID)
                continuation.resume(throwing: error)
            }
        }
    }

    private func ensureReady() async throws {
        if process?.isRunning != true {
            try startProcess()
        }

        if !isInitialized {
            _ = try await request(
                method: "initialize",
                params: [
                    "protocolVersion": 1,
                    "clientInfo": [
                        "name": "HermesMenuBar",
                        "version": "2.0.0"
                    ]
                ],
                bootstrapRequest: true
            )

            try write(json: [
                "jsonrpc": "2.0",
                "method": "initialized",
                "params": [:]
            ])
            isInitialized = true
        }
    }

    private func startProcess() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try findHermesExecutable())
        process.arguments = ["acp"]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        process.terminationHandler = { [weak process] terminatedProcess in
            let code = process?.terminationStatus ?? terminatedProcess.terminationStatus
            Task {
                await self.handleTermination(code: Int(code))
            }
        }

        try process.run()

        self.process = process
        self.inputHandle = inputPipe.fileHandleForWriting
        self.recentStderr.removeAll()
        self.isInitialized = false

        stdoutTask = Task {
            do {
                for try await line in outputPipe.fileHandleForReading.bytes.lines {
                    handleStdoutLine(String(line))
                }
                handleTermination(code: Int(process.terminationStatus))
            } catch {
                failOutstandingRequests(with: ACPError.transportError(error.localizedDescription))
            }
        }

        stderrTask = Task {
            do {
                for try await line in errorPipe.fileHandleForReading.bytes.lines {
                    appendStderr(String(line))
                }
            } catch {
                appendStderr("stderr reader failed: \(error.localizedDescription)")
            }
        }

        log("Started ACP process with pid \(process.processIdentifier)")
    }

    private func buildPromptBlocks(from payload: HermesPromptPayload) -> [[String: Any]] {
        var blocks: [[String: Any]] = []

        let text = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            blocks.append([
                "type": "text",
                "text": text
            ])
        }

        for image in payload.images {
            blocks.append([
                "type": "image_url",
                "image_url": [
                    "url": image.dataURL
                ]
            ])
        }

        if blocks.isEmpty {
            blocks.append([
                "type": "text",
                "text": "Please continue."
            ])
        }

        return blocks
    }

    private func handleStdoutLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let data = trimmed.data(using: .utf8) else { return }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? JSON else {
                return
            }

            if let method = json["method"] as? String {
                handleServerMethod(method, payload: json)
                return
            }

            if let requestID = json["id"] as? Int,
               let waiter = responseWaiters.removeValue(forKey: requestID) {
                if let errorPayload = json["error"] as? JSON {
                    waiter.resume(throwing: ACPError.serverError(message(from: errorPayload) ?? "Unknown ACP error"))
                    return
                }

                if let result = json["result"] as? JSON {
                    waiter.resume(returning: result)
                } else {
                    waiter.resume(returning: [:])
                }
            }
        } catch {
            log("Failed to decode ACP line: \(trimmed)")
        }
    }

    private func handleServerMethod(_ method: String, payload: JSON) {
        if method == "session/update" {
            return
        }

        if method == "session/request_permission",
           let requestID = payload["id"] {
            Task {
                try? await respond(
                    id: requestID,
                    result: [
                        "outcome": [
                            "outcome": "allow_once"
                        ]
                    ]
                )
            }
        }
    }

    private func respond(id: Any, result: Any) async throws {
        try write(json: [
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        ])
    }

    private func extractText(from result: JSON) -> String {
        if let content = result["content"] as? [[String: Any]] {
            return content.compactMap { item in
                item["text"] as? String
            }.joined()
        }

        if let text = result["text"] as? String {
            return text
        }

        return ""
    }

    private func parseToolCallEvent(_ update: JSON) -> HermesToolCallEvent? {
        guard let toolCallId = update["toolCallId"] as? String ?? update["tool_call_id"] as? String else {
            return nil
        }

        let title = update["title"] as? String ?? "Tool Call"
        let kind = update["kind"] as? String ?? "other"
        let status = update["status"] as? String
        let contentText = extractToolContent(from: update["content"])
        let rawOutput = update["rawOutput"] as? String ?? update["raw_output"] as? String

        return HermesToolCallEvent(
            id: toolCallId,
            title: title,
            kind: kind,
            content: rawOutput ?? contentText,
            status: status
        )
    }

    private func extractToolContent(from anyContent: Any?) -> String {
        guard let items = anyContent as? [[String: Any]] else {
            return ""
        }

        return items.compactMap { item in
            if let content = item["content"] as? [String: Any] {
                return content["text"] as? String
            }
            return item["text"] as? String
        }.joined(separator: "\n")
    }

    private func handleTermination(code: Int) {
        let stderr = recentStderr.joined(separator: "\n")
        process = nil
        inputHandle = nil
        isInitialized = false
        stdoutTask?.cancel()
        stderrTask?.cancel()
        stdoutTask = nil
        stderrTask = nil

        if !responseWaiters.isEmpty {
            let error = ACPError.processExited(code: code, stderr: stderr)
            failOutstandingRequests(with: error)
        }
    }

    private func failOutstandingRequests(with error: Error) {
        let waiters = responseWaiters
        responseWaiters.removeAll()

        for waiter in waiters.values {
            waiter.resume(throwing: error)
        }
    }

    private func appendStderr(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentStderr.append(trimmed)
        if recentStderr.count > 40 {
            recentStderr.removeFirst(recentStderr.count - 40)
        }
    }

    private func write(json: JSON) throws {
        guard let inputHandle else {
            throw ACPError.transportError("ACP process input is unavailable.")
        }

        let data = try JSONSerialization.data(withJSONObject: json)
        inputHandle.write(data)
        inputHandle.write(Data([0x0A]))
    }

    private func makeRequestID() -> Int {
        defer { nextRequestID += 1 }
        return nextRequestID
    }

    private func findHermesExecutable() throws -> String {
        let knownPaths = [
            "\(NSHomeDirectory())/.local/bin/hermes",
            "/opt/homebrew/bin/hermes",
            "/usr/local/bin/hermes",
            "/usr/bin/hermes"
        ]

        for path in knownPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        throw ACPError.hermesNotFound
    }

    private func message(from errorPayload: JSON) -> String? {
        errorPayload["message"] as? String
    }

    private func log(_ message: String) {
        NSLog("[ACPClient] \(message)")
        DebugLogger.log("[ACPClient] \(message)")
    }
}

private final class OneShotPromptState: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var errorHandle: FileHandle?
    private var cancelled = false
    private var finished = false
    private var lastActivityAt = Date()

    func attach(process: Process, errorHandle: FileHandle) {
        lock.lock()
        self.process = process
        self.errorHandle = errorHandle
        lastActivityAt = Date()
        lock.unlock()
    }

    func markActivity() {
        lock.lock()
        lastActivityAt = Date()
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        let cancelled = cancelled
        lock.unlock()
        return cancelled
    }

    func secondsSinceLastActivity() -> TimeInterval {
        lock.lock()
        let lastActivityAt = lastActivityAt
        lock.unlock()
        return Date().timeIntervalSince(lastActivityAt)
    }

    func stderrSnapshot() -> String {
        lock.lock()
        let errorHandle = errorHandle
        lock.unlock()
        let data = errorHandle?.availableData ?? Data()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let process = process
        lock.unlock()
        process?.terminate()
    }

    func terminateProcess() {
        lock.lock()
        let process = process
        lock.unlock()
        process?.terminate()
    }

    func finish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        finished = true
        return true
    }
}

private enum ACPError: LocalizedError {
    case hermesNotFound
    case invalidResponse(String)
    case serverError(String)
    case processExited(code: Int, stderr: String)
    case transportError(String)

    var errorDescription: String? {
        switch self {
        case .hermesNotFound:
            return "找不到 hermes 可执行文件。"
        case .invalidResponse(let message):
            return message
        case .serverError(let message):
            return "ACP 错误: \(message)"
        case .processExited(let code, let stderr):
            if stderr.isEmpty {
                return "ACP 进程已退出，退出码 \(code)。"
            }
            return "ACP 进程已退出，退出码 \(code)。\n\(stderr)"
        case .transportError(let message):
            return message
        }
    }
}
