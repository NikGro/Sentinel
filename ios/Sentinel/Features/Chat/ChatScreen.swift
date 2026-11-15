import SwiftUI

/// Schlanker Einsatz-Chat für alle Kräfte und die Kommandozentrale.
struct ChatScreen: View {
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @State private var draft = ""
    @FocusState private var isComposing: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(lage.messages) { message in
                            MessageBubble(message: message, isMine: message.updatedBy == lage.selfId, sender: lage.name(of: message.updatedBy))
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: lage.messages.count) { _, _ in
                    markRead()
                    if let last = lage.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            .overlay {
                if lage.messages.isEmpty {
                    ContentUnavailableView("Noch keine Nachrichten", systemImage: "bubble.left.and.bubble.right", description: Text("Nachrichten sehen alle im Einsatz. Sie verschwinden, wenn die Lage zurückgesetzt wird."))
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Nachricht", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($isComposing)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    Button("Senden", systemImage: "arrow.up") {
                        lage.sendMessage(draft)
                        draft = ""
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: markRead)
        }
    }

    private func markRead() {
        if let last = lage.messages.last, last.updatedAt > settings.lastReadMessageAt {
            settings.lastReadMessageAt = last.updatedAt
        }
    }
}

private struct MessageBubble: View {
    let message: Versioned<ChatMessage>
    let isMine: Bool
    let sender: String

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 2) {
                if !isMine {
                    Text(sender)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)
                }
                Text(message.data.text)
                    .textSelection(.enabled)
                Text(Format.time(message.updatedDate))
                    .font(.caption2)
                    .foregroundStyle(isMine ? AnyShapeStyle(Color.white.opacity(0.75)) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isMine ? Color.white : Color.primary)
            .background(isMine ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary), in: .rect(cornerRadius: 16))
            .frame(maxWidth: 320, alignment: isMine ? .trailing : .leading)
            if !isMine { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
    }
}
