import SwiftUI

/// Kurzübersicht zu einem angetippten Kartenobjekt.
struct QuickLookSheet: View {
    let selection: MapSelection
    let placeLastKnown: () -> Void

    @Environment(LageStore.self) private var lage

    var body: some View {
        NavigationStack {
            Group {
                switch selection {
                case .member(let id):
                    if let member = lage.members[id] { MemberQuickLook(member: member) } else { gone }
                case .vehicle(let id):
                    if let vehicle = lage.vehicles[id] { VehicleDetail(vehicleId: vehicle.id) } else { gone }
                case .target(let id):
                    if lage.targets[id] != nil { TargetDetail(targetId: id) } else { gone }
                case .lastKnown:
                    LastKnownQuickLook(placeLastKnown: placeLastKnown)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var gone: some View {
        ContentUnavailableView("Nicht mehr vorhanden", systemImage: "questionmark.circle")
    }
}

/// Schnellübersicht eines Fahnders mit Anruf- und Navigationsknopf.
struct MemberQuickLook: View {
    let member: Versioned<Member>

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private var position: Position? { lage.positions[member.id] }
    private var vehicle: Versioned<Vehicle>? { member.data.fahrzeugId.flatMap { lage.vehicles[$0] } }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Avatar(blobId: member.data.fotoBlob, fallbackText: member.data.funkrufname, size: 72, tint: lage.isOnline(member.id) ? .green : .gray)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.data.funkrufname)
                            .font(.title2.weight(.bold))
                        Text(member.data.name)
                        Text(member.data.dienststelle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)

                HStack(spacing: 12) {
                    if let url = PhoneNumber.callURL(member.data.telefon) {
                        Button { openURL(url) } label: {
                            Label("Anrufen", systemImage: "phone.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.green)
                    }
                    if position != nil, member.id != lage.selfId {
                        Button {
                            model.navigate(to: .member(member.id))
                            dismiss()
                        } label: {
                            Label("Hinführen", systemImage: "location.north.line.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                }
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            Section("Status") {
                LabeledContent("Verbindung", value: lage.isOnline(member.id) ? "Verbunden" : "Nicht verbunden")
                if let position {
                    LabeledContent("Position", value: Format.ago(position.date))
                    if let speed = position.spd, speed > 1 {
                        LabeledContent("Geschwindigkeit", value: "\(Int(speed * 3.6)) km/h")
                    }
                } else {
                    LabeledContent("Position", value: "unbekannt")
                }
                if lage.operation.a?.memberId == member.id {
                    Label("Hält die A-Position", systemImage: "a.circle.fill")
                        .foregroundStyle(Theme.aPosition)
                }
                if !member.data.telefon.isEmpty {
                    LabeledContent("Handynummer", value: member.data.telefon)
                }
            }

            if let vehicle {
                Section("Fahrzeug") {
                    NavigationLink {
                        VehicleDetail(vehicleId: vehicle.id)
                    } label: {
                        VehicleRow(vehicle: vehicle)
                    }
                }
            }
        }
        .navigationTitle(member.data.funkrufname)
    }
}

private struct LastKnownQuickLook: View {
    let placeLastKnown: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let lkp = lage.operation.lkp {
                Section {
                    LabeledContent("Zeitpunkt", value: lkp.date.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Verstrichen", value: Format.ago(lkp.date))
                    LabeledContent("Quelle", value: lkp.quelle == "a" ? "A-Position beim Moduswechsel" : lkp.quelle == "tracker" ? "Tracker" : "Manuell gesetzt")
                    if let target = lkp.targetId.flatMap({ lage.targets[$0] }) {
                        LabeledContent("Zielperson", value: target.data.displayName)
                    }
                }
                Section {
                    Button("Hinführen", systemImage: "location.north.line.fill") {
                        model.navigate(to: .point(lkp.point, title: "Letzter Standort"))
                        dismiss()
                    }
                    if lage.operation.modus == .fahndung {
                        Button("Auf Karte neu setzen", systemImage: "hand.tap") {
                            placeLastKnown()
                            dismiss()
                        }
                    }
                    Button("Entfernen", systemImage: "trash", role: .destructive) {
                        lage.clearLastKnownPosition()
                        dismiss()
                    }
                }
            } else {
                ContentUnavailableView("Kein letzter Standort", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle("Letzter bekannter Standort")
    }
}
