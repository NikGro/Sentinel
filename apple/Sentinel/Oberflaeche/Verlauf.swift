import SentinelKern
import SwiftUI

/// Mitternacht heute in Millisekunden (für den Zeitraum „Heute“).
func mitternachtMs() -> Int64 { Int64(Calendar.current.startOfDay(for: .now).timeIntervalSince1970 * 1000) }

/// Leiste unten im Verlauf: Titel mit Schließen (in der Leiste, nicht oben), Zeitraum, Zusammenfassung, Zeitregler
/// und „Auf der Karte behalten“. Gleich aufgebaut wie auf Android.
struct VerlaufLeiste: View {
    let v: Verlauf
    let stand: Int
    @Binding var anteil: Double
    let zeitraumWaehlen: (Zeitraum) -> Void
    let behalten: () -> Void
    let schliessen: () -> Void

    var body: some View {
        let _ = stand
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verlauf \(v.titel)").font(.headline).lineLimit(1)
                    Text(v.zusammenfassung()).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: schliessen) {
                    Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Verlauf schließen")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Verlauf.companion.zeitraeume(jetztMs: Int64(Date.now.timeIntervalSince1970 * 1000), mitternachtMs: mitternachtMs()), id: \.titel) { z in
                        Button(z.titel) { zeitraumWaehlen(z) }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(v.zeitraum?.titel == z.titel ? .accentColor : .secondary)
                    }
                }
            }
            if let t = v.zeitBei(anteil: anteil) {
                HStack(spacing: 10) {
                    Text(Date(timeIntervalSince1970: Double(t.int64Value) / 1000).formatted(date: .omitted, time: .shortened))
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                    Slider(value: $anteil, in: 0...1)
                }
            }
            if !(v.spur?.punkte.isEmpty ?? true) {
                Button("Auf der Karte behalten", action: behalten).buttonStyle(.glass)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .accessibilityIdentifier("Verlaufleiste")
    }
}
