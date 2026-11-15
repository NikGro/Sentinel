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
            MainView()
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
        .confirmationDialog("Dieses Gerät vom Server abmelden?", isPresented: $showsSignOut, titleVisibility: .visible) {
            Button("Abmelden", role: .destructive) { model.signOut() }
        } message: {
            Text("Für eine erneute Anmeldung wird der Zugangscode benötigt.")
        }
    }
}

/// Hauptnavigation. Die Lageleiste über der Tableiste ist in jeder Ansicht sichtbar.
struct MainView: View {
    enum Section: Hashable {
        case lage, ziele, kraefte, chat, mehr
    }

    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @State private var selection: Section = .lage
    @State private var showsSituation = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("Lage", systemImage: "map", value: Section.lage) {
                MapScreen()
            }
            Tab("Ziele", systemImage: "person.crop.rectangle.stack", value: Section.ziele) {
                TargetListScreen()
            }
            Tab("Kräfte", systemImage: "person.3", value: Section.kraefte) {
                ForcesScreen()
            }
            Tab("Chat", systemImage: "bubble.left.and.bubble.right", value: Section.chat) {
                ChatScreen()
            }
            .badge(unreadCount)
            Tab("Mehr", systemImage: "ellipsis", value: Section.mehr) {
                SettingsScreen()
            }
        }
        .tabViewBottomAccessory {
            SituationBar { showsSituation = true }
        }
        .sheet(isPresented: $showsSituation) {
            SituationSheet()
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
