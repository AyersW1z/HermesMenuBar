import Foundation

final class HermesImagePreprocessor {
    private let pythonURL: URL?
    private let hermesAgentDirectory: URL?

    init() {
        let hermesPath = "\(NSHomeDirectory())/.local/bin/hermes"
        if let resolvedPath = try? FileManager.default.destinationOfSymbolicLink(atPath: hermesPath) {
            let resolvedURL = URL(fileURLWithPath: resolvedPath)
            pythonURL = resolvedURL.deletingLastPathComponent().appendingPathComponent("python")
            hermesAgentDirectory = resolvedURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        } else {
            pythonURL = URL(fileURLWithPath: "\(NSHomeDirectory())/.hermes/hermes-agent/venv/bin/python")
            hermesAgentDirectory = URL(fileURLWithPath: "\(NSHomeDirectory())/.hermes/hermes-agent")
        }
    }

    func enrichPrompt(text: String, attachments: [MessageAttachment]) async -> HermesPromptPayload {
        guard !attachments.isEmpty else {
            return HermesPromptPayload(text: text)
        }

        var notes: [String] = []
        var imageInputs: [HermesImageInput] = []

        for attachment in attachments where attachment.kind == .image {
            if let dataURL = makeDataURL(for: attachment) {
                imageInputs.append(HermesImageInput(filename: attachment.filename, dataURL: dataURL))
            }

            let note = await analyzeAttachment(attachment)
            notes.append(note)
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = notes.joined(separator: "\n\n")
        let finalText: String

        if !prefix.isEmpty && !trimmedText.isEmpty {
            finalText = "\(prefix)\n\n\(trimmedText)"
        } else if !prefix.isEmpty {
            finalText = prefix
        } else if !trimmedText.isEmpty {
            finalText = trimmedText
        } else {
            finalText = "Please analyze the attached image(s)."
        }

        return HermesPromptPayload(text: finalText, images: imageInputs)
    }

    private func analyzeAttachment(_ attachment: MessageAttachment) async -> String {
        do {
            if let analysis = try await runVisionAnalyze(for: attachment.fileURL) {
                return """
                [The user attached an image. Here's what it contains:
                \(analysis)]
                [If you need a closer look, use vision_analyze with image_url: \(attachment.fileURL.path)]
                """
            }
        } catch {
            return """
            [The user attached an image but analysis failed (\(error.localizedDescription)).
            You can try examining it with vision_analyze using image_url: \(attachment.fileURL.path)]
            """
        }

        return """
        [The user attached an image but it could not be analyzed automatically.
        You can try examining it with vision_analyze using image_url: \(attachment.fileURL.path)]
        """
    }

    private func runVisionAnalyze(for imageURL: URL) async throws -> String? {
        guard let pythonURL, let hermesAgentDirectory else {
            return nil
        }

        guard FileManager.default.isExecutableFile(atPath: pythonURL.path) else {
            return nil
        }

        let script = """
        import asyncio
        import json
        import sys

        from tools.vision_tools import vision_analyze_tool

        async def main():
            result = await vision_analyze_tool(
                image_url=sys.argv[1],
                user_prompt=(
                    "Describe everything visible in this image in thorough detail. "
                    "Include any text, code, UI, data, objects, people, layout, colors, "
                    "and any other notable visual information."
                ),
            )
            print(result)

        asyncio.run(main())
        """

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let process = Process()
                    process.currentDirectoryURL = hermesAgentDirectory
                    process.executableURL = pythonURL
                    process.arguments = ["-c", script, imageURL.path]

                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe

                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    guard process.terminationStatus == 0 else {
                        let stderr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: NSError(
                            domain: "HermesImagePreprocessor",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: stderr]
                        ))
                        return
                    }

                    guard let output = String(data: outputData, encoding: .utf8),
                          let data = output.data(using: .utf8),
                          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let analysis = json["analysis"] as? String else {
                        continuation.resume(returning: nil)
                        return
                    }

                    continuation.resume(returning: analysis.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func makeDataURL(for attachment: MessageAttachment) -> String? {
        guard let data = try? Data(contentsOf: attachment.fileURL) else {
            return nil
        }

        return "data:\(attachment.mimeType);base64,\(data.base64EncodedString())"
    }
}
