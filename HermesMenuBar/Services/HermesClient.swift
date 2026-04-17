import Foundation

struct ACPAvailableSession: Equatable, Identifiable {
    let id: String
    let cwd: String
}

struct HermesImageInput: Equatable {
    let filename: String
    let dataURL: String
}

struct HermesPromptPayload: Equatable {
    var text: String
    var images: [HermesImageInput] = []
}

struct HermesSendResult: Equatable {
    let text: String
    let sessionId: String
}

struct HermesToolCallEvent: Equatable {
    let id: String
    let title: String
    let kind: String
    let content: String
    let status: String?
}

enum HermesStreamEvent: Equatable {
    case messageChunk(String)
    case thoughtChunk(String)
    case toolCallStarted(HermesToolCallEvent)
    case toolCallUpdated(HermesToolCallEvent)
}

protocol HermesClientProtocol {
    func createSession(cwd: String) async throws -> String
    func listSessions() async throws -> [ACPAvailableSession]
    func loadSession(sessionId: String, cwd: String) async throws -> Bool
    func sendMessage(_ payload: HermesPromptPayload, requestID: String, sessionId: String?, cwd: String, onEvent: @Sendable @escaping (HermesStreamEvent) -> Void) async throws -> HermesSendResult
    func cancel(requestID: String, sessionId: String?) async
    func deleteSession(sessionId: String) async throws -> Bool
}

class HermesClient: HermesClientProtocol {
    private var currentTask: Task<Void, Never>?
    private var urlSession: URLSession
    
    private let apiURL = "http://localhost:8080/api/chat"
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        self.urlSession = URLSession(configuration: config)
    }

    func createSession(cwd: String) async throws -> String {
        UUID().uuidString
    }

    func listSessions() async throws -> [ACPAvailableSession] {
        []
    }

    func loadSession(sessionId: String, cwd: String) async throws -> Bool {
        true
    }
    
    func sendMessage(_ payload: HermesPromptPayload, requestID: String, sessionId: String?, cwd: String, onEvent: @Sendable @escaping (HermesStreamEvent) -> Void) async throws -> HermesSendResult {
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "message": payload.text,
            "session_id": sessionId as Any,
            "stream": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await withCheckedThrowingContinuation { continuation in
            currentTask = Task {
                do {
                    let (bytes, response) = try await urlSession.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        continuation.resume(throwing: HermesError.invalidResponse)
                        return
                    }
                    
                    var fullResponse = ""
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            if data == "[DONE]" {
                                break
                            }
                            fullResponse += data
                            onEvent(.messageChunk(data))
                        } else if !line.isEmpty {
                            fullResponse += line
                            onEvent(.messageChunk(line))
                        }
                    }
                    
                    continuation.resume(returning: HermesSendResult(text: fullResponse, sessionId: sessionId ?? ""))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func cancel(requestID: String, sessionId: String?) async {
        currentTask?.cancel()
        currentTask = nil
    }

    func deleteSession(sessionId: String) async throws -> Bool {
        throw HermesError.unsupportedOperation("Remote Hermes session deletion is only supported by ACPClient.")
    }
    
    enum HermesError: Error {
        case invalidResponse
        case requestCancelled
        case networkError(Error)
        case unsupportedOperation(String)
    }
}

class MockHermesClient: HermesClientProtocol {
    func createSession(cwd: String) async throws -> String {
        UUID().uuidString
    }

    func listSessions() async throws -> [ACPAvailableSession] {
        []
    }

    func loadSession(sessionId: String, cwd: String) async throws -> Bool {
        true
    }

    func sendMessage(_ payload: HermesPromptPayload, requestID: String, sessionId: String?, cwd: String, onEvent: @Sendable @escaping (HermesStreamEvent) -> Void) async throws -> HermesSendResult {
        let response = "This is a mock response from Hermes. You said: \"\(payload.text)\"\n\nI'm a simulated AI assistant for testing purposes. In production, this would connect to the actual Hermes backend."
        
        let words = response.split(separator: " ")
        var streamedContent = ""
        
        for word in words {
            try await Task.sleep(nanoseconds: 50_000_000)
            let chunk = word + " "
            streamedContent += chunk
            onEvent(.messageChunk(String(chunk)))
        }
        
        return HermesSendResult(text: response, sessionId: sessionId ?? UUID().uuidString)
    }
    
    func cancel(requestID: String, sessionId: String?) async {}

    func deleteSession(sessionId: String) async throws -> Bool {
        throw HermesClient.HermesError.unsupportedOperation("MockHermesClient does not persist Hermes sessions.")
    }
}
