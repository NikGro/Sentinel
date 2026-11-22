import SwiftUI

/// Übergeordnetes Hauptmenü, außerhalb jeder Instanz: Instanzen und Sonderbereiche, dazu alles, was nicht zu einem
/// Einsatz gehört (Profil, Geräte, Tracker, Argus Predict, App-Sperre, Verbindung, Entwickler).
struct HomeView: View {
    var body: some View {
        TabView {
            Tab("Instanzen", systemImage: "square.stack.3d.up") {
                NavigationStack { InstancesScreen(isHome: true) }
            }
            Tab("Mehr", systemImage: "ellipsis") {
                NavigationStack { HomeMoreScreen() }
            }
        }
    }
}

/// „Mehr“ im Hauptmenü.
struct HomeMoreScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @State private var showsSignOut = false
    @AppStorage(CameraProbe.settingsKey) private var sendsCameraDiagnosis = false

    var body: some View {
        @Bindable var settings = settings
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
                } footer: {
                    Text("Profil bearbeiten: Spitzname, Name, Dienststelle und Foto.")
                }
            }

            Section("Verwaltung") {
                NavigationLink { DevicesAdminScreen() } label: {
                    Label("Geräte und Zugangscode", systemImage: "iphone.gen3")
                }
                NavigationLink { TrackersAdminScreen() } label: {
                    Label("GPS-Tracker", systemImage: "dot.radiowaves.left.and.right")
                }
                NavigationLink { ArgusImportScreen() } label: {
                    Label("Argus Predict", systemImage: "chart.bar.xaxis")
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

            Section {
                Toggle("Kamerawerte einblenden", systemImage: "camera.metering.center.weighted", isOn: $settings.showsCameraDebug)
                Toggle("Kamera-Messdaten senden", systemImage: "waveform.path.ecg", isOn: $sendsCameraDiagnosis)
            } header: {
                Text("Entwickler")
            } footer: {
                Text("Kamerawerte: Abstand, Neigung, Richtung, Anheft-Modus und Gestenerkennung auf der Karte. Messdaten: Kamerawerte und Gesten alle zehn Sekunden an den eigenen Server, zur Fehlersuche; danach wieder ausschalten.")
            }

            Section {
                LabeledContent("Version", value: Bundle.main.versionDescription)
                Button("Gerät abmelden", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { showsSignOut = true }
            } header: {
                Text("Über")
            }
        }
        .contentMargins(.top, 20, for: .scrollContent)
        .navigationTitle("Mehr")
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) { TabHeader(title: "Mehr") }
        .alert("Dieses Gerät vom Server abmelden?", isPresented: $showsSignOut) {
            Button("Abbrechen", role: .cancel) {}
            Button("Abmelden", role: .destructive) { model.signOut() }
        } message: {
            Text("Für eine erneute Anmeldung wird der Zugangscode benötigt.")
        }
    }
}
