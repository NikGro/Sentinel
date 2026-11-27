package de.nglab.sentinel

import android.app.Application
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import org.maplibre.android.MapLibre

class SentinelApp : Application() {
    lateinit var modell: AppModell
        private set

    override fun onCreate() {
        super.onCreate()
        MapLibre.getInstance(this)
        modell = AppModell(this)
        // Sichtbarkeit der App: Standort für die Karte nur, solange sie sichtbar ist (außer im Dienst).
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) = modell.vordergrund(true)
            override fun onStop(owner: LifecycleOwner) = modell.vordergrund(false)
        })
    }
}
