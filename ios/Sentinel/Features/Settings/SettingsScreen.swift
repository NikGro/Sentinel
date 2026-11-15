import SwiftUI

/// Mehr: Profil, Dienst und Fortbewegung, Geräteeinstellungen und die komplette Verwaltung des Einsatzes.
/// Alles, was die Kommandozentrale kann, ist auch hier erreichbar.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(LocationService.self) private var location
    @Environment(\.openURL) private var openURL
    @State private var showsMobility = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            List {
                if let me = lage.me {
                    Section {
                        NavigationLink {
                            ProfileEditor(mode: .edit)
                        } label: {
                            HStack(spacing: 14) {
                                Avatar(blobId: me.data.fotoBlob, fallbackText: me.data.spitzname, size: 56)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(me.data.spitzname)
                                        .font(.title3.weight(.bold))
                                    Text("\(me.data.name), \(me.data.dienststelle)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section {
                        Toggle(isOn: Binding(get: { me.data.aktiv }, set: { lage.setActive($0) })) {
                            Label(me.data.aktiv ? "Im Dienst" : "Ruhemodus", systemImage: me.data.aktiv ? "person.fill.checkmark" : "moon.zzz.fill")
                        }
                        Button {
                            showsMobility = true
                        } label: {
                            LabeledContent {
                                Text(lage.mobilityDescription(of: me.data))
                            } label: {
                                Label("Fortbewegung", systemImage: me.data.fortbewegung.symbolName)
                            }
                        }
                        .tint(.primary)
                        .disabled(!me.data.aktiv)
                    } header: {
                        Text("Dienst")
                    } footer: {
                        Text("Im Ruhemodus wird kein Standort geteilt und die A-Position ist nicht verfügbar.")
                    }
                }

                Section {
                    Toggle("Eigene Position teilen", systemImage: "location.fill", isOn: $settings.sharesLocation)
                    if location.isDenied {
                        Button("Standortzugriff in den Einstellungen erlauben", systemImage: "exclamationmark.triangle.fill") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .foregroundStyle(.orange)
                    }
                    Toggle("Bestreifte Wege anzeigen", systemImage: "road.lanes", isOn: $settings.showsCoverage)
                } header: {
                    Text("Standort und Karte")
                } footer: {
                    Text("Die Position geht nur an den eigenen Sentinel-Server, auch im Hintergrund. Bestreifung wird immer aufgezeichnet; die Anzeige schaltet jeder für sich.")
                }

                Section {
                    Toggle(isOn: $settings.permanentLayerUnlocked) {
                        Label(settings.permanentLayerUnlocked ? "Dauerhafte Orte entsperrt" : "Dauerhafte Orte gesperrt", systemImage: settings.permanentLayerUnlocked ? "lock.open.fill" : "lock.fill")
                    }
                    .tint(.orange)
                } footer: {
                    Text("Schützt die Ebene mit dauerhaft wichtigen Orten vor versehentlichem Bearbeiten. Die Sperre gilt wieder nach dem nächsten Start der App.")
                }

                Section("Einsatz") {
                    NavigationLink { SituationAdminScreen() } label: {
                        Label("Funkkanal und Einsatzinformationen", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    NavigationLink { LayersAdminScreen() } label: {
                        Label("Ebenen, Pakete und Argus", systemImage: "square.3.layers.3d")
                    }
                    NavigationLink { TrackersAdminScreen() } label: {
                        Label("GPS-Tracker", systemImage: "dot.radiowaves.left.and.right")
                    }
                    NavigationLink { DevicesAdminScreen() } label: {
                        Label("Geräte und Zugangscode", systemImage: "iphone.gen3")
                    }
                }

                Section {
                    Toggle("App-Sperre", systemImage: "faceid", isOn: $settings.appLockEnabled)
                } header: {
                    Text("Sicherheit")
                } footer: {
                    Text("Beim Verlassen wird die App gesperrt und erst nach Face ID, Touch ID oder Gerätecode wieder freigegeben. Im App-Umschalter sind nie Einsatzdaten zu sehen.")
                }

                Section("Verbindung") {
                    LabeledContent("Server", value: model.credentials?.serverURL.host() ?? "–")
                    LabeledContent("Zustand", value: lage.connection.title)
                    LabeledContent("Weg-Zeit und Sonderrechte", value: lage.routingAvailable ? "Wegenetz" : "Näherungsmodell")
                }

                Section("Über") {
                    LabeledContent("Version", value: Bundle.main.versionDescription)
                }
            }
            .navigationTitle("Mehr")
            .sheet(isPresented: $showsMobility) {
                MobilitySheet()
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

extension Bundle {
    var versionDescription: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
