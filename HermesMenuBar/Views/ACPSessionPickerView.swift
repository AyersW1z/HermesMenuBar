import SwiftUI

struct ACPSessionPickerView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Attach Existing ACP Session")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Text("Reconnect a Hermes ACP session and bind it to a local chat.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Button("Done") {
                    viewModel.showingACPSessionPicker = false
                }
                .buttonStyle(.bordered)
            }

            if viewModel.availableACPSessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                    Text("No ACP sessions found")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Start one in Hermes first, then refresh here.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.availableACPSessions) { session in
                            Button {
                                viewModel.connectToACPSession(session.id)
                            } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(session.id)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(session.cwd)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.55))
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Color(red: 0.54, green: 0.82, blue: 1.0))
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                Button {
                    viewModel.refreshAvailableACPSessions()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }

            if viewModel.isLoadingACPSessions {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading ACP sessions…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 560, height: 420)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.13, blue: 0.20),
                    Color(red: 0.07, green: 0.09, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
    }
}
