package de.nglab.sentinel

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
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

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val modell = (application as SentinelApp).modell
        // Standort (und auf neueren Android-Versionen Mitteilungen) beim ersten Start erfragen.
        val anfrage = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { modell.vordergrund(true) }
        val rechte = buildList {
            add(Manifest.permission.ACCESS_FINE_LOCATION)
            add(Manifest.permission.ACCESS_COARSE_LOCATION)
            if (Build.VERSION.SDK_INT >= 33) add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (!modell.standort.erlaubt) anfrage.launch(rechte.toTypedArray())
        setContent {
            SentinelThema {
                val phase by modell.phase.collectAsStateWithLifecycle()
                when (phase) {
                    Phase.Einrichtung -> Einrichtung(modell)
                    Phase.Verbinde -> Verbinde(modell)
                    Phase.Profil -> ProfilAnlegen(modell)
                    Phase.Bereit -> Hauptansicht(modell)
                }
            }
        }
    }
}
