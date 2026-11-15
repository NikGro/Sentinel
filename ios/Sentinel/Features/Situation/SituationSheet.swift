import SwiftUI

/// Lageübersicht: Einsatzinformationen, Funkkanal, Modus und Erreichbarkeit der Kräfte.
struct SituationSheet: View {
    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showsChannelEditor = false
    @State private var showsNotesEditor = false
    @State private var pendingMode: Modus?

    var body: some View {
        NavigationStack {
            List {
                Section("Einsatz") {
                    LabeledContent("Lage") {
                        Text(lage.operation.titel.isEmpty ? "Ohne Titel" : lage.operation.titel)
                    }
                    Button { showsChannelEditor = true } label: {
                        LabeledContent {
                            Text(lage.operation.funkkanal ?? "nicht gesetzt")
                                .monospacedDigit()
                        } label: {
                            Label("Funkkanal", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                    .tint(.primary)
                    if !lage.operation.hinweise.isEmpty {
                        Text(lage.operation.hinweise)
                            .font(.callout)
                    }
                    Button("Titel und Hinweise bearbeiten", systemImage: "square.and.pencil") { showsNotesEditor = true }
                }

                Section {
                    ForEach(Modus.allCases) { modus in
                        Button {
                            if modus != lage.operation.modus { pendingMode = modus }
                        } label: {
                            HStack {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(modus.title)
                                        Text(modus.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: modus.symbolName)
                                        .foregroundStyle(Theme.color(for: modus))
                                }
                                Spacer()
                                if modus == lage.operation.modus {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                } header: {
                    Text("Modus")
                } footer: {
                    Text("Der Modus gilt für alle. Beim Wechsel geht nichts verloren: Die A-Position wird in der Fahndung zum letzten bekannten Standort, Bestreifung und Standort bleiben beim Rückwechsel gespeichert.")
                }

                if lage.operation.modus == .observation {
                    Section("A-Position") {
                        if let holder = lage.aHolder, let a = lage.operation.a {
                            LabeledContent(holder.data.funkrufname) {
                                Text("seit \(Format.time(Date(timeIntervalSince1970: a.seit / 1000)))")
                            }
                        } else {
                            Text("Niemand hält die A-Position.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Kräfte") {
                    ForEach(lage.sortedMembers) { member in
                        HStack(spacing: 12) {
                            Avatar(blobId: member.data.fotoBlob, fallbackText: member.data.funkrufname, size: 36, tint: lage.isOnline(member.id) ? .green : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.data.funkrufname)
                                    .font(.body.weight(.semibold))
                                Text(member.data.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let url = PhoneNumber.callURL(member.data.telefon), member.id != lage.selfId {
                                Button("Anrufen", systemImage: "phone.fill") { openURL(url) }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.circle)
                                    .tint(.green)
                                    .accessibilityLabel("\(member.data.funkrufname) anrufen")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lageübersicht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showsChannelEditor) {
                ChannelEditor(current: lage.operation.funkkanal)
                    .presentationDetents([.height(260)])
            }
            .sheet(isPresented: $showsNotesEditor) {
                SituationNotesEditor(title: lage.operation.titel, notes: lage.operation.hinweise)
            }
            .confirmationDialog(
                "Modus für alle auf „\(pendingMode?.title ?? "")“ ändern?",
                isPresented: Binding(get: { pendingMode != nil }, set: { if !$0 { pendingMode = nil } }),
                titleVisibility: .visible
            ) {
                Button("Modus wechseln") {
                    if let pendingMode { lage.setMode(pendingMode) }
                }
            }
        }
    }
}

/// Funkkanal setzen: 1 bis 5 Ziffern.
struct ChannelEditor: View {
    let current: String?

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kanal", text: $text)
                        .keyboardType(.numberPad)
                        .font(.title2.monospacedDigit())
                        .focused($focused)
                        .onChange(of: text) { _, value in
                            text = String(value.filter(\.isNumber).prefix(5))
                        }
                } footer: {
                    Text("1 bis 5 Ziffern. Gilt für alle und wird in jeder Ansicht angezeigt.")
                }
            }
            .navigationTitle("Funkkanal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Setzen") {
                        lage.setChannel(text.isEmpty ? nil : text)
                        dismiss()
                    }
                    .disabled(!text.isEmpty && !RadioChannel.isValid(text))
                }
            }
            .onAppear {
                text = current ?? ""
                focused = true
            }
        }
    }
}

private struct SituationNotesEditor: View {
    @State var title: String
    @State var notes: String

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Titel") {
                    TextField("z. B. Observation Musterstraße", text: $title)
                }
                Section("Einsatzhinweise") {
                    TextField("Auftrag, Treffpunkt, Eigensicherung …", text: $notes, axis: .vertical)
                        .lineLimit(5...14)
                }
            }
            .navigationTitle("Einsatzinformationen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        lage.setSituation(title: String(title.prefix(80)), notes: String(notes.prefix(4000)))
                        dismiss()
                    }
                }
            }
        }
    }
}
