import SwiftUI

/// Kurzübersicht zu einem angetippten Kartenobjekt.
struct QuickLookSheet: View {
    let selection: MapSelection
    /// Standort eines Ziels auf der Karte neu setzen.
    let placeTarget: (String) -> Void

    @Environment(LageStore.self) private var lage

    var body: some View {
        NavigationStack {
            Group {
                switch selection {
                case .member(let id):
                    if let member = lage.members[id] { MemberQuickLook(member: member) } else { gone }
                case .vehicle(let id):
                    if lage.vehicles[id] != nil { VehicleDetail(vehicleId: id) } else { gone }
                case .target(let id):
                    if lage.targets[id] != nil { TargetDetail(targetId: id, placeOnMap: placeTarget) } else { gone }
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

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Avatar(blobId: member.data.fotoBlob, fallbackText: member.data.spitzname, size: 72, tint: lage.isOnline(member.id) && member.data.aktiv ? .green : .gray)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.data.spitzname)
                            .font(.title2.weight(.bold))
                        Text(member.data.name)
                        Text(member.data.dienststelle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)

                HStack(spacing: 12) {
                    if let url = PhoneNumber.callURL(member.data.telefon), member.id != lage.selfId {
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
                LabeledContent("Dienst", value: member.data.aktiv ? (lage.isOnline(member.id) ? "Verbunden" : "Nicht verbunden") : "Ruhemodus")
                LabeledContent("Unterwegs", value: lage.mobilityDescription(of: member.data))
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

            if let vehicle = lage.vehicle(of: member.data) {
                Section("Fahrzeug") {
                    NavigationLink {
                        VehicleDetail(vehicleId: vehicle.id)
                    } label: {
                        VehicleRow(vehicle: vehicle)
                    }
                }
            }
        }
        .navigationTitle(member.data.spitzname)
    }
}
