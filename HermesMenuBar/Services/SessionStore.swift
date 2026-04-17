import Foundation
import UniformTypeIdentifiers

struct SessionsSnapshot: Codable {
    var sessions: [ChatSession]
    var currentSessionID: UUID?
}

struct SessionStore {
    let baseDirectory: URL
    let fileManager: FileManager

    init(
        baseDirectory: URL = SessionStore.defaultBaseDirectory(),
        fileManager: FileManager = .default
    ) {
        self.baseDirectory = baseDirectory
        self.fileManager = fileManager
    }

    var sessionsFileURL: URL {
        baseDirectory.appendingPathComponent("sessions.json")
    }

    var attachmentsDirectoryURL: URL {
        baseDirectory.appendingPathComponent("attachments", isDirectory: true)
    }

    func load() throws -> SessionsSnapshot? {
        guard fileManager.fileExists(atPath: sessionsFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: sessionsFileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(SessionsSnapshot.self, from: data)
    }

    func save(_ snapshot: SessionsSnapshot) throws {
        try prepareDirectory(baseDirectory)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)

        let tempURL = sessionsFileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)

        if fileManager.fileExists(atPath: sessionsFileURL.path) {
            _ = try fileManager.replaceItemAt(sessionsFileURL, withItemAt: tempURL)
        } else {
            try fileManager.moveItem(at: tempURL, to: sessionsFileURL)
        }
    }

    func importImage(from sourceURL: URL) throws -> MessageAttachment {
        try prepareDirectory(attachmentsDirectoryURL)

        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destinationURL = attachmentsDirectoryURL.appendingPathComponent(filename)

        if sourceURL.standardizedFileURL != destinationURL.standardizedFileURL {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }

        let mimeType = mimeType(for: destinationURL)

        return MessageAttachment(
            kind: .image,
            filename: sourceURL.lastPathComponent,
            filePath: destinationURL.path,
            mimeType: mimeType
        )
    }

    static func defaultBaseDirectory() -> URL {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return supportDirectory.appendingPathComponent("HermesMenuBar", isDirectory: true)
    }

    private func prepareDirectory(_ directoryURL: URL) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func mimeType(for fileURL: URL) -> String {
        if let type = UTType(filenameExtension: fileURL.pathExtension),
           let mimeType = type.preferredMIMEType {
            return mimeType
        }

        return "image/png"
    }
}
