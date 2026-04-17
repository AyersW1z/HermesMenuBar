import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var attachments: [MessageAttachment]
    var displayKind: MessageDisplayKind
    var title: String?
    var toolCallId: String?
    var toolKind: String?
    var toolStatus: String?
    var sequence: Int
    
    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        attachments: [MessageAttachment] = [],
        displayKind: MessageDisplayKind = .chat,
        title: String? = nil,
        toolCallId: String? = nil,
        toolKind: String? = nil,
        toolStatus: String? = nil,
        sequence: Int = 0
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.attachments = attachments
        self.displayKind = displayKind
        self.title = title
        self.toolCallId = toolCallId
        self.toolKind = toolKind
        self.toolStatus = toolStatus
        self.sequence = sequence
    }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case timestamp
        case isStreaming
        case attachments
        case displayKind
        case title
        case toolCallId
        case toolKind
        case toolStatus
        case sequence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        role = try container.decode(MessageRole.self, forKey: .role)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        isStreaming = try container.decodeIfPresent(Bool.self, forKey: .isStreaming) ?? false
        attachments = try container.decodeIfPresent([MessageAttachment].self, forKey: .attachments) ?? []
        displayKind = try container.decodeIfPresent(MessageDisplayKind.self, forKey: .displayKind) ?? .chat
        title = try container.decodeIfPresent(String.self, forKey: .title)
        toolCallId = try container.decodeIfPresent(String.self, forKey: .toolCallId)
        toolKind = try container.decodeIfPresent(String.self, forKey: .toolKind)
        toolStatus = try container.decodeIfPresent(String.self, forKey: .toolStatus)
        sequence = try container.decodeIfPresent(Int.self, forKey: .sequence) ?? 0
    }
}
