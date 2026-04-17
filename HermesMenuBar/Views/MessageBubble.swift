import SwiftUI
import AppKit

struct MessageBubble: View {
    let message: Message

    private var isUser: Bool {
        message.role == .user && message.displayKind == .chat
    }

    private let bubbleContentMaxWidth: CGFloat = 520
    private let thoughtContentMaxWidth: CGFloat = 380
    private let toolContentMaxWidth: CGFloat = 460

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if isUser {
                Spacer(minLength: 72)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: cardSpacing) {
                HStack(spacing: 8) {
                    Image(systemName: headerIconName)
                        .font(.system(size: headerIconSize, weight: .black))
                    Text(headerTitle)
                        .font(.system(size: headerFontSize, weight: .bold))
                    if let toolStatus = message.toolStatus, message.displayKind == .tool {
                        Text(toolStatus.capitalized)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(toolStatusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(toolStatusColor.opacity(0.14))
                            )
                    } else if message.isStreaming {
                        Text("typing")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(headerColor.opacity(0.7))
                    }
                }
                .foregroundStyle(headerColor)

                if !message.attachments.isEmpty {
                    attachmentGrid
                }

                if !message.content.isEmpty {
                    Group {
                        if message.displayKind == .tool {
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(message.content)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(14)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.black.opacity(0.20))
                            )
                        } else {
                            MarkdownTextView(markdown: message.content)
                        }
                    }
                    .foregroundStyle(isUser ? Color.white : Color(red: 0.93, green: 0.95, blue: 1.0))
                    .frame(maxWidth: contentWidth, alignment: isUser ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if message.isStreaming {
                    HStack(spacing: 6) {
                        Circle().frame(width: 5, height: 5)
                        Circle().frame(width: 5, height: 5)
                        Circle().frame(width: 5, height: 5)
                    }
                    .foregroundStyle(headerColor.opacity(0.7))
                }
            }
            .frame(maxWidth: containerWidth, alignment: isUser ? .trailing : .leading)
            .fixedSize(horizontal: true, vertical: false)
            .padding(cardPadding)
            .background(backgroundStyle)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)

            if !isUser {
                Spacer(minLength: 72)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var attachmentGrid: some View {
        HStack(spacing: 10) {
            ForEach(message.attachments) { attachment in
                if let image = NSImage(contentsOf: attachment.fileURL) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 128, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: contentWidth, alignment: isUser ? .trailing : .leading)
    }

    private var backgroundStyle: some View {
        Group {
            if isUser {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.53, blue: 0.96),
                                Color(red: 0.17, green: 0.39, blue: 0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if message.displayKind == .tool {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.09, green: 0.12, blue: 0.18),
                                Color(red: 0.12, green: 0.16, blue: 0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if message.displayKind == .thought {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.17, green: 0.14, blue: 0.10),
                                Color(red: 0.23, green: 0.18, blue: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }

    private var borderColor: Color {
        switch message.displayKind {
        case .chat:
            return isUser ? Color.white.opacity(0.10) : Color.white.opacity(0.07)
        case .thought:
            return Color(red: 0.93, green: 0.77, blue: 0.44).opacity(0.20)
        case .tool:
            return Color(red: 0.63, green: 0.82, blue: 1.0).opacity(0.18)
        }
    }

    private var headerTitle: String {
        switch message.displayKind {
        case .chat:
            return message.role == .user ? "You" : "Hermes"
        case .thought:
            return message.title ?? "Hermes thinking"
        case .tool:
            return message.title ?? "Tool"
        }
    }

    private var headerIconName: String {
        switch message.displayKind {
        case .chat:
            return message.role == .user ? "person.fill" : "sparkles"
        case .thought:
            return "brain"
        case .tool:
            switch message.toolKind {
            case "execute":
                return "terminal"
            case "read":
                return "doc.text.magnifyingglass"
            case "edit":
                return "square.and.pencil"
            case "fetch":
                return "globe"
            case "think":
                return "brain"
            default:
                return "hammer"
            }
        }
    }

    private var headerColor: Color {
        switch message.displayKind {
        case .chat:
            return isUser ? Color.white.opacity(0.88) : Color(red: 0.76, green: 0.86, blue: 1.0)
        case .thought:
            return Color(red: 0.95, green: 0.80, blue: 0.50)
        case .tool:
            return Color(red: 0.68, green: 0.86, blue: 1.0)
        }
    }

    private var contentWidth: CGFloat {
        switch message.displayKind {
        case .chat:
            return bubbleContentMaxWidth
        case .thought:
            return thoughtContentMaxWidth
        case .tool:
            return toolContentMaxWidth
        }
    }

    private var containerWidth: CGFloat {
        contentWidth
    }

    private var cardPadding: CGFloat {
        switch message.displayKind {
        case .chat:
            return 18
        case .thought:
            return 16
        case .tool:
            return 16
        }
    }

    private var cardSpacing: CGFloat {
        switch message.displayKind {
        case .chat:
            return 10
        case .thought:
            return 8
        case .tool:
            return 10
        }
    }

    private var cornerRadius: CGFloat {
        switch message.displayKind {
        case .chat:
            return 24
        case .thought:
            return 22
        case .tool:
            return 20
        }
    }

    private var headerIconSize: CGFloat {
        switch message.displayKind {
        case .chat:
            return 11
        case .thought, .tool:
            return 10
        }
    }

    private var headerFontSize: CGFloat {
        switch message.displayKind {
        case .chat:
            return 12
        case .thought, .tool:
            return 11
        }
    }

    private var shadowColor: Color {
        switch message.displayKind {
        case .chat:
            return isUser ? Color.blue.opacity(0.12) : Color.black.opacity(0.10)
        case .thought:
            return Color.orange.opacity(0.08)
        case .tool:
            return Color.blue.opacity(0.08)
        }
    }

    private var shadowRadius: CGFloat {
        switch message.displayKind {
        case .chat:
            return 18
        case .thought, .tool:
            return 10
        }
    }

    private var shadowOffset: CGFloat {
        switch message.displayKind {
        case .chat:
            return 8
        case .thought, .tool:
            return 4
        }
    }

    private var toolStatusColor: Color {
        switch message.toolStatus?.lowercased() {
        case "completed":
            return Color(red: 0.55, green: 0.86, blue: 0.62)
        case "running":
            return Color(red: 0.98, green: 0.79, blue: 0.40)
        default:
            return Color.white.opacity(0.75)
        }
    }
}
