import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Session Diagnostics")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Button("Done") {
                    viewModel.showingDiagnostics = false
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let session = viewModel.currentSession {
                        diagnosticRow(title: "Local Session", value: session.id.uuidString)
                        diagnosticRow(title: "ACP Session", value: session.acpSessionId ?? "Not attached")
                        diagnosticRow(title: "Status", value: viewModel.statusText(for: session))
                        diagnosticRow(title: "Messages", value: "\(session.messages.count)")
                        diagnosticRow(title: "Pinned", value: session.isPinned ? "Yes" : "No")
                        diagnosticRow(title: "Archived", value: session.isArchived ? "Yes" : "No")

                        let runtime = viewModel.currentRuntimeState
                        diagnosticRow(title: "Transport", value: runtime.transportState.rawValue.capitalized)
                        diagnosticRow(title: "Request Active", value: runtime.isRequestActive ? "Yes" : "No")
                        diagnosticRow(title: "Last Error", value: runtime.lastError ?? "None")
                    } else {
                        Text("No active session.")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 6)
            }
        }
        .padding(28)
        .frame(width: 560, height: 420)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.15, blue: 0.22),
                    Color(red: 0.08, green: 0.10, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
    }

    private func diagnosticRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .textSelection(.enabled)
        }
    }
}
