package de.nglab.sentinel

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import de.nglab.sentinel.dienst.Ort
import de.nglab.sentinel.dienst.Standort
import de.nglab.sentinel.dienst.StandortDienst
import de.nglab.sentinel.kern.lage.Lage
import de.nglab.sentinel.kern.lage.LageEreignis
import de.nglab.sentinel.kern.netz.Api
import de.nglab.sentinel.kern.netz.Verbindung
import de.nglab.sentinel.kern.netz.Verbindungszustand
import de.nglab.sentinel.kern.netz.Zugang
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Phasen der App: Einrichtung, Verbindungsaufbau, Profil anlegen, die eigentliche App. */
enum class Phase { Einrichtung, Verbinde, Profil, Bereit }

/**
 * Zusammenbau der App: hält Lage, Verbindung und Serverzugriff und verbindet sie. Gegenstück zum `AppModel` der
 * iOS-App; die Regeln selbst stecken im gemeinsamen Kern.
 */
class AppModell(private val kontext: Context) {
    val bereich = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val http = Verbindung.httpClient()
    val lage = Lage()
    private val verbindung = Verbindung(http, bereich)
    val verbindungszustand: StateFlow<Verbindungszustand> get() = verbindung.zustand

    private val ablage = Zugangsablage(kontext)
    private val _zugang = MutableStateFlow(ablage.laden())
    val zugang: StateFlow<Zugang?> = _zugang.asStateFlow()

    private val _phase = MutableStateFlow(if (_zugang.value == null) Phase.Einrichtung else Phase.Verbinde)
    val phase: StateFlow<Phase> = _phase.asStateFlow()

    /** Letzte Meldung (Fehler, Hinweise), zur Anzeige als Banner. */
    private val _meldung = MutableStateFlow<LageEreignis?>(null)
    val meldung: StateFlow<LageEreignis?> = _meldung.asStateFlow()

    val api: Api? get() = _zugang.value?.let { Api(http, it.server, it.token) }

    /** Eigener Standort (Karte) und Übertragung im Dienst. */
    val standort = Standort(kontext)
    val ort: StateFlow<Ort?> get() = standort.ort
    private var imVordergrund = false
    private var dienstLaeuft = false

    /** Navigation (Ferrostar-Kern, Routen vom eigenen Server). */
    val navigator = de.nglab.sentinel.navi.Navigator({ _zugang.value?.server }, { _zugang.value?.token }, standort.roh)

    init {
        standort.beiPosition = { p -> if (lage.stand.value.imDienst) lage.positionSenden(p) }
        // Dienststatus steuert Übertragung und Benachrichtigung zentral, unabhängig von Ansichten: außer Dienst endet
        // alles sofort, auch wenn die App gerade nicht sichtbar ist.
        bereich.launch {
            lage.stand.collect { s -> dienstAnpassen(s.hatStand && s.imDienst) }
        }
        verbindung.beiNachricht = { text -> bereich.launch { lage.empfangen(text); phaseNachStand() } }
        verbindung.beiZugangEntzogen = { bereich.launch { abmelden(lokal = true) } }
        lage.beiEreignis = { e -> if (e !is LageEreignis.Position) _meldung.value = e }
        _zugang.value?.let { starten(it) }
    }

    private fun starten(z: Zugang) {
        lage.verbinden(z.geraetId) { verbindung.senden(it) }
        verbindung.starten(z)
    }

    private fun phaseNachStand() {
        val stand = lage.stand.value
        if (!stand.hatStand) return
        _phase.value = if (stand.ich == null) Phase.Profil else Phase.Bereit
    }

    private fun dienstAnpassen(imDienst: Boolean) {
        if (imDienst && !dienstLaeuft && standort.erlaubt) {
            dienstLaeuft = true
            StandortDienst.starten(kontext)
        } else if (!imDienst && dienstLaeuft) {
            dienstLaeuft = false
            StandortDienst.beenden(kontext)
            if (!imVordergrund) standort.stoppen()
        }
    }

    /** Die App ist sichtbar: Standort für die Karte, auch außer Dienst (ohne Übertragung). */
    fun vordergrund(sichtbar: Boolean) {
        imVordergrund = sichtbar
        if (sichtbar) {
            standort.starten()
            dienstAnpassen(lage.stand.value.hatStand && lage.stand.value.imDienst)
        } else if (!dienstLaeuft) {
            standort.stoppen()
        }
    }

    internal fun standortHintergrundBeendet() {
        dienstLaeuft = false
        if (!imVordergrund) standort.stoppen()
    }

    fun meldungGelesen() {
        _meldung.value = null
    }

    /** Meldet dieses Gerät mit dem Zugangscode am Server an. */
    suspend fun anmelden(serverEingabe: String, code: String) {
        val server = Api.serverAdresse(serverEingabe) ?: throw IllegalArgumentException("Bitte eine gültige HTTPS-Adresse eingeben.")
        val anmeldung = Api(http, server, null).anmelden(code.trim(), "${Build.MANUFACTURER} ${Build.MODEL}")
        val z = Zugang(server, anmeldung.deviceId, anmeldung.token)
        ablage.sichern(z)
        _zugang.value = z
        _phase.value = Phase.Verbinde
        starten(z)
    }

    /** Entfernt Anmeldung und alle Einsatzdaten von diesem Gerät; beim Server wird das Gerät gesperrt. */
    fun abmelden(lokal: Boolean = false) {
        val a = api
        if (!lokal && a != null) bereich.launch { runCatching { a.abmelden() } }
        navigator.stoppen()
        verbindung.stoppen()
        StandortDienst.beenden(kontext)
        dienstLaeuft = false
        lage.trennen()
        ablage.loeschen()
        _zugang.value = null
        _phase.value = Phase.Einrichtung
    }
}

/**
 * Anmeldung dieses Geräts, verschlüsselt mit einem Schlüssel im Android Keystore (an das Gerät gebunden, nicht
 * exportierbar, nicht in Sicherungen). Gegenstück zum Schlüsselbund auf iOS.
 */
class Zugangsablage(kontext: Context) {
    private val prefs = kontext.getSharedPreferences("zugang", Context.MODE_PRIVATE)
    private val alias = "sentinel-zugang"

    private fun schluessel(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(alias, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return gen.generateKey()
    }

    fun sichern(z: Zugang) {
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, schluessel())
        val daten = c.doFinal(z.token.toByteArray())
        prefs.edit()
            .putString("server", z.server)
            .putString("geraet", z.geraetId)
            .putString("token", Base64.encodeToString(daten, Base64.NO_WRAP))
            .putString("iv", Base64.encodeToString(c.iv, Base64.NO_WRAP))
            .apply()
    }

    fun laden(): Zugang? = runCatching {
        val server = prefs.getString("server", null) ?: return null
        val geraet = prefs.getString("geraet", null) ?: return null
        val token = Base64.decode(prefs.getString("token", null) ?: return null, Base64.NO_WRAP)
        val iv = Base64.decode(prefs.getString("iv", null) ?: return null, Base64.NO_WRAP)
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, schluessel(), GCMParameterSpec(128, iv))
        Zugang(server, geraet, String(c.doFinal(token)))
    }.getOrNull()

    fun loeschen() {
        prefs.edit().clear().apply()
    }
}
