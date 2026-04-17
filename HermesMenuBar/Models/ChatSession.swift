import Foundation

struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    var acpSessionId: String?
    var isPinned: Bool
    var isArchived: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        acpSessionId: String? = nil,
        isPinned: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.acpSessionId = acpSessionId
        self.isPinned = isPinned
        self.isArchived = isArchived
    }

    var previewText: String {
        for message in messages.reversed() {
            guard message.displayKind == .chat else { continue }
            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message.content
            }
            if !message.attachments.isEmpty {
                return message.attachments.count == 1 ? "1 attachment" : "\(message.attachments.count) attachments"
            }
        }
        return "No messages yet"
    }
}
