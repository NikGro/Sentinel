import SwiftUI

/// Mehr innerhalb einer Instanz: Hauptmenü, Funkkanal und Einsatzinformationen, Ebenen und Pakete.
/// Profil, Geräte, Tracker, Argus, App-Sperre, Verbindung und Entwickler stehen im Hauptmenü unter „Mehr“.
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
        NavigationStack {
            List {
                if let me = lage.me {
                    Section {
                        // Ein Eintrag für Dienst und Instanzen: Im Dienst ist, wer in einer Instanz ist.
                        // Instanzen wechseln, verlassen und Pakete gibt es im übergeordneten Hauptmenü.
                        Button { model.showsHome = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: me.data.aktiv ? "square.stack.3d.up.fill" : "moon.zzz.fill")
                                    .foregroundStyle(me.data.aktiv ? Color.accentColor : Color.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hauptmenü")
                                    Text(me.data.aktiv ? "Im Dienst · \(currentArea)" : "Außer Dienst · Instanz betreten")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.primary)

                        if location.isDenied {
                            Button("Standortzugriff in den Einstellungen erlauben", systemImage: "exclamationmark.triangle.fill") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            .foregroundStyle(.orange)
                        }
                    } footer: {
                        Text(me.data.aktiv
                            ? "Ihr Standort wird mit den eigenen Kräften geteilt, auch im Hintergrund, und nur an den eigenen Sentinel-Server übertragen."
                            : "Außer Dienst: Es wird kein Standort geteilt und die A-Position ist nicht verfügbar. Mit dem Betreten einer Instanz ist man wieder im Dienst.")
                    }
                }

                Section("Einsatz") {
                    NavigationLink { SituationAdminScreen() } label: {
                        Label("Funkkanal und Einsatzinformationen", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    NavigationLink { LayersAdminScreen() } label: {
                        Label("Ebenen und Pakete", systemImage: "square.3.layers.3d")
                    }
                }

                Section("Über") {
                    LabeledContent("Version", value: Bundle.main.versionDescription)
                }
            }
            // Erster Eintrag unterhalb des Verlaufs der Kopfzeile.
            .contentMargins(.top, 20, for: .scrollContent)
            .navigationTitle("Mehr")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                TabHeader(title: "Mehr")
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
