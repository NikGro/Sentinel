package de.nglab.sentinel

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import de.nglab.sentinel.ui.Einrichtung
import de.nglab.sentinel.ui.Hauptansicht
import de.nglab.sentinel.ui.ProfilAnlegen
import de.nglab.sentinel.ui.SentinelThema
import de.nglab.sentinel.ui.Verbinde

class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val modell = (application as SentinelApp).modell
        // Standort (und auf neueren Android-Versionen Mitteilungen) erst nach der Anmeldung erfragen, wie auf iOS.
        val anfrage = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { modell.vordergrund(true) }
        val rechte = buildList {
            add(Manifest.permission.ACCESS_FINE_LOCATION)
            add(Manifest.permission.ACCESS_COARSE_LOCATION)
            if (Build.VERSION.SDK_INT >= 33) add(Manifest.permission.POST_NOTIFICATIONS)
        }
        setContent {
            SentinelThema {
                val phase by modell.phase.collectAsStateWithLifecycle()
                androidx.compose.runtime.LaunchedEffect(phase == Phase.Einrichtung) {
                    if (phase != Phase.Einrichtung && !modell.standort.erlaubt) anfrage.launch(rechte.toTypedArray())
                }
                val meldung by modell.meldung.collectAsStateWithLifecycle()
                androidx.compose.foundation.layout.Box {
                    when (phase) {
                        Phase.Einrichtung -> Einrichtung(modell)
                        Phase.Verbinde -> Verbinde(modell)
                        Phase.Profil -> ProfilAnlegen(modell)
                        Phase.Bereit -> Hauptansicht(modell)
                    }
                    de.nglab.sentinel.ui.Banner(meldung) { modell.meldungGelesen() }
                    val gesperrt by modell.gesperrt.collectAsStateWithLifecycle()
                    if (gesperrt && phase != Phase.Einrichtung) de.nglab.sentinel.ui.Sperrbildschirm { entsperren() }
                }
            }
        }
    }

    /** Fingerabdruck, Gesicht oder Gerätecode; bei Erfolg ist die App entsperrt. */
    private fun entsperren() {
        val modell = (application as SentinelApp).modell
        val erlaubt = androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK or androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
        if (androidx.biometric.BiometricManager.from(this).canAuthenticate(erlaubt) != androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS) {
            // Ohne eingerichtete Sperre am Gerät lässt sich nicht prüfen; dann nicht aussperren.
            modell.entsperrt()
            return
        }
        val prompt = androidx.biometric.BiometricPrompt(this, androidx.core.content.ContextCompat.getMainExecutor(this), object : androidx.biometric.BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: androidx.biometric.BiometricPrompt.AuthenticationResult) = modell.entsperrt()
        })
        prompt.authenticate(
            androidx.biometric.BiometricPrompt.PromptInfo.Builder().setTitle("SENTINEL entsperren").setAllowedAuthenticators(erlaubt).build(),
        )
    }
}
