import SwiftUI

/// Auswahl als Glaspillen wie im Verlauf: Gewähltes steht als Kapsel mit „x“ zum Entfernen da, über „+“ kommt
/// Weiteres hinzu. `minimum` legt fest, wie viele mindestens gewählt bleiben.
struct PillPicker<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Set<Item>
    let title: (Item) -> String
    let symbol: (Item) -> String
    var minimum = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items.filter(selection.contains)) { item in
                    HStack(spacing: 5) {
                        Image(systemName: symbol(item))
                        Text(title(item))
                            .lineLimit(1)
                        if selection.count > minimum {
                            Button {
                                selection.remove(item)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(title(item)) entfernen")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                }
                let missing = items.filter { !selection.contains($0) }
                if !missing.isEmpty {
                    Menu {
                        ForEach(missing) { item in
                            Button(title(item), systemImage: symbol(item)) { selection.insert(item) }
                        }
                    } label: {
                        Group {
                            if selection.isEmpty { Label("Hinzufügen", systemImage: "plus") } else { Image(systemName: "plus") }
                        }
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 10)
                            .frame(minWidth: 32, minHeight: 30)
                            .contentShape(.capsule)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .accessibilityLabel("Hinzufügen")
                }
            }
            .padding(.vertical, 2)
        }
    }
}
