import SwiftUI

// Verläufe an zentraler Stelle: Auswahl der Spuren (Plus-Menü der Karte) und die Übersicht unter „Mehr“ mit
// Aufzeichnung je Objekt und Aufbewahrung.

/// Liste aller Spuren zum Auswählen; optional mit dem Schalter „Aufzeichnen“ je Objekt.
struct HistorySubjectList: View {
    @Binding var selection: Set<SpurSubject>
    var showsRecording = false

    @Environment(LageStore.self) private var lage

    var body: some View {
        Section("Fahnder") {
            ForEach(lage.sortedMembers) { member in
                row(SpurSubject(art: .member, id: member.id), title: lage.label(of: member.data), symbol: "person.fill",
                    recording: member.id == lage.selfId ? recordingBinding(member) : nil)
            }
        }
        if !lage.sortedTargets.isEmpty {
            Section("Ziele") {
                ForEach(lage.sortedTargets) { target in
                    row(SpurSubject(art: .target, id: target.id), title: target.data.displayName, symbol: target.data.art.symbolName,
                        recording: Binding(get: { target.data.aufzeichnung }, set: { on in
                            var next = target.data
                            next.aufzeichnung = on
                            lage.put(next, id: target.id)
                        }))
                }
            }
        }
        if !lage.sortedVehicles.isEmpty {
            Section("Fahrzeuge") {
                ForEach(lage.sortedVehicles) { vehicle in
                    row(SpurSubject(art: .vehicle, id: vehicle.id), title: vehicle.data.funkrufname, symbol: "car.fill",
                        recording: Binding(get: { vehicle.data.aufzeichnung }, set: { on in
                            var next = vehicle.data
                            next.aufzeichnung = on
                            lage.put(next, id: vehicle.id)
                        }))
                }
            }
        }
        if !lage.trackers.isEmpty {
            Section("Tracker") {
                ForEach(lage.trackers.values.sorted { $0.data.name < $1.data.name }) { tracker in
                    row(SpurSubject(art: .tracker, id: tracker.id), title: tracker.data.name, symbol: "sensor.tag.radiowaves.forward.fill",
                        recording: Binding(get: { tracker.data.records }, set: { on in
                            var next = tracker.data
                            next.aufzeichnung = on
                            lage.put(next, id: tracker.id)
                        }))
                }
            }
        }
    }

    private func recordingBinding(_ member: Versioned<Member>) -> Binding<Bool> {
        Binding(get: { member.data.aufzeichnung }, set: { on in
            var next = member.data
            next.aufzeichnung = on
            lage.put(next, id: member.id)
        })
    }

    private func row(_ subject: SpurSubject, title: String, symbol: String, recording: Binding<Bool>?) -> some View {
        HStack(spacing: 12) {
            Button {
                if selection.contains(subject) { selection.remove(subject) } else { selection.insert(subject) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selection.contains(subject) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selection.contains(subject) ? Color.accentColor : Color.secondary)
                    Label(title, systemImage: symbol)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if showsRecording, let recording {
                Toggle("Aufzeichnen", isOn: recording)
                    .labelsHidden()
                    .accessibilityLabel("\(title) aufzeichnen")
            }
        }
    }
}

/// Auswahl aus dem Plus-Menü der Karte: Wessen Verlauf soll gezeigt werden?
struct HistoryPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<SpurSubject> = []

    var body: some View {
        NavigationStack {
            List {
                HistorySubjectList(selection: $selection)
            }
            .navigationTitle("Verlauf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anzeigen") {
                        model.historySubjects = Array(selection)
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .onAppear { selection = Set(model.historySubjects) }
        }
    }
}

/// Mehr › Verläufe: alle Spuren, was aufgezeichnet wird, Aufbewahrung, und von hier auf die Karte.
struct HistoryOverviewScreen: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Set<SpurSubject> = []
    @State private var retentionDays: Int?
    @State private var failure: String?

    var body: some View {
        List {
            Section {
                Button("Auswahl auf der Karte zeigen", systemImage: "map") {
                    model.historySubjects = Array(selection)
                    model.showMap()
                }
                .disabled(selection.isEmpty)
            } footer: {
                Text("Antippen wählt eine Spur aus; der Schalter rechts legt fest, ob weiter aufgezeichnet wird. Abschalten löscht nichts.")
            }
            HistorySubjectList(selection: $selection, showsRecording: true)
            Section {
                Picker("Aufbewahren", selection: Binding(
                    get: { retentionDays ?? 30 },
                    set: { days in
                        retentionDays = days
                        Task {
                            do { try await model.client?.setSpurRetentionDays(days) } catch { failure = error.localizedDescription }
                        }
                    }
                )) {
                    ForEach([7, 14, 30, 60, 90, 180, 365], id: \.self) { Text("\($0) Tage").tag($0) }
                }
                .disabled(retentionDays == nil)
            } header: {
                Text("Aufbewahrung")
            } footer: {
                Text("So lange bleiben die Verläufe auf dem Server. Der eigene Verlauf entsteht nur im Dienst.")
            }
        }
        .navigationTitle("Verläufe")
        .navigationBarTitleDisplayMode(.inline)
        .task { retentionDays = try? await model.client?.spurRetentionDays() }
        .alert("Hinweis", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }
}
