import SwiftUI

/// Profil, Geräteeinstellungen und Angaben zur Verbindung.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(LocationService.self) private var location
    @Environment(\.openURL) private var openURL

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
                                Avatar(blobId: me.data.fotoBlob, fallbackText: me.data.funkrufname, size: 56)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(me.data.funkrufname)
                                        .font(.title3.weight(.bold))
                                    Text("\(me.data.name) · \(me.data.dienststelle)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
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
                } header: {
                    Text("Standort")
                } footer: {
                    Text("Die Position wird nur an den eigenen Sentinel-Server übertragen, auch wenn die App im Hintergrund läuft.")
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
                    LabeledContent("Weg-Zeit-Berechnung", value: lage.routingAvailable ? "Wegenetz" : "Näherungsmodell")
                }

                Section("Über") {
                    LabeledContent("Version", value: Bundle.main.versionDescription)
                }
            }
            .navigationTitle("Mehr")
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
