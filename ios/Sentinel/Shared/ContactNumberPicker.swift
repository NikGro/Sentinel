import ContactsUI
import SwiftUI

/// Übernimmt eine Rufnummer aus den Kontakten (z. B. aus der eigenen Karte "Meine Karte").
/// iOS gibt Apps die eigene Rufnummer der SIM nicht preis; die Auswahl über die Kontakte ist der vorgesehene Weg.
/// Der Auswahldialog läuft außerhalb der App und braucht keine Kontakte-Berechtigung.
struct ContactNumberPicker: UIViewControllerRepresentable {
    let onPick: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let controller = CNContactPickerViewController()
        controller.delegate = context.coordinator
        controller.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        controller.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        controller.predicateForSelectionOfContact = NSPredicate(format: "phoneNumbers.@count == 1")
        return controller
    }

    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String) -> Void

        init(onPick: @escaping (String) -> Void) {
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            if let number = contact.phoneNumbers.first?.value.stringValue { onPick(number) }
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            if let number = (contactProperty.value as? CNPhoneNumber)?.stringValue { onPick(number) }
        }
    }
}

enum PhoneNumber {
    /// Bringt eine Rufnummer in die Form, die der Server akzeptiert (Ziffern, Leerzeichen, +, Klammern, Schräg- und Bindestrich).
    static func sanitize(_ input: String) -> String {
        let allowed = CharacterSet(charactersIn: "+0123456789 ()/-")
        let cleaned = String(input.unicodeScalars.filter { allowed.contains($0) })
        return String(cleaned.trimmingCharacters(in: .whitespaces).prefix(24))
    }

    static func callURL(_ number: String) -> URL? {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }
}
