import CoreLocation
import Foundation
import Observation
import SentinelKern
import UIKit

/// Phasen der App: Einrichtung, Verbindungsaufbau, Profil anlegen, die eigentliche App.
enum Phase {
    case einrichtung, verbinde, profil, bereit
}

/// Sendet über die Echtzeitverbindung des Kerns (Brücke für `Lage`).
private final class VerbindungsSender: NSObject, Sender {
    weak var verbindung: Verbindung?
    func senden(text: String) -> Bool { verbindung?.senden(text: text) ?? false }
}

private final class KeinSender: NSObject, Sender {
    func senden(text: String) -> Bool { false }
}

/// Zusammenbau der App: hält Lage, Verbindung und Serverzugriff und verbindet sie. Die Regeln stecken im gemeinsamen
/// Kern (identisch mit Android); hier nur die Anbindung an iOS.
@Observable
final class AppModell {
    private(set) var phase: Phase = .einrichtung
    private(set) var stand: LageStand = LageStand.companion.leer
    private(set) var verbindungszustand: Verbindungszustand = .getrennt
    private(set) var zugang: Zugang?
    /// Letzte Meldung (Fehler, Hinweise) für das Banner.
    var meldung: Meldung?

    @ObservationIgnored let lage = Lage(sender: KeinSender())
    @ObservationIgnored private let verbindung = Bruecke.shared.neueVerbindung()
    @ObservationIgnored private let sender = VerbindungsSender()
    @ObservationIgnored private var beobachter: [Abmelder] = []
    let standort = Standort()
    /// Navigation (Ferrostar-Kern, Routen vom eigenen Server).
    let navigator = Navigator()
    /// Spuren der Spur-Markierungen (Verlauf, Standortspur), laufend nachgeladen.
    @ObservationIgnored let spuren = Spurenlader()

    var api: Api? { zugang.map { Bruecke.shared.api(server: $0.server, token: $0.token) } }

    init() {
        sender.verbindung = verbindung
        verbindung.beiNachricht = { [weak self] text in
            self?.lage.empfangen(text: text)
        }
        verbindung.beiZugangEntzogen = { [weak self] in self?.abmelden(lokal: true) }
        lage.beiEreignis = { [weak self] ereignis in self?.ereignis(ereignis) }
        beobachter.append(Bruecke.shared.standBeobachten(lage: lage) { [weak self] neu in
            guard let self else { return }
            self.stand = neu
            self.phaseNachStand()
            self.standort.statuszeile = Statusanzeige.shared.detail(stand: neu)
            self.standort.dienst(neu.hatStand && neu.imDienst)
        })
        beobachter.append(Bruecke.shared.verbindungBeobachten(verbindung: verbindung) { [weak self] z in self?.verbindungszustand = z })
        standort.beiPosition = { [weak self] p in
            guard let self, self.stand.imDienst else { return }
            self.lage.positionSenden(p: p)
        }
        if let z = Zugangsablage.laden() {
            zugang = z
            phase = .verbinde
            starten(z)
        }
    }

    private func starten(_ z: Zugang) {
        navigator.verbinden(server: z.server, token: z.token)
        navigator.api = { [weak self] in self?.api }
        lage.verbinden(ichId: z.geraetId, sender: sender)
        verbindung.starten(zugang: z)
    }

    private func phaseNachStand() {
        guard stand.hatStand else { return }
        phase = stand.ich == nil ? .profil : .bereit
    }

    private func ereignis(_ e: LageEreignis) {
        guard let m = Meldungen.shared.aus(e: e, stand: stand) else { return }
        meldung = m
        // Im Vordergrund reicht das Banner, außer bei Alarmen; im Hintergrund die Systemmitteilung (wie Android).
        let vordergrund = UIApplication.shared.applicationState == .active
        if m.systemmitteilung, !vordergrund || m.dringlichkeit == .alarm { Mitteilungen.zeigen(m) }
    }

    // App-Sperre (Face ID bzw. Gerätecode nach einer Zeit im Hintergrund; Regel im Kern)
    var sperreAn: Bool = UserDefaults.standard.bool(forKey: "sperre") {
        didSet { UserDefaults.standard.set(sperreAn, forKey: "sperre") }
    }
    var sperreFrist: Int = UserDefaults.standard.object(forKey: "sperreFrist") as? Int ?? 60 {
        didSet { UserDefaults.standard.set(sperreFrist, forKey: "sperreFrist") }
    }
    var gesperrt: Bool = UserDefaults.standard.bool(forKey: "sperre")
    @ObservationIgnored private var hintergrundSeit: Date?

    func szenenwechsel(aktiv: Bool) {
        if !aktiv {
            if hintergrundSeit == nil { hintergrundSeit = .now }
            return
        }
        let seit = hintergrundSeit.map { KotlinLong(value: Int64($0.timeIntervalSince1970 * 1000)) }
        if AppSperre.shared.sperren(an: sperreAn, fristSekunden: Int32(sperreFrist), imHintergrundSeitMs: seit, jetztMs: Int64(Date.now.timeIntervalSince1970 * 1000)) {
            gesperrt = true
        }
        hintergrundSeit = nil
    }

    /// Fehlermeldung als Hinweis-Banner (lokale Fehler, z. B. bei der Anmeldung).
    func hinweis(_ text: String) {
        meldung = Meldung(titel: "Hinweis", text: text, dringlichkeit: .hinweis, objekt: nil, ort: nil, kennung: "fehler")
    }

    /// Meldet dieses Gerät mit dem Zugangscode am Server an.
    func anmelden(server eingabe: String, code: String) async throws {
        guard let server = Bruecke.shared.serverAdresse(eingabe: eingabe) else {
            throw NSError(domain: "Sentinel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bitte eine gültige HTTPS-Adresse eingeben."])
        }
        let anmeldung = try await Bruecke.shared.api(server: server, token: nil).anmelden(code: code.trimmingCharacters(in: .whitespaces), geraet: UIDevice.current.name)
        let z = Zugang(server: server, geraetId: anmeldung.deviceId, token: anmeldung.token)
        Zugangsablage.sichern(z)
        zugang = z
        phase = .verbinde
        starten(z)
        // Standort und Mitteilungen erst nach der Anmeldung erfragen und nutzen.
        standort.starten()
        Mitteilungen.erlaubnisErfragen()
    }

    /// Entfernt Anmeldung und alle Einsatzdaten von diesem Gerät; beim Server wird das Gerät gesperrt.
    func abmelden(lokal: Bool = false) {
        if !lokal, let api {
            Task { try? await api.abmelden() }
        }
        navigator.verbinden(server: nil, token: nil)
        verbindung.stoppen()
        lage.trennen()
        standort.dienst(false)
        Zugangsablage.loeschen()
        zugang = nil
        phase = .einrichtung
    }
}

/// Anmeldung im Schlüsselbund: an dieses Gerät gebunden, nicht in Backups oder iCloud.
enum Zugangsablage {
    private static let dienst = "de.nglab.sentinel.zugang"

    static func sichern(_ z: Zugang) {
        let daten = try? JSONSerialization.data(withJSONObject: ["server": z.server, "geraet": z.geraetId, "token": z.token])
        loeschen()
        guard let daten else { return }
        SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: dienst,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: daten,
        ] as CFDictionary, nil)
    }

    static func laden() -> Zugang? {
        var ergebnis: AnyObject?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: dienst,
            kSecReturnData: true,
        ] as CFDictionary, &ergebnis)
        guard status == errSecSuccess, let daten = ergebnis as? Data,
              let o = try? JSONSerialization.jsonObject(with: daten) as? [String: String],
              let server = o["server"], let geraet = o["geraet"], let token = o["token"] else { return nil }
        return Zugang(server: server, geraetId: geraet, token: token)
    }

    static func loeschen() {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: dienst] as CFDictionary)
    }
}
