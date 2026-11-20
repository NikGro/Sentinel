import MapKit
import SwiftUI

// Ansicht eines Ziels mit Standort, Straßenansicht, Notizen und Fotos.

/// Vollständiges Profil eines Ziels.
/// Alle Fotos eines Ziels, auch aus älteren Einzelbildfeldern.
func allAttachments(_ target: Target) -> [ChatAttachment] {
    var copy = target
    copy.normalize()
    return copy.anhaenge
}

struct TargetDetail: View {
    let targetId: String
    /// Standort auf der Karte neu setzen; nur verfügbar, wenn die Detailansicht über der Karte liegt.
    var placeOnMap: ((String) -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var editing: TargetEditorContext?

    var body: some View {
        if let target = lage.targets[targetId] {
            content(target)
        } else {
            ContentUnavailableView("Ziel wurde entfernt", systemImage: "person.slash")
        }
    }

    private func content(_ entity: Versioned<Target>) -> some View {
        let target = entity.data
        return List {
            if lage.position(ofTarget: entity) != nil {
                NavigateHereSection {
                    model.navigate(to: .target(entity.id))
                    dismiss()
                }
            }
            TargetMovementSection(entity: entity, placeOnMap: placeOnMap)
            Section {
                HistoryButton(subject: SpurSubject(art: .target, id: entity.id))
                // Ausgeschaltet: nichts Neues wird aufgezeichnet, Bisheriges bleibt bis zum Ablauf erhalten.
                Toggle("Verlauf aufzeichnen", isOn: Binding(
                    get: { target.aufzeichnung },
                    set: { on in
                        var next = target
                        next.aufzeichnung = on
                        lage.put(next, id: entity.id)
                    }
                ))
            }
            Section {
                HStack(alignment: .top, spacing: 16) {
                    RemoteImage(blobId: target.fotoBlob) {
                        ZStack {
                            Theme.target.opacity(0.2)
                            Image(systemName: target.art.symbolName)
                                .font(.largeTitle)
                                .foregroundStyle(Theme.target)
                        }
                    }
                    .frame(width: 110, height: 140)
                    .clipShape(.rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(target.displayName)
                            .font(.title3.weight(.bold))
                        if target.art == .fahrzeug, let secondary = target.secondaryName {
                            Text(secondary)
                                .font(.subheadline)
                        }
                        Text(target.art.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.target)
                        if let birthDate = target.birthDate, let age = target.age() {
                            Text("\(birthDate.formatted(date: .numeric, time: .omitted)), \(age) Jahre")
                                .font(.subheadline)
                        }
                        if !target.geburtsort.isEmpty {
                            Text("geb. in \(target.geburtsort)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !target.staatsangehoerigkeit.isEmpty {
                            Text(target.staatsangehoerigkeit)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            // Zielobjekte haben keine dynamische Quelle; ihr Standort wird nur von Hand gesetzt.
            if !target.supportsDynamicSource {
            Section("Standort") {
                if let position = lage.position(ofTarget: entity) {
                    LabeledContent("Von Hand gesetzt", value: Format.ago(position.date))
                } else {
                    Text("Kein Standort bekannt.")
                        .foregroundStyle(.secondary)
                }
                if let placeOnMap {
                    Button(target.standort == nil ? "Standort auf Karte setzen" : "Standort neu setzen", systemImage: "hand.tap") {
                        placeOnMap(entity.id)
                        dismiss()
                    }
                }
            }
            }

            if !target.anschrift.isEmpty || target.art == .objekt {
                Section("Anschrift") {
                    if !target.anschrift.isEmpty {
                        Text(target.anschrift)
                            .textSelection(.enabled)
                    }
                    LookAroundCard(address: target.anschrift, point: lage.position(ofTarget: entity)?.point)
                }
            }
            if !target.kennzeichen.isEmpty {
                Section {
                    LabeledContent(target.art == .person ? "Genutztes Fahrzeug" : "Kennzeichen") {
                        Text(target.kennzeichen)
                            .font(.body.monospaced().weight(.semibold))
                    }
                }
            }

            TextSection(title: "Notizen", text: target.notes)

            if !allAttachments(target).isEmpty {
                AttachmentsSection(attachments: .constant(allAttachments(target)), editable: false, marksTitlePhoto: true)
            }

            Section {
                Text("Zuletzt geändert von \(lage.name(of: entity.updatedBy)), \(Format.ago(entity.updatedDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        // Hinführen, Unterwegs und Standortquelle eng beieinander statt mit großen Abschnittsabständen.
        .listSectionSpacing(.compact)
        .navigationTitle(target.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Bearbeiten") { editing = TargetEditorContext(id: entity.id, target: target, isNew: false) }
            }
        }
        .sheet(item: $editing) { context in
            TargetEditor(context: context)
        }
    }
}

private struct TextSection: View {
    let title: String
    let text: String

    var body: some View {
        if !text.isEmpty {
            Section(title) {
                Text(text)
                    .textSelection(.enabled)
            }
        }
    }
}

/// Look-Around-Vorschau (Straßenansicht von Apple Karten) für eine Anschrift oder einen Standort, sofern Apple dort Aufnahmen hat.
struct LookAroundCard: View {
    let address: String
    let point: GeoPoint?

    @State private var scene: MKLookAroundScene?
    @State private var loaded = false

    var body: some View {
        Group {
            if let scene {
                LookAroundPreview(initialScene: scene)
                    .frame(height: 180)
                    .clipShape(.rect(cornerRadius: 12))
            } else if loaded {
                Label("Keine Straßenansicht verfügbar", systemImage: "binoculars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .task(id: "\(address)|\(point?.lat ?? 0)|\(point?.lon ?? 0)") {
            loaded = false
            scene = await Self.loadScene(address: address, point: point)
            loaded = true
        }
    }

    private static func loadScene(address: String, point: GeoPoint?) async -> MKLookAroundScene? {
        var coordinate = point?.coordinate
        if coordinate == nil, !address.isEmpty {
            let placemarks = try? await CLGeocoder().geocodeAddressString(address)
            coordinate = placemarks?.first?.location?.coordinate
        }
        guard let coordinate else { return nil }
        return try? await MKLookAroundSceneRequest(coordinate: coordinate).scene
    }
}
