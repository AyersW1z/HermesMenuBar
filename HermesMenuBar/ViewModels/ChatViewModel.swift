import Foundation
import AppKit
import UniformTypeIdentifiers
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    struct ActiveRequest {
        let requestID: String
        let sessionID: UUID
        let messageID: UUID
        let acpSessionID: String?
    }

    @Published var sessionManager: SessionManager
    @Published var inputText = ""
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var showingACPSessionPicker = false
    @Published var showingDiagnostics = false
    @Published var showArchivedSessions = false
    @Published var isLoadingACPSessions = false
    @Published var availableACPSessions: [ACPAvailableSession] = []
    @Published var draftImageURLs: [URL] = []

    private let hermesClient: HermesClientProtocol
    private let acpBrowserClient: HermesClientProtocol
    private let imagePreprocessor: HermesImagePreprocessor
    private let cwd: String
    private var activeRequest: ActiveRequest?
    private var activeToolMessageIDsByToolCallID: [String: UUID] = [:]
    private var hydratedACPSessionIDs: Set<String> = []
    private var cancellables: Set<AnyCancellable> = []

    init(
        hermesClient: HermesClientProtocol = ACPClient(),
        acpBrowserClient: HermesClientProtocol? = nil,
        sessionManager: SessionManager? = nil,
        imagePreprocessor: HermesImagePreprocessor = HermesImagePreprocessor(),
        cwd: String = FileManager.default.currentDirectoryPath
    ) {
        self.hermesClient = hermesClient
        self.acpBrowserClient = acpBrowserClient ?? ACPClient()
        self.sessionManager = sessionManager ?? SessionManager()
        self.imagePreprocessor = imagePreprocessor
        self.cwd = cwd

        self.sessionManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        self.sessionManager.clearStaleRequestState()
        DebugLogger.log("[ChatViewModel] init cwd=\(cwd)")

        Task { @MainActor in
            await preloadACPSessions()
        }
    }

    var currentSession: ChatSession? {
        sessionManager.currentSession
    }

    var currentMessages: [Message] {
        currentSession?.messages ?? []
    }

    var currentRuntimeState: SessionRuntimeState {
        guard let sessionID = currentSession?.id else {
            return SessionRuntimeState()
        }
        return sessionManager.runtimeState(for: sessionID)
    }

    var hasActiveRequestInCurrentSession: Bool {
        guard let currentSession else { return false }
        return activeRequest?.sessionID == currentSession.id
    }

    var visibleSessions: [ChatSession] {
        sessionManager.visibleSessions(searchText: searchText, includeArchived: showArchivedSessions)
    }

    var canSend: Bool {
        hasDraftContent && !isComposerLockedByAnotherSession && !hasActiveRequestInCurrentSession
    }

    var hasDraftContent: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draftImageURLs.isEmpty
    }

    var isComposerLockedByAnotherSession: Bool {
        guard let activeRequest,
              let currentSession else {
            return false
        }
        return activeRequest.sessionID != currentSession.id
    }

    var backgroundRequestBanner: String? {
        guard let activeRequest,
              let currentSession,
              activeRequest.sessionID != currentSession.id,
              let busySession = sessionManager.session(with: activeRequest.sessionID) else {
            return nil
        }
        return "Reply still streaming in \(busySession.name)"
    }

    func sendMessage() {
        guard let session = currentSession else {
            DebugLogger.log("[ChatViewModel] sendMessage aborted: no current session")
            return
        }
        guard canSend else {
            DebugLogger.log("[ChatViewModel] sendMessage aborted: canSend=false activeCurrent=\(hasActiveRequestInCurrentSession) activeAny=\(activeRequest != nil) runtimeActive=\(currentRuntimeState.isRequestActive)")
            sessionManager.clearStaleRequestState()
            return
        }
        guard activeRequest == nil else {
            DebugLogger.log("[ChatViewModel] sendMessage aborted: activeRequest already exists")
            return
        }

        DebugLogger.log("[ChatViewModel] sendMessage session=\(session.id.uuidString) text=\(inputText)")
        sessionManager.normalizeStreamingMessages(in: session.id)
        sessionManager.updateRuntimeState(for: session.id) { runtime in
            runtime.isRequestActive = false
            if runtime.transportState == .connecting {
                runtime.transportState = .ready
            }
        }

        let rawText = inputText
        let imageURLs = draftImageURLs

        inputText = ""
        draftImageURLs = []
        errorMessage = nil

        do {
            let attachments = try sessionManager.persistAttachments(from: imageURLs)
            let userMessage = Message(role: .user, content: rawText, attachments: attachments)
            sessionManager.addMessage(userMessage, to: session.id)

            let assistantMessage = Message(role: .assistant, content: "", isStreaming: true)
            sessionManager.addMessage(assistantMessage, to: session.id)
            sessionManager.updateRuntimeState(for: session.id) { runtime in
                runtime.transportState = .connecting
                runtime.isRequestActive = true
                runtime.lastError = nil
            }

            Task {
                do {
                    let requestID = UUID().uuidString
                    let existingACPSessionID = session.acpSessionId
                    activeRequest = ActiveRequest(
                        requestID: requestID,
                        sessionID: session.id,
                        messageID: assistantMessage.id,
                        acpSessionID: existingACPSessionID
                    )

                    let payload = await imagePreprocessor.enrichPrompt(text: rawText, attachments: attachments)

                    let sendResult = try await hermesClient.sendMessage(payload, requestID: requestID, sessionId: existingACPSessionID, cwd: cwd) { [weak self] event in
                        Task { @MainActor in
                            self?.handleStreamEvent(
                                event,
                                requestID: requestID,
                                sessionID: session.id,
                                assistantMessageID: assistantMessage.id
                            )
                        }
                    }

                    guard self.activeRequest?.sessionID == session.id,
                          self.activeRequest?.messageID == assistantMessage.id else {
                        return
                    }
                    if sendResult.sessionId != existingACPSessionID {
                        sessionManager.updateACPSessionID(sendResult.sessionId, for: session.id)
                        activeRequest = ActiveRequest(
                            requestID: requestID,
                            sessionID: session.id,
                            messageID: assistantMessage.id,
                            acpSessionID: sendResult.sessionId
                        )
                    }
                    NSLog("[ChatViewModel] Final send result for session \(session.id.uuidString.prefix(8)): \(sendResult.text.prefix(120))")
                    DebugLogger.log("[ChatViewModel] finalSendResult session=\(session.id.uuidString) text=\(sendResult.text)")
                    finalizeMessage(
                        content: sendResult.text,
                        sessionID: session.id,
                        messageID: assistantMessage.id
                    )
                } catch {
                    guard self.activeRequest?.sessionID == session.id,
                          self.activeRequest?.messageID == assistantMessage.id else {
                        return
                    }
                    failRequest(
                        for: session.id,
                        messageID: assistantMessage.id,
                        error: error.localizedDescription
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            DebugLogger.log("[ChatViewModel] sendMessage immediate error=\(error.localizedDescription)")
        }
    }

    func cancelRequest() {
        guard let activeRequest else { return }
        DebugLogger.log("[ChatViewModel] cancelRequest session=\(activeRequest.sessionID.uuidString)")

        Task {
            await hermesClient.cancel(requestID: activeRequest.requestID, sessionId: activeRequest.acpSessionID)
        }

        sessionManager.removeMessage(messageID: activeRequest.messageID, from: activeRequest.sessionID)
        sessionManager.updateRuntimeState(for: activeRequest.sessionID) { runtime in
            runtime.isRequestActive = false
            runtime.transportState = .ready
            runtime.lastError = "Request cancelled"
        }
        self.activeRequest = nil
    }

    func createNewSession() {
        _ = sessionManager.createSession()
        errorMessage = nil
    }

    func deleteSession(_ session: ChatSession) {
        Task {
            do {
                if let acpSessionID = session.acpSessionId, !acpSessionID.isEmpty {
                    if activeRequest?.sessionID == session.id {
                        cancelRequest()
                    }

                    let remainingBindings = sessionManager
                        .sessions(boundToACP: acpSessionID)
                        .filter { $0.id != session.id }

                    if remainingBindings.isEmpty {
                        _ = try await hermesClient.deleteSession(sessionId: acpSessionID)
                        await MainActor.run {
                            availableACPSessions.removeAll { $0.id == acpSessionID }
                            hydratedACPSessionIDs.remove(acpSessionID)
                        }
                    } else {
                        DebugLogger.log("[ChatViewModel] deleteSession local-only detach session=\(session.id.uuidString) acp=\(acpSessionID) remainingBindings=\(remainingBindings.count)")
                    }
                }

                await MainActor.run {
                    sessionManager.deleteSession(session)
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "删除 session 失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func switchToSession(_ session: ChatSession) {
        sessionManager.switchToSession(session)
    }

    func clearCurrentSession() {
        guard let sessionID = currentSession?.id else { return }
        sessionManager.clearMessages(in: sessionID)
    }

    func renameSession(_ session: ChatSession, to newName: String) {
        sessionManager.renameSession(session, to: newName)
    }

    func togglePin(_ session: ChatSession) {
        sessionManager.togglePin(for: session.id)
    }

    func toggleArchive(_ session: ChatSession) {
        sessionManager.toggleArchive(for: session.id)
    }

    func attachImages() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK else { return }
        addDraftImages(from: panel.urls)
    }

    func addDraftImages(from urls: [URL]) {
        let imageURLs = urls.filter { url in
            UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
        }

        for imageURL in imageURLs where !draftImageURLs.contains(imageURL) {
            draftImageURLs.append(imageURL)
        }
    }

    func removeDraftImage(_ url: URL) {
        draftImageURLs.removeAll { $0 == url }
    }

    func openACPSessionPicker() {
        showingACPSessionPicker = true
        Task {
            await loadAvailableACPSessions(forceRefresh: availableACPSessions.isEmpty)
        }
    }

    func refreshAvailableACPSessions() {
        Task {
            await loadAvailableACPSessions(forceRefresh: true)
        }
    }

    func connectToACPSession(_ acpSessionID: String) {
        Task {
            do {
                let success = try await hermesClient.loadSession(sessionId: acpSessionID, cwd: cwd)
                guard success else {
                    throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "ACP session 无法恢复"])
                }

                await MainActor.run {
                    let targetSession: ChatSession
                    if let existingSession = sessionManager.session(boundToACP: acpSessionID) {
                        targetSession = existingSession
                        sessionManager.switchToSession(existingSession)
                    } else if let currentSession,
                       currentSession.messages.isEmpty,
                       currentSession.acpSessionId == nil {
                        targetSession = currentSession
                        sessionManager.updateACPSessionID(acpSessionID, for: currentSession.id)
                    } else {
                        targetSession = sessionManager.createSession(
                            name: "ACP \(acpSessionID.prefix(8))",
                            acpSessionId: acpSessionID
                        )
                    }

                    hydratedACPSessionIDs.insert(acpSessionID)
                    sessionManager.updateRuntimeState(for: targetSession.id) { runtime in
                        runtime.transportState = .ready
                        runtime.lastError = nil
                    }
                    showingACPSessionPicker = false
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "连接 ACP session 失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func preloadACPSessions() async {
        await loadAvailableACPSessions(forceRefresh: true, silent: true)
    }

    private func loadAvailableACPSessions(forceRefresh: Bool, silent: Bool = false) async {
        if isLoadingACPSessions {
            return
        }

        if !forceRefresh && !availableACPSessions.isEmpty {
            return
        }

        isLoadingACPSessions = true
        defer { isLoadingACPSessions = false }

        do {
            let sessions = try await acpBrowserClient.listSessions()
            let uniqueSessions = Dictionary(
                sessions.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            ).values.sorted { lhs, rhs in
                let lhsCurrent = lhs.cwd == cwd
                let rhsCurrent = rhs.cwd == cwd
                if lhsCurrent != rhsCurrent {
                    return lhsCurrent && !rhsCurrent
                }
                if lhs.cwd != rhs.cwd {
                    return lhs.cwd < rhs.cwd
                }
                return lhs.id < rhs.id
            }

            availableACPSessions = uniqueSessions
            sessionManager.syncACPSessions(uniqueSessions, preferredCWD: cwd)
            DebugLogger.log("[ChatViewModel] synced \(uniqueSessions.count) ACP sessions")
            if !silent {
                errorMessage = nil
            }
        } catch {
            if !silent {
                errorMessage = "无法加载 ACP sessions: \(error.localizedDescription)"
            }
            DebugLogger.log("[ChatViewModel] loadAvailableACPSessions error=\(error.localizedDescription)")
        }
    }

    func statusText(for session: ChatSession) -> String {
        let runtime = sessionManager.runtimeState(for: session.id)
        if runtime.isRequestActive {
            return "Streaming"
        }
        switch runtime.transportState {
        case .connecting:
            return "Connecting"
        case .ready:
            return session.acpSessionId == nil ? "Ready" : "Attached"
        case .error:
            return "Error"
        case .disconnected:
            return session.acpSessionId == nil ? "Local" : "Detached"
        }
    }

    private func appendChunk(_ chunk: String, to sessionID: UUID, messageID: UUID) {
        guard activeRequest?.sessionID == sessionID,
              activeRequest?.messageID == messageID else {
            return
        }
        guard var message = sessionManager.session(with: sessionID)?.messages.first(where: { $0.id == messageID }) else {
            return
        }

        message.content += chunk
        message.isStreaming = true
        sessionManager.updateMessage(message, in: sessionID)
        NSLog("[ChatViewModel] Appended chunk for session \(sessionID.uuidString.prefix(8)): \(chunk.prefix(120))")
        DebugLogger.log("[ChatViewModel] appendChunk session=\(sessionID.uuidString) chunk=\(chunk)")
    }

    private func finalizeMessage(content: String, sessionID: UUID, messageID: UUID) {
        guard var message = sessionManager.session(with: sessionID)?.messages.first(where: { $0.id == messageID }) else {
            cleanupActiveRequest(for: sessionID)
            return
        }

        let resolvedContent = content.isEmpty ? message.content : content
        message.content = resolvedContent
        message.isStreaming = false
        sessionManager.updateMessage(message, in: sessionID)
        NSLog("[ChatViewModel] Finalized message for session \(sessionID.uuidString.prefix(8)): \(resolvedContent.prefix(120))")
        DebugLogger.log("[ChatViewModel] finalizeMessage session=\(sessionID.uuidString) content=\(resolvedContent)")
        sessionManager.updateRuntimeState(for: sessionID) { runtime in
            runtime.transportState = .ready
            runtime.isRequestActive = false
            runtime.lastError = nil
        }
        cleanupActiveRequest(for: sessionID)
    }

    private func failRequest(for sessionID: UUID, messageID: UUID, error: String) {
        if var message = sessionManager.session(with: sessionID)?.messages.first(where: { $0.id == messageID }),
           !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            message.isStreaming = false
            sessionManager.updateMessage(message, in: sessionID)
        } else {
            sessionManager.removeMessage(messageID: messageID, from: sessionID)
        }
        sessionManager.updateRuntimeState(for: sessionID) { runtime in
            runtime.transportState = .error
            runtime.isRequestActive = false
            runtime.lastError = error
        }
        DebugLogger.log("[ChatViewModel] failRequest session=\(sessionID.uuidString) error=\(error)")

        if currentSession?.id == sessionID {
            errorMessage = error
        }

        cleanupActiveRequest(for: sessionID)
    }

    private func cleanupActiveRequest(for sessionID: UUID) {
        if activeRequest?.sessionID == sessionID {
            activeRequest = nil
        }
        activeToolMessageIDsByToolCallID.removeAll()
    }

    private func handleStreamEvent(_ event: HermesStreamEvent, requestID: String, sessionID: UUID, assistantMessageID: UUID) {
        guard activeRequest?.requestID == requestID,
              activeRequest?.sessionID == sessionID,
              activeRequest?.messageID == assistantMessageID else {
            DebugLogger.log("[ChatViewModel] ignored stale stream event request=\(requestID) session=\(sessionID.uuidString)")
            return
        }

        switch event {
        case .messageChunk(let chunk):
            appendChunk(chunk, to: sessionID, messageID: assistantMessageID)

        case .thoughtChunk(let thought):
            let thoughtMessage = Message(
                role: .assistant,
                content: thought,
                isStreaming: false,
                displayKind: .thought,
                title: "Hermes thinking"
            )
            sessionManager.insertMessage(thoughtMessage, beforeMessageID: assistantMessageID, in: sessionID)

        case .toolCallStarted(let toolEvent):
            let toolMessage = Message(
                role: .assistant,
                content: toolEvent.content,
                isStreaming: true,
                displayKind: .tool,
                title: toolEvent.title,
                toolCallId: toolEvent.id,
                toolKind: toolEvent.kind,
                toolStatus: toolEvent.status ?? "running"
            )
            activeToolMessageIDsByToolCallID[toolEvent.id] = toolMessage.id
            sessionManager.insertMessage(toolMessage, beforeMessageID: assistantMessageID, in: sessionID)

        case .toolCallUpdated(let toolEvent):
            guard let messageID = activeToolMessageIDsByToolCallID[toolEvent.id],
                  var message = sessionManager.session(with: sessionID)?.messages.first(where: { $0.id == messageID }) else {
                let fallback = Message(
                    role: .assistant,
                    content: toolEvent.content,
                    isStreaming: false,
                    displayKind: .tool,
                    title: toolEvent.title,
                    toolCallId: toolEvent.id,
                    toolKind: toolEvent.kind,
                    toolStatus: toolEvent.status ?? "completed"
                )
                sessionManager.insertMessage(fallback, beforeMessageID: assistantMessageID, in: sessionID)
                return
            }

            message.content = toolEvent.content
            message.isStreaming = false
            message.title = toolEvent.title
            message.toolKind = toolEvent.kind
            message.toolStatus = toolEvent.status ?? "completed"
            sessionManager.updateMessage(message, in: sessionID)
        }
    }
}
