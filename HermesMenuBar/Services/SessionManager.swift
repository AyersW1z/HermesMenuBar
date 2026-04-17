import Foundation
import Combine

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var sessions: [ChatSession] = []
    @Published private(set) var currentSessionID: UUID?

    private let store: SessionStore
    private var runtimeStates: [UUID: SessionRuntimeState] = [:]
    private var pendingSaveTask: Task<Void, Never>?

    init(store: SessionStore = SessionStore()) {
        self.store = store
        loadSessions()
    }

    var currentSession: ChatSession? {
        guard let currentSessionID else { return nil }
        return sessions.first(where: { $0.id == currentSessionID })
    }

    var allSessions: [ChatSession] {
        sessions
    }

    func session(with id: UUID) -> ChatSession? {
        sessions.first(where: { $0.id == id })
    }

    func session(boundToACP acpSessionId: String) -> ChatSession? {
        sessions.first(where: { $0.acpSessionId == acpSessionId })
    }

    func sessions(boundToACP acpSessionId: String) -> [ChatSession] {
        sessions.filter { $0.acpSessionId == acpSessionId }
    }

    func visibleSessions(searchText: String = "", includeArchived: Bool = false) -> [ChatSession] {
        let normalizedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = sessions.filter { session in
            if session.isArchived && !includeArchived {
                return false
            }

            guard !normalizedQuery.isEmpty else { return true }

            if session.name.lowercased().contains(normalizedQuery) {
                return true
            }

            if session.previewText.lowercased().contains(normalizedQuery) {
                return true
            }

            return session.messages.contains { message in
                message.content.lowercased().contains(normalizedQuery)
            }
        }

        return filtered.sorted(by: sortSessions)
    }

    func runtimeState(for sessionID: UUID) -> SessionRuntimeState {
        runtimeStates[sessionID] ?? SessionRuntimeState()
    }

    func clearStaleRequestState() {
        objectWillChange.send()
        for key in runtimeStates.keys {
            if runtimeStates[key]?.isRequestActive == true {
                runtimeStates[key]?.isRequestActive = false
                if runtimeStates[key]?.transportState == .connecting {
                    runtimeStates[key]?.transportState = .ready
                }
            }
        }
    }

    func createSession(name: String? = nil, acpSessionId: String? = nil) -> ChatSession {
        objectWillChange.send()
        let sessionName = name ?? makeSessionName()
        let session = ChatSession(name: sessionName, acpSessionId: acpSessionId)
        sessions.append(session)
        runtimeStates[session.id] = SessionRuntimeState(
            transportState: acpSessionId == nil ? .disconnected : .ready,
            isRequestActive: false,
            lastError: nil,
            lastUpdatedAt: Date()
        )
        switchToSession(session)
        scheduleSave()
        return session
    }

    func deleteSession(_ session: ChatSession) {
        objectWillChange.send()
        sessions.removeAll { $0.id == session.id }
        runtimeStates.removeValue(forKey: session.id)

        if currentSessionID == session.id {
            currentSessionID = visibleSessions(includeArchived: false).first?.id ?? sessions.sorted(by: sortSessions).first?.id
        }

        if sessions.isEmpty {
            _ = createSession(name: "Default Session")
            return
        }

        scheduleSave()
    }

    func switchToSession(_ session: ChatSession) {
        objectWillChange.send()
        currentSessionID = session.id
        scheduleSave()
    }

    func addMessage(_ message: Message, to sessionID: UUID) {
        mutateSession(sessionID) { session in
            var message = message
            message.sequence = nextSequence(in: session)
            session.messages.append(message)
            session.updatedAt = Date()
        }
    }

    func insertMessage(_ message: Message, beforeMessageID targetMessageID: UUID, in sessionID: UUID) {
        mutateSession(sessionID) { session in
            var message = message
            message.sequence = nextSequence(in: session)
            if let targetIndex = session.messages.firstIndex(where: { $0.id == targetMessageID }) {
                let targetSequence = session.messages[targetIndex].sequence
                for index in session.messages.indices where session.messages[index].sequence >= targetSequence {
                    session.messages[index].sequence += 1
                }
                message.sequence = targetSequence
                session.messages.insert(message, at: targetIndex)
            } else {
                session.messages.append(message)
            }
            session.messages.sort { lhs, rhs in
                if lhs.sequence != rhs.sequence {
                    return lhs.sequence < rhs.sequence
                }
                return lhs.timestamp < rhs.timestamp
            }
            session.updatedAt = Date()
        }
    }

    func updateMessage(_ message: Message, in sessionID: UUID) {
        mutateSession(sessionID) { session in
            guard let index = session.messages.firstIndex(where: { $0.id == message.id }) else { return }
            session.messages[index] = message
            session.updatedAt = Date()
        }
    }

    func removeMessage(messageID: UUID, from sessionID: UUID) {
        mutateSession(sessionID) { session in
            session.messages.removeAll { $0.id == messageID }
            session.updatedAt = Date()
        }
    }

    func removeSessions(boundToACP acpSessionId: String) {
        let boundSessions = sessions.filter { $0.acpSessionId == acpSessionId }
        for session in boundSessions {
            deleteSession(session)
        }
    }

    func renameSession(_ session: ChatSession, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        mutateSession(session.id) { mutableSession in
            mutableSession.name = trimmedName
        }
    }

    func clearMessages(in sessionID: UUID) {
        mutateSession(sessionID) { session in
            session.messages.removeAll()
            session.updatedAt = Date()
        }
    }

    func togglePin(for sessionID: UUID) {
        mutateSession(sessionID) { session in
            session.isPinned.toggle()
        }
    }

    func toggleArchive(for sessionID: UUID) {
        mutateSession(sessionID) { session in
            session.isArchived.toggle()
        }

        if currentSessionID == sessionID,
           let current = session(with: sessionID),
           current.isArchived,
           let nextSession = visibleSessions(includeArchived: false).first {
            currentSessionID = nextSession.id
        }
    }

    func updateACPSessionID(_ acpSessionId: String?, for sessionID: UUID) {
        mutateSession(sessionID) { session in
            session.acpSessionId = acpSessionId
        }
    }

    func updateRuntimeState(for sessionID: UUID, mutate: (inout SessionRuntimeState) -> Void) {
        var state = runtimeStates[sessionID] ?? SessionRuntimeState()
        mutate(&state)
        state.lastUpdatedAt = Date()
        runtimeStates[sessionID] = state
        objectWillChange.send()
    }

    func persistAttachments(from imageURLs: [URL]) throws -> [MessageAttachment] {
        try imageURLs.map { try store.importImage(from: $0) }
    }

    func syncACPSessions(_ acpSessions: [ACPAvailableSession], preferredCWD: String? = nil) {
        objectWillChange.send()

        let sortedSessions = acpSessions.sorted { lhs, rhs in
            let lhsPreferred = preferredCWD.map { lhs.cwd == $0 } ?? false
            let rhsPreferred = preferredCWD.map { rhs.cwd == $0 } ?? false
            if lhsPreferred != rhsPreferred {
                return lhsPreferred && !rhsPreferred
            }
            if lhs.cwd != rhs.cwd {
                return lhs.cwd < rhs.cwd
            }
            return lhs.id < rhs.id
        }
        let remoteIDs = Set(sortedSessions.map(\.id))

        let placeholderSessionID = sessions.first(where: {
            $0.acpSessionId == nil && $0.messages.isEmpty && $0.name == "Default Session"
        })?.id
        var placeholderConsumed = false

        for acpSession in sortedSessions {
            let displayName = displayName(for: acpSession)

            if let existingIndex = sessions.firstIndex(where: { $0.acpSessionId == acpSession.id }) {
                if shouldRefreshName(for: sessions[existingIndex], acpSession: acpSession) {
                    sessions[existingIndex].name = displayName
                }
                sessions[existingIndex].updatedAt = Date()
                runtimeStates[sessions[existingIndex].id]?.transportState = .ready
                runtimeStates[sessions[existingIndex].id]?.lastError = nil
                continue
            }

            if !placeholderConsumed,
               let placeholderID = placeholderSessionID,
               let placeholderIndex = sessions.firstIndex(where: { $0.id == placeholderID }) {
                sessions[placeholderIndex].name = displayName
                sessions[placeholderIndex].acpSessionId = acpSession.id
                sessions[placeholderIndex].updatedAt = Date()
                runtimeStates[sessions[placeholderIndex].id]?.transportState = .ready
                runtimeStates[sessions[placeholderIndex].id]?.lastError = nil
                placeholderConsumed = true
                continue
            }

            let session = ChatSession(
                name: displayName,
                acpSessionId: acpSession.id
            )
            sessions.append(session)
            runtimeStates[session.id] = SessionRuntimeState(
                transportState: .ready,
                isRequestActive: false,
                lastError: nil,
                lastUpdatedAt: Date()
            )
        }

        var removedCurrentSession = false
        sessions.removeAll { session in
            guard let acpSessionId = session.acpSessionId,
                  !remoteIDs.contains(acpSessionId) else {
                return false
            }

            let shouldRemove = session.messages.isEmpty && !session.isPinned
            if shouldRemove {
                runtimeStates.removeValue(forKey: session.id)
                removedCurrentSession = removedCurrentSession || currentSessionID == session.id
                return true
            }

            runtimeStates[session.id]?.transportState = .disconnected
            runtimeStates[session.id]?.lastError = "ACP session unavailable"
            return false
        }

        if removedCurrentSession {
            currentSessionID = visibleSessions(includeArchived: false).first?.id ?? sessions.sorted(by: sortSessions).first?.id
        }

        if sessions.isEmpty {
            let defaultSession = ChatSession(name: "Default Session")
            sessions = [defaultSession]
            currentSessionID = defaultSession.id
            runtimeStates[defaultSession.id] = SessionRuntimeState(
                transportState: .disconnected,
                isRequestActive: false,
                lastError: nil,
                lastUpdatedAt: Date()
            )
        }

        scheduleSave()
    }

    func normalizeStreamingMessages(in sessionID: UUID) {
        mutateSession(sessionID) { session in
            session.messages = session.messages.compactMap { message in
                guard message.role == .assistant, message.isStreaming else {
                    return message
                }

                if message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return nil
                }

                var finishedMessage = message
                finishedMessage.isStreaming = false
                return finishedMessage
            }
        }
    }

    private func mutateSession(_ sessionID: UUID, mutate: (inout ChatSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        objectWillChange.send()
        mutate(&sessions[index])
        sessions[index].updatedAt = Date()
        scheduleSave()
    }

    private func makeSessionName() -> String {
        "Session \(sessions.count + 1)"
    }

    private func nextSequence(in session: ChatSession) -> Int {
        (session.messages.map(\.sequence).max() ?? -1) + 1
    }

    private func displayName(for acpSession: ACPAvailableSession) -> String {
        let cwdLabel: String
        if acpSession.cwd == "/" {
            cwdLabel = "Root"
        } else {
            let trimmed = acpSession.cwd.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            cwdLabel = trimmed.isEmpty ? "Workspace" : URL(fileURLWithPath: acpSession.cwd).lastPathComponent
        }

        return "\(cwdLabel) · \(acpSession.id.prefix(8))"
    }

    private func shouldRefreshName(for session: ChatSession, acpSession: ACPAvailableSession) -> Bool {
        if session.messages.isEmpty {
            return true
        }

        let suffix = "· \(acpSession.id.prefix(8))"
        return session.name.contains(suffix)
    }

    private func loadSessions() {
        do {
            if let snapshot = try store.load() {
                sessions = snapshot.sessions.map(sanitizedSession)
                currentSessionID = snapshot.currentSessionID ?? snapshot.sessions.sorted(by: sortSessions).first?.id
            }
        } catch {
            NSLog("[SessionManager] Failed to load sessions: \(error.localizedDescription)")
        }

        if sessions.isEmpty {
            let defaultSession = ChatSession(name: "Default Session")
            sessions = [defaultSession]
            currentSessionID = defaultSession.id
        }

        runtimeStates = Dictionary(uniqueKeysWithValues: sessions.map { session in
            (session.id, SessionRuntimeState(
                transportState: session.acpSessionId == nil ? .disconnected : .ready,
                isRequestActive: false,
                lastError: nil,
                lastUpdatedAt: nil
            ))
        })
    }

    private func sanitizedSession(_ session: ChatSession) -> ChatSession {
        var session = session
        session.messages = session.messages.compactMap { message in
            guard message.role == .assistant, message.isStreaming else {
                return message
            }

            if message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return nil
            }

            var finishedMessage = message
            finishedMessage.isStreaming = false
            return finishedMessage
        }
        return session
    }

    private func scheduleSave() {
        pendingSaveTask?.cancel()
        let snapshot = SessionsSnapshot(sessions: sessions, currentSessionID: currentSessionID)
        pendingSaveTask = Task.detached(priority: .utility) { [store] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            try? store.save(snapshot)
        }
    }

    private func sortSessions(lhs: ChatSession, rhs: ChatSession) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }

        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        return lhs.createdAt > rhs.createdAt
    }
}
