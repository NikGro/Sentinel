import SwiftUI

/// Erste Einrichtung: Server und Zugangscode. Das Profil folgt nach erfolgreicher Anmeldung.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var server = LocalSettings.defaultServer
    @State private var code = ""
    @State private var isWorking = false
    @State private var failure: String?
    @FocusState private var focus: Field?

    private enum Field {
        case server, code
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 56))
                            .foregroundStyle(.tint)
                        Text("SENTINEL")
                            .font(.largeTitle.weight(.bold))
                            .tracking(4)
                        Text("Gemeinsame Lagekarte für Observation und Fahndung")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Serveradresse", text: $server)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .server)
                        .submitLabel(.next)
                        .onSubmit { focus = .code }
                    TextField("Zugangscode", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .focused($focus, equals: .code)
                        .submitLabel(.go)
                        .onSubmit(connect)
                } header: {
                    Text("Anmeldung")
                } footer: {
                    Text("Den Zugangscode gibt es in Sentinel Web. Die Verbindung ist immer verschlüsselt.")
                }

                if let failure {
                    Section {
                        Label(failure, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: connect) {
                        HStack {
                            Spacer()
                            if isWorking {
                                ProgressView()
                            } else {
                                Text("Verbinden")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isWorking || code.trimmingCharacters(in: .whitespaces).count < 4)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func connect() {
        guard !isWorking else { return }
        isWorking = true
        failure = nil
        Task {
            defer { isWorking = false }
            do {
                try await model.enroll(server: server, code: code)
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}
