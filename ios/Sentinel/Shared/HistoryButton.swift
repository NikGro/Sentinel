import SwiftUI

/// „Verlauf auf der Karte“: zeigt die aufgezeichnete Spur im Verlaufsmodus der Karte.
struct HistoryButton: View {
    let subject: SpurSubject
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            model.showHistory(subject)
            dismiss()
        } label: {
            Label("Verlauf auf der Karte", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
        }
    }
}
