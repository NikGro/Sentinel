import SentinelKern
import SwiftUI

/// Navi-Leiste oben: nächstes Manöver groß, darunter Fahrspuren und das übernächste Manöver (gleich wie auf Android).
struct NaviLeisteOben: View {
    let n: Navistand

    var body: some View {
        let farbe: Color = n.info.sonderrechte ? .red : Color(hex: "#1C6E3D")
        VStack(alignment: .leading, spacing: 8) {
            if let f = n.fortschritt {
                HStack(spacing: 14) {
                    Image(systemName: f.manoever.sf).font(.system(size: 34, weight: .bold)).frame(width: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        if !f.angekommen { Text(Format.shared.entfernung(meter: f.bisManoever)).font(.system(size: 28, weight: .bold)).monospacedDigit() }
                        Text(f.anweisung).font(.headline).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                if f.spuren.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(f.spuren.indices, id: \.self) { i in
                            let s = f.spuren[i]
                            Image(systemName: (s.symbole.first ?? .geradeaus).sf)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(s.aktiv ? farbe : .white)
                                .frame(width: 30, height: 30)
                                .background(s.aktiv ? Color.white : Color.white.opacity(0.18), in: .rect(cornerRadius: 6))
                        }
                    }
                }
                if let d = f.danach {
                    HStack(spacing: 8) {
                        Text("Dann").foregroundStyle(.white.opacity(0.8))
                        if let m = f.danachManoever { Image(systemName: m.sf).font(.subheadline.weight(.semibold)) }
                        Text(d).lineLimit(1).foregroundStyle(.white.opacity(0.9))
                    }
                    .font(.subheadline)
                }
            } else if let fehler = n.fehler {
                Text(fehler).font(.headline)
            } else {
                Text("Route wird berechnet …").font(.headline)
                ProgressView().tint(.white)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(farbe), in: .rect(cornerRadius: 24))
        .padding(.horizontal, 12)
        .accessibilityIdentifier("Navileiste")
    }
}

/// Navi-Leiste unten: Ankunft, Restzeit, Entfernung, Sonderrechte, Beenden.
struct NaviLeisteUnten: View {
    let n: Navistand
    @Binding var sonderrechte: Bool
    let beenden: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(n.titel.isEmpty ? "Ziel" : n.titel).font(.headline).lineLimit(1)
                    if let f = n.fortschritt, !f.angekommen {
                        let ankunft = Date.now.addingTimeInterval(f.restSekunden)
                        Text("\(ankunft.formatted(date: .omitted, time: .shortened)) Ankunft · \(Format.shared.dauer(sekunden: f.restSekunden)) · \(Format.shared.entfernung(meter: f.restMeter))")
                            .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    }
                    if n.info.verkehr { Text("Umfährt Stau oder Sperrung").font(.caption).foregroundStyle(.tint) }
                }
                Spacer(minLength: 0)
                Button("Beenden", action: beenden)
                    .font(.headline)
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .accessibilityIdentifier("Navigation beenden")
            }
            Toggle("Sonderrechte", isOn: $sonderrechte)
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .tint(sonderrechte ? .red : .primary)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
