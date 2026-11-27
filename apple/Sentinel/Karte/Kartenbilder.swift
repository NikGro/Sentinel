import SentinelKern
import UIKit

/// Erzeugt die Bilder, die der gemeinsame Kartenstil anfordert (`grund-#RRGGBB`, `schild-#RRGGBB`, `sym-<schlüssel>`,
/// `zeichen-a`, `ich-*`), mit SF Symbols. Maße wie auf Android: Symbol 40 pt, Zeichen 22 pt.
enum Kartenbilder {
    static func bild(_ name: String) -> UIImage? {
        if name.hasPrefix("grund-") { return grund(farbe(String(name.dropFirst(6)))) }
        if name.hasPrefix("schild-") { return schild(farbe(String(name.dropFirst(7)))) }
        if name.hasPrefix("sym-") {
            guard let symbol = Symbol.entries.first(where: { $0.bildname == name }) else { return nil }
            return zeichen(symbol.sf, groesse: 20)
        }
        switch name {
        case "zeichen-a": return buchstabeA()
        case "ich-punkt": return ichPunkt()
        case "ich-pfeil": return ichPfeil()
        case "ich-fahrzeug": return ichFahrzeug()
        default: return nil
        }
    }

    private static func farbe(_ hex: String) -> UIColor {
        var wert: UInt64 = 0
        let text = hex.replacingOccurrences(of: "#", with: "")
        guard text.count == 6, Scanner(string: text).scanHexInt64(&wert) else { return UIColor(red: 1, green: 0.62, blue: 0.04, alpha: 1) }
        return UIColor(red: CGFloat((wert >> 16) & 0xFF) / 255, green: CGFloat((wert >> 8) & 0xFF) / 255, blue: CGFloat(wert & 0xFF) / 255, alpha: 1)
    }

    /// Abgerundetes Quadrat in der Gruppenfarbe mit weißem Rand und leichtem Schatten.
    private static func grund(_ f: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 44, height: 44)).image { k in
            let r = CGRect(x: 3, y: 2, width: 38, height: 38)
            k.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.35).cgColor)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: r, cornerRadius: 11).fill()
            k.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            f.setFill()
            UIBezierPath(roundedRect: r.insetBy(dx: 2, dy: 2), cornerRadius: 9).fill()
        }
    }

    /// Linienschild, in der Mitte dehnbar (wächst mit dem Text der Linie).
    private static func schild(_ f: UIColor) -> UIImage {
        let bild = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 22)).image { _ in
            let r = CGRect(x: 1, y: 1, width: 28, height: 20)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: r, cornerRadius: 5).fill()
            f.setFill()
            UIBezierPath(roundedRect: r.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 4).fill()
        }
        return bild.resizableImage(withCapInsets: UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6), resizingMode: .stretch)
    }

    static func zeichen(_ sf: String, groesse: CGFloat, farbe: UIColor = .white) -> UIImage? {
        let konfig = UIImage.SymbolConfiguration(pointSize: groesse, weight: .semibold)
        return UIImage(systemName: sf, withConfiguration: konfig)?.withTintColor(farbe, renderingMode: .alwaysOriginal)
    }

    private static func buchstabeA() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 18, height: 18)).image { _ in
            let r = CGRect(x: 1, y: 1, width: 16, height: 16)
            UIColor.systemRed.setFill()
            UIBezierPath(ovalIn: r).fill()
            UIColor.white.setStroke()
            let rand = UIBezierPath(ovalIn: r)
            rand.lineWidth = 1.5
            rand.stroke()
            let text = NSAttributedString(string: "A", attributes: [.font: UIFont.systemFont(ofSize: 11, weight: .heavy), .foregroundColor: UIColor.white])
            let g = text.size()
            text.draw(at: CGPoint(x: 9 - g.width / 2, y: 9 - g.height / 2))
        }
    }

    private static func ichPunkt() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 26, height: 26)).image { k in
            k.cgContext.setShadow(offset: CGSize(width: 0, height: 0.5), blur: 2, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 22, height: 22)).fill()
            k.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor.systemBlue.setFill()
            UIBezierPath(ovalIn: CGRect(x: 5, y: 5, width: 16, height: 16)).fill()
        }
    }

    private static func ichPfeil() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 48, height: 48)).image { k in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 24, y: 4))
            p.addLine(to: CGPoint(x: 40, y: 42))
            p.addLine(to: CGPoint(x: 24, y: 32))
            p.addLine(to: CGPoint(x: 8, y: 42))
            p.close()
            k.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.35).cgColor)
            UIColor.systemBlue.setFill()
            p.fill()
            k.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor.white.setStroke()
            p.lineWidth = 2.5
            p.lineJoinStyle = .round
            p.stroke()
        }
    }

    private static func ichFahrzeug() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 36, height: 36)).image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: 34, height: 34)).fill()
            UIColor.systemBlue.setFill()
            UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 30, height: 30)).fill()
            zeichen("car.fill", groesse: 15)?.draw(in: CGRect(x: 8, y: 9, width: 20, height: 18))
        }
    }
}
