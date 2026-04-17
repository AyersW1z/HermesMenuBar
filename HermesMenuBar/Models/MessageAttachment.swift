import Foundation

struct MessageAttachment: Identifiable, Codable, Equatable, Hashable {
    enum Kind: String, Codable {
        case image
    }

    let id: UUID
    var kind: Kind
    var filename: String
    var filePath: String
    var mimeType: String

    init(
        id: UUID = UUID(),
        kind: Kind,
        filename: String,
        filePath: String,
        mimeType: String
    ) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.filePath = filePath
        self.mimeType = mimeType
    }

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
}
