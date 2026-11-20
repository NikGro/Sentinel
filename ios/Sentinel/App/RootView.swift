import SwiftUI

/// Oberste Ansicht: Einrichtung, Verbindungsaufbau, Profil oder die eigentliche App.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            content
            // Sichtschutz: Im App-Umschalter und bei gesperrter App sind keine Einsatzdaten zu sehen.
            if lock.isLocked || scenePhase != .active {
                PrivacyShield(isLocked: lock.isLocked) { Task { await lock.unlock() } }
                    .transition(.opacity)
            }
        }
        .animation(.default, value: lock.isLocked)
    }

    /// In einer Instanz (im Dienst) oder in einem Sonderbereich; außer Dienst bleibt nur das Hauptmenü.
    private var insideInstance: Bool {
        (model.lage.me?.data.aktiv ?? true) || model.editsPermanentLayer || model.lage.isPackageArea
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .onboarding:
            OnboardingView()
        case .connecting:
            ConnectingView()
        case .profile:
            NavigationStack {
                ProfileEditor(mode: .create)
            }
        case .main:
            // Passen App und Server nicht zusammen, ist die App gesperrt, bis eine passende Version läuft.
            if let mismatch = model.lage.versionMismatch {
                VersionLockView(message: mismatch)
            } else if model.showsHome || !insideInstance {
                // Übergeordnetes Hauptmenü: Karte, Ziele, Kräfte und Chat gibt es nur innerhalb einer Instanz.
                NavigationStack { InstancesScreen(isHome: true) }
            } else {
                MainView()
            }
        }
    }
}

struct VersionLockView: View {
    let message: String
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Version passt nicht", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        } description: {
            Text(message + "\n\nBis dahin ist die App gesperrt, damit keine Fehler durch unterschiedliche Stände entstehen.")
        } actions: {
            Button("Abmelden", role: .destructive) { model.signOut() }
                .buttonStyle(.bordered)
        }
    }
}

private struct PrivacyShield: View {
    let isLocked: Bool
    let unlock: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("SENTINEL")
                    .font(.title.weight(.bold))
                    .tracking(4)
                if isLocked {
                    Button("Entsperren", systemImage: "faceid", action: unlock)
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                }
            }
        }
    }
}

private struct ConnectingView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSignOut = false

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text("Verbinde mit dem Server …")
                .font(.headline)
            if let host = model.credentials?.serverURL.host() {
                Text(host)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Abmelden", role: .destructive) { showsSignOut = true }
                .padding(.top, 24)
        }
        .padding()
        .alert("Dieses Gerät vom Server abmelden?", isPresented: $showsSignOut) {
            Button("Abbrechen", role: .cancel) {}
            Button("Abmelden", role: .destructive) { model.signOut() }
        } message: {
            Text("Für eine erneute Anmeldung wird der Zugangscode benötigt.")
        }
    }
}

/// Hauptnavigation. Die Lageleiste mit dem Funkkanal gehört zur Karte.
struct MainView: View {
    enum Section: Hashable {
        case lage, ziele, kraefte, chat, mehr
    }

    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(AlertCenter.self) private var alerts
    @Environment(AppModel.self) private var model
    @State private var selection: Section = .lage

    private var inSpecialArea: Bool { model.editsPermanentLayer || lage.isPackageArea }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Lage", systemImage: "map", value: Section.lage) {
                MapScreen()
            }
            Tab("Ziele", systemImage: "person.crop.rectangle.stack", value: Section.ziele) {
                TargetListScreen()
            }
            // In den Sonderbereichen gibt es keinen Einsatzbetrieb: keine Kräfte und kein Chat.
            if !inSpecialArea {
                Tab("Kräfte", systemImage: "person.3", value: Section.kraefte) {
                    ForcesScreen()
                }
                Tab("Chat", systemImage: "bubble.left.and.bubble.right", value: Section.chat) {
                    ChatScreen()
                }
                .badge(unreadCount)
            }
            Tab("Mehr", systemImage: "ellipsis", value: Section.mehr) {
                SettingsScreen()
            }
        }
        .onChange(of: model.mapRequest) { selection = .lage }
        .onChange(of: inSpecialArea) { if inSpecialArea, selection == .kraefte || selection == .chat { selection = .lage } }
        .overlay(alignment: .top) {
            if let alert = alerts.current {
                AlertBanner(alert: alert, dismiss: { alerts.dismiss() }, open: { model.openInstance($0) })
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(alert.id)
            }
        }
        .alert("Hinweis", isPresented: Binding(get: { lage.lastError != nil }, set: { if !$0 { lage.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lage.lastError ?? "")
        }
    }

    private var unreadCount: Int {
        guard selection != .chat else { return 0 }
        return lage.messages.filter { $0.updatedAt > settings.lastReadMessageAt && $0.updatedBy != lage.selfId }.count
    }
}
