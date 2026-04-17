import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var editingSessionID: UUID?
    @State private var editingName = ""
    @State private var dropActive = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
                .background(Color.white.opacity(0.08))
            mainPanel
        }
        .frame(minWidth: 980, minHeight: 720)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.11),
                    Color(red: 0.08, green: 0.10, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $viewModel.showingACPSessionPicker) {
            ACPSessionPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingDiagnostics) {
            DiagnosticsView(viewModel: viewModel)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hermes")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Modern menu bar workspace for long-running chats, images, and ACP sessions.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField(
                "",
                text: $viewModel.searchText,
                prompt: Text("Search sessions").foregroundColor(.white.opacity(0.32))
            )
                .textFieldStyle(.plain)
                .foregroundStyle(.white.opacity(0.92))
                .tint(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    actionPill(title: "New", icon: "plus") {
                        viewModel.createNewSession()
                    }
                    actionPill(title: "Attach ACP", icon: "link.badge.plus") {
                        viewModel.openACPSessionPicker()
                    }
                }

                actionPill(
                    title: viewModel.showArchivedSessions ? "Hide Archived" : "Show Archived",
                    icon: "archivebox",
                    fullWidth: true
                ) {
                    viewModel.showArchivedSessions.toggle()
                }
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.visibleSessions) { session in
                        sessionRow(session)
                    }
                }
                .padding(.trailing, 4)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    viewModel.showingDiagnostics = true
                } label: {
                    Label("Diagnostics", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.75))

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(22)
        .frame(width: 300)
        .background(Color.black.opacity(0.18))
    }

    private func sessionRow(_ session: ChatSession) -> some View {
        let isSelected = viewModel.currentSession?.id == session.id

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    if editingSessionID == session.id {
                        TextField("Session name", text: $editingName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .tint(.white)
                            .onSubmit {
                                viewModel.renameSession(session, to: editingName)
                                editingSessionID = nil
                            }
                    } else {
                        Text(session.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Text(session.previewText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    if session.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.95, green: 0.76, blue: 0.31))
                    }

                    Text(viewModel.statusText(for: session))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            HStack(spacing: 10) {
                inlineIconButton(systemName: session.isPinned ? "pin.slash.fill" : "pin.fill") {
                    viewModel.togglePin(session)
                }
                inlineIconButton(systemName: "pencil") {
                    editingSessionID = session.id
                    editingName = session.name
                }
                inlineIconButton(systemName: session.isArchived ? "tray.full.fill" : "archivebox.fill") {
                    viewModel.toggleArchive(session)
                }
                inlineIconButton(systemName: "trash.fill") {
                    viewModel.deleteSession(session)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            if editingSessionID != session.id {
                viewModel.switchToSession(session)
            }
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            topBar

            if let banner = viewModel.backgroundRequestBanner {
                Text(banner)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.86, green: 0.90, blue: 1.0))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.13, green: 0.18, blue: 0.28))
            }

            messageArea
            composer
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.currentSession?.name ?? "No Session")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    statusChip
                    if let acpSessionID = viewModel.currentSession?.acpSessionId {
                        Text(acpSessionID.prefix(12))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }

            Spacer()

            Button {
                viewModel.clearCurrentSession()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .foregroundStyle(.white.opacity(0.86))

            Button {
                viewModel.showingDiagnostics = true
            } label: {
                Label("Inspect", systemImage: "waveform.path.ecg")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .foregroundStyle(.white.opacity(0.86))
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .background(Color.white.opacity(0.03))
    }

    private var statusChip: some View {
        let state = viewModel.currentRuntimeState
        let color: Color

        switch state.transportState {
        case .ready:
            color = state.isRequestActive ? Color(red: 0.34, green: 0.71, blue: 1.0) : Color(red: 0.35, green: 0.82, blue: 0.58)
        case .connecting:
            color = Color(red: 0.94, green: 0.70, blue: 0.28)
        case .error:
            color = Color(red: 0.96, green: 0.43, blue: 0.43)
        case .disconnected:
            color = Color.white.opacity(0.35)
        }

        return Text(viewModel.currentRuntimeState.isRequestActive ? "Streaming" : viewModel.statusText(for: viewModel.currentSession ?? ChatSession(name: "Unknown")))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.14))
            )
    }

    private var messageArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.currentMessages.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.currentMessages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(24)
            }
            .onChange(of: viewModel.currentMessages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.currentMessages.last?.content) {
                scrollToBottom(proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("A cleaner Hermes workspace")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Sessions stay organized, ACP links stay attached, markdown renders properly, and images can be added directly into the conversation.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                featureCard(icon: "paperclip", title: "Images", subtitle: "Attach screenshots and references")
                featureCard(icon: "doc.richtext", title: "Markdown", subtitle: "Readable code blocks and lists")
                featureCard(icon: "square.stack.3d.up.fill", title: "Sessions", subtitle: "Search, pin, archive, reconnect")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.15, blue: 0.24),
                            Color(red: 0.09, green: 0.11, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var composer: some View {
        VStack(spacing: 14) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !viewModel.draftImageURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.draftImageURLs, id: \.self) { imageURL in
                            attachmentPreview(url: imageURL)
                        }
                    }
                }
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(dropActive ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(dropActive ? Color(red: 0.38, green: 0.70, blue: 1.0) : Color.white.opacity(0.08), lineWidth: 1.2)
                    )

                VStack(spacing: 14) {
                    ComposerTextView(text: $viewModel.inputText, isEnabled: !viewModel.isComposerLockedByAnotherSession) {
                        viewModel.sendMessage()
                    }
                    .frame(height: 110)

                    HStack {
                        Button {
                            viewModel.attachImages()
                        } label: {
                            Label("Image", systemImage: "paperclip")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.78))

                        Text("Enter to send, Shift+Enter for newline")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.42))

                        Spacer()

                        if viewModel.hasActiveRequestInCurrentSession {
                            Button {
                                DebugLogger.log("[ChatView] stop button tapped")
                                viewModel.cancelRequest()
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(Color(red: 0.94, green: 0.43, blue: 0.43))
                        } else {
                            Button {
                                DebugLogger.log("[ChatView] send button tapped")
                                viewModel.sendMessage()
                            } label: {
                                Label("Send", systemImage: "arrow.up.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!viewModel.canSend)
                        }
                    }
                }
                .padding(18)

                if viewModel.inputText.isEmpty {
                    Text(viewModel.isComposerLockedByAnotherSession ? "Finish the active background reply before sending from another session." : "Ask Hermes something, or drop images here…")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 28)
                        .padding(.leading, 24)
                        .allowsHitTesting(false)
                }
            }
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dropActive, perform: handleDrop(providers:))
        }
        .padding(24)
        .background(Color.white.opacity(0.03))
    }

    private func featureCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.58, green: 0.82, blue: 1.0))
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func actionPill(title: String, icon: String, fullWidth: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, fullWidth ? 14 : 10)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func inlineIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.62))
        }
        .buttonStyle(.plain)
    }

    private func attachmentPreview(url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            Button {
                viewModel.removeDraftImage(url)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                Task { @MainActor in
                    viewModel.addDraftImages(from: [url])
                }
            }
        }
        return true
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = viewModel.currentMessages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}
