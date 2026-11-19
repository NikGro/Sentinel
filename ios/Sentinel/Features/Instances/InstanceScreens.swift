import SwiftUI

/// Instanzenmenü: eigene Einsätze öffnen, anlegen, beitreten, verlassen und löschen. Darunter, deutlich abgesetzt,
/// die beiden Sonderbereiche „Dauerhafte Orte bearbeiten“ und „Paket vorbereiten“.
struct InstancesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @State private var creating = false
    @State private var editing: Versioned<Instance>?
    @State private var deleting: Versioned<Instance>?

    var body: some View {
        List {
            Section {
                ForEach(lage.myInstances) { instance in
                    InstanceRow(instance: instance, isOpen: instance.id == lage.instanz && !model.editsPermanentLayer) {
                        model.openInstance(instance.id)
                    }
                    .swipeActions(edge: .trailing) {
                        if instance.id != Instance.mainId {
                            Button("Löschen", systemImage: "trash", role: .destructive) { deleting = instance }
                            Button("Verlassen", systemImage: "rectangle.portrait.and.arrow.right") { lage.leaveInstance(instance.id) }
                                .tint(.orange)
                        }
                    }
                    .contextMenu {
                        if instance.id != Instance.mainId {
                            Button("Umbenennen", systemImage: "pencil") { editing = instance }
                            Button("Verlassen", systemImage: "rectangle.portrait.and.arrow.right") { lage.leaveInstance(instance.id) }
                            Button("Löschen", systemImage: "trash", role: .destructive) { deleting = instance }
                        }
                    }
                }
                Button("Neue Instanz", systemImage: "plus.circle.fill") { creating = true }
            } header: {
                Text("Meine Instanzen")
            } footer: {
                Text("Jede Instanz hat ihre eigene Lage, eigene Ziele, Chats, A-Position und Notrufe. Geöffnet ist immer genau eine. Aus den anderen kommen A-Position und Notruf als Hinweis.")
            }

            if !lage.otherInstances.isEmpty {
                Section("Weitere Instanzen") {
                    ForEach(lage.otherInstances) { instance in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(instance.data.name)
                                Text("\(instance.data.mitglieder.count) Mitglieder")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Beitreten") { lage.joinInstance(instance.id) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section {
                Button {
                    model.editPermanentLayer(true)
                } label: {
                    SpecialAreaRow(
                        title: "Dauerhafte Orte bearbeiten",
                        subtitle: "Gilt in allen Instanzen. Nur Werkzeuge für Markierungen.",
                        symbol: "pin.fill",
                        isOpen: model.editsPermanentLayer
                    )
                }
                .tint(.primary)
                NavigationLink {
                    PackagesScreen()
                } label: {
                    SpecialAreaRow(
                        title: "Paket vorbereiten",
                        subtitle: "Pakete anlegen und bearbeiten, dann in einen Einsatz übernehmen.",
                        symbol: "shippingbox.fill",
                        isOpen: lage.isPackageArea
                    )
                }
            } header: {
                Label("Sonderbereiche", systemImage: "wrench.and.screwdriver")
            }
            .listRowBackground(Color.indigo.opacity(0.12))
        }
        .navigationTitle("Instanzen")
        .sheet(isPresented: $creating) {
            InstanceForm(title: "Neue Instanz") { name, description in
                // Der Server öffnet die neue Instanz gleich.
                if model.route.isActive { model.stopNavigation() }
                lage.createInstance(name: name, description: description, package: false)
                model.showMap()
            }
        }
        .sheet(item: $editing) { instance in
            InstanceForm(title: "Instanz bearbeiten", name: instance.data.name, description: instance.data.beschreibung) { name, description in
                lage.editInstance(instance.id, name: name, description: description)
            }
        }
        .alert("„\(deleting?.data.name ?? "")“ löschen?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                if let id = deleting?.id { lage.deleteInstance(id) }
            }
        } message: {
            Text("Lage, Ziele, Chats und Bestreifung dieser Instanz werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen.")
        }
    }
}

private struct InstanceRow: View {
    let instance: Versioned<Instance>
    let isOpen: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(systemName: instance.id == Instance.mainId ? "map.fill" : "scope")
                    .foregroundStyle(.tint)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(instance.data.name)
                        .font(.body.weight(isOpen ? .semibold : .regular))
                    if !instance.data.beschreibung.isEmpty {
                        Text(instance.data.beschreibung)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if isOpen {
                    Text("Geöffnet")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
        .tint(.primary)
    }
}

private struct SpecialAreaRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isOpen: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isOpen {
                Text("Geöffnet")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
            }
        }
    }
}

/// Bibliothek der Objekt-Pakete. Ein Paket wird wie eine eigene Instanz bearbeitet und kann in den geöffneten
/// Einsatz übernommen werden; die Objekte sind danach eigenständig und nicht mehr an das Paket gebunden.
struct PackagesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @State private var creating = false
    @State private var importing: Versioned<Instance>?
    @State private var deleting: Versioned<Instance>?
    @State private var editing: Versioned<Instance>?

    /// Einsatz, in den übernommen wird: der geöffnete, oder beim Bearbeiten eines Pakets der vorherige.
    private var targetInstance: Versioned<Instance>? {
        lage.isPackageArea ? lage.instances[model.returnInstance ?? Instance.mainId] : lage.currentInstance
    }

    var body: some View {
        List {
            Section {
                if lage.packages.isEmpty {
                    Text("Noch keine Pakete.")
                        .foregroundStyle(.secondary)
                }
                ForEach(lage.packages) { package in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shippingbox.fill")
                                .foregroundStyle(.indigo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(package.data.name).font(.headline)
                                if !package.data.beschreibung.isEmpty {
                                    Text(package.data.beschreibung)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if package.id == lage.instanz {
                                Text("In Bearbeitung")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.indigo)
                            }
                        }
                        HStack {
                            Button("Bearbeiten", systemImage: "pencil.and.outline") { model.openInstance(package.id) }
                            Spacer()
                            if let target = targetInstance {
                                Button("In „\(target.data.name)“ übernehmen", systemImage: "square.and.arrow.down") { importing = package }
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.subheadline)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Löschen", systemImage: "trash", role: .destructive) { deleting = package }
                        Button("Umbenennen", systemImage: "pencil") { editing = package }
                    }
                }
                Button("Neues Paket", systemImage: "plus.circle.fill") { creating = true }
            } footer: {
                Text("Pakete liegen in einer Bibliothek auf dem Server und stehen in allen Instanzen zur Verfügung. Beim Bearbeiten sind nur die Werkzeuge zum Anlegen sichtbar.")
            }
        }
        .navigationTitle("Pakete")
        .sheet(isPresented: $creating) {
            InstanceForm(title: "Neues Paket") { name, description in
                model.prepareNewPackage()
                lage.createInstance(name: name, description: description, package: true)
                model.showMap()
            }
        }
        .sheet(item: $editing) { package in
            InstanceForm(title: "Paket bearbeiten", name: package.data.name, description: package.data.beschreibung) { name, description in
                lage.editInstance(package.id, name: name, description: description)
            }
        }
        .alert("„\(importing?.data.name ?? "")“ übernehmen?", isPresented: Binding(get: { importing != nil }, set: { if !$0 { importing = nil } })) {
            Button("Abbrechen", role: .cancel) {}
            Button("Übernehmen") {
                guard let package = importing, let target = targetInstance else { return }
                // Aus einem geöffneten Paket heraus zuerst zurück in den Einsatz, dann übernehmen. Der Server
                // verarbeitet beides in dieser Reihenfolge, weil beides über dieselbe Verbindung geht.
                if lage.isPackageArea { model.openInstance(target.id) }
                lage.importPackage(package.id)
            }
        } message: {
            Text("Alle Objekte des Pakets werden in „\(targetInstance?.data.name ?? "")“ kopiert und sind danach eigenständige Objekte dieser Instanz. Das lässt sich nicht rückgängig machen.")
        }
        .alert("Paket „\(deleting?.data.name ?? "")“ löschen?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                if let id = deleting?.id { lage.deleteInstance(id) }
            }
        } message: {
            Text("Bereits übernommene Objekte bleiben in ihren Instanzen erhalten.")
        }
    }
}

/// Name und Beschreibung einer Instanz oder eines Pakets.
private struct InstanceForm: View {
    let title: String
    @State var name = ""
    @State var description = ""
    let save: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    init(title: String, name: String = "", description: String = "", save: @escaping (String, String) -> Void) {
        self.title = title
        _name = State(initialValue: name)
        _description = State(initialValue: description)
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Beschreibung (optional)", text: $description, axis: .vertical)
                    .lineLimit(2...5)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        save(String(name.trimmingCharacters(in: .whitespaces).prefix(60)), String(description.prefix(500)))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Leiste unten auf der Karte im Sonderbereich: zeigt, wo man ist, und führt zurück in den Einsatz.
struct SpecialAreaBar: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.editsPermanentLayer ? "pin.fill" : "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.editsPermanentLayer ? "Dauerhafte Orte bearbeiten" : "Paket: \(lage.currentInstance?.data.name ?? "")")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(model.editsPermanentLayer ? "Gilt in allen Instanzen" : "Vorbereitung, kein Einsatzbetrieb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("Fertig") { model.leaveSpecialArea() }
                .buttonStyle(.glassProminent)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(.indigo.opacity(0.2)), in: .rect(cornerRadius: 20))
    }
}
