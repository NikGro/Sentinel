import Foundation

/// Eine eigene Bearbeitung an einer Markierung: Zustand davor und danach. `nil` bedeutet "existiert nicht".
struct MapEdit: Equatable, Sendable {
    let id: String
    let before: MapObject?
    let after: MapObject?
}

/// Verlauf der eigenen Bearbeitungen für Rückgängig und Wiederholen.
/// Enthält bewusst nur die Schritte dieses Geräts: Jeder macht ausschließlich eigene Änderungen rückgängig.
struct UndoStack: Equatable, Sendable {
    private(set) var done: [MapEdit] = []
    private(set) var undone: [MapEdit] = []
    private let limit: Int

    init(limit: Int = 50) {
        self.limit = limit
    }

    var canUndo: Bool { !done.isEmpty }
    var canRedo: Bool { !undone.isEmpty }

    /// Merkt eine neue Bearbeitung. Der Wiederholen-Verlauf verfällt dadurch.
    mutating func record(_ edit: MapEdit) {
        guard edit.before != edit.after else { return }
        done.append(edit)
        if done.count > limit { done.removeFirst(done.count - limit) }
        undone.removeAll()
    }

    /// Liefert den Zustand, der wiederherzustellen ist (`nil` = Objekt löschen), samt Objekt-ID.
    mutating func undo() -> (id: String, restore: MapObject?)? {
        guard let edit = done.popLast() else { return nil }
        undone.append(edit)
        return (edit.id, edit.before)
    }

    mutating func redo() -> (id: String, restore: MapObject?)? {
        guard let edit = undone.popLast() else { return nil }
        done.append(edit)
        return (edit.id, edit.after)
    }

    mutating func clear() {
        done.removeAll()
        undone.removeAll()
    }
}
