import SwiftUI

struct SessionPickerView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var editingSession: ChatSession?
    @State private var editName: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.createNewSession() }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            
            List(viewModel.sessionManager.sessions) { session in
                HStack {
                    if editingSession?.id == session.id {
                        TextField("Session name", text: $editName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                viewModel.sessionManager.renameSession(session, to: editName)
                                editingSession = nil
                            }
                    } else {
                        Text(session.name)
                            .lineLimit(1)
                        
                        if session.id == viewModel.sessionManager.currentSession?.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    if editingSession?.id != session.id {
                        Button(action: { 
                            editingSession = session
                            editName = session.name
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: { viewModel.deleteSession(session) }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if editingSession?.id != session.id {
                        viewModel.switchToSession(session)
                    }
                }
            }
            .listStyle(.plain)
        }
        .frame(width: 250, height: 300)
    }
}
