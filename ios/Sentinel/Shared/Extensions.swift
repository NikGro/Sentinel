import Foundation

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

extension Double {
    /// Gerundet als ganze Zahl; `nil` bei unendlich oder ungültig (Int(∞) bricht sonst das Programm ab).
    var roundedInt: Int? {
        guard isFinite, abs(self) < Double(Int.max) else { return nil }
        return Int(rounded())
    }
}
