import SwiftUI

struct MarkdownTextView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                switch segment {
                case .text(let text):
                    if let rendered = try? AttributedString(
                        markdown: text,
                        options: AttributedString.MarkdownParsingOptions(
                            interpretedSyntax: .inlineOnlyPreservingWhitespace
                        )
                    ) {
                        Text(rendered)
                            .textSelection(.enabled)
                    } else {
                        Text(text)
                            .textSelection(.enabled)
                    }
                case .code(let code):
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(code)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(red: 0.90, green: 0.94, blue: 1.0))
                            .textSelection(.enabled)
                            .padding(14)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 0.10, green: 0.13, blue: 0.19))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var segments: [MarkdownSegment] {
        var parsed: [MarkdownSegment] = []
        let pieces = markdown.components(separatedBy: "```")

        for index in pieces.indices {
            let piece = pieces[index]
            if piece.isEmpty { continue }
            if index.isMultiple(of: 2) {
                parsed.append(.text(piece))
            } else {
                let lines = piece.split(separator: "\n", omittingEmptySubsequences: false)
                if lines.count > 1 {
                    parsed.append(.code(lines.dropFirst().joined(separator: "\n")))
                } else {
                    parsed.append(.code(piece))
                }
            }
        }

        return parsed.isEmpty ? [.text(markdown)] : parsed
    }
}

private enum MarkdownSegment {
    case text(String)
    case code(String)
}
