import SwiftUI

/// Mehr: Profil, Dienst, Geräteeinstellungen und die komplette Verwaltung des Einsatzes.
/// Alles, was die Kommandozentrale kann, ist auch hier erreichbar.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(LocationService.self) private var location
    @Environment(\.openURL) private var openURL

    private var currentArea: String {
        if model.editsPermanentLayer { return "Dauerhafte Orte bearbeiten" }
        let name = lage.currentInstance?.data.name ?? "KSOD"
        return lage.isPackageArea ? "Paket: \(name)" : "Geöffnet: \(name)"
    }

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
                            Label("Im Dienst", systemImage: "person.badge.shield.checkmark.fill")
                        }

                        if location.isDenied {
                            Button("Standortzugriff in den Einstellungen erlauben", systemImage: "exclamationmark.triangle.fill") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            .foregroundStyle(.orange)
                        }
                    } footer: {
                        Text(me.data.aktiv
                            ? "Ihr Standort wird mit den eigenen Kräften geteilt, auch im Hintergrund, und nur an den eigenen Sentinel-Server übertragen."
                            : "Ruhemodus: Es wird kein Standort geteilt und die A-Position ist nicht verfügbar.")
                    }
                }

                Section {
                    NavigationLink { InstancesScreen() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Instanzen")
                                Text(currentArea)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Einsätze wechseln und verwalten, dauerhafte Orte bearbeiten und Pakete vorbereiten.")
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
                    NavigationLink { HistoryOverviewScreen() } label: {
                        Label("Verläufe", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
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
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                TabHeader(title: "Mehr")
                    .background(Color(.systemGroupedBackground))
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
