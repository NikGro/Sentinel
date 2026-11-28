package de.nglab.sentinel.dienst

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import de.nglab.sentinel.MainActivity
import de.nglab.sentinel.R
import de.nglab.sentinel.SentinelApp
import de.nglab.sentinel.kern.modell.Position
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Eigener Standort für Karte und Übertragung. */
data class Ort(val lat: Double, val lon: Double, val zeitMs: Long, val genauigkeit: Double?, val tempo: Double?, val richtung: Double?)

/**
 * Standort im Vordergrund (für die Karte) und, solange man im Dienst ist, im Hintergrund über den `StandortDienst`.
 * Übertragen wird ab 5 m Bewegung, spätestens alle 15 s (Herzschlag), wie auf iOS.
 */
class Standort(private val kontext: Context) {
    private val _ort = MutableStateFlow<Ort?>(null)
    val ort: StateFlow<Ort?> = _ort.asStateFlow()

    /** Rohe Standorte für den Navigationskern (Ferrostar). */
    private val _roh = kotlinx.coroutines.flow.MutableSharedFlow<Location>(replay = 1, extraBufferCapacity = 8, onBufferOverflow = kotlinx.coroutines.channels.BufferOverflow.DROP_OLDEST)
    val roh: kotlinx.coroutines.flow.SharedFlow<Location> = _roh

    var beiPosition: (Position) -> Unit = {}
    private var zuletztGesendet: Ort? = null
    private val client = LocationServices.getFusedLocationProviderClient(kontext)
    private var laeuft = false

    private val rueckruf = object : LocationCallback() {
        override fun onLocationResult(ergebnis: LocationResult) {
            ergebnis.lastLocation?.let(::aufnehmen)
        }
    }

    val erlaubt: Boolean get() = ContextCompat.checkSelfPermission(kontext, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    fun starten() {
        if (laeuft || !erlaubt) return
        laeuft = true
        val anfrage = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1_000).setMinUpdateDistanceMeters(0f).build()
        client.requestLocationUpdates(anfrage, rueckruf, Looper.getMainLooper())
    }

    fun stoppen() {
        if (!laeuft) return
        laeuft = false
        client.removeLocationUpdates(rueckruf)
    }

    private fun aufnehmen(l: Location) {
        _roh.tryEmit(l)
        val o = Ort(l.latitude, l.longitude, l.time, l.accuracy.toDouble(), if (l.hasSpeed()) l.speed.toDouble() else null, if (l.hasBearing()) l.bearing.toDouble() else null)
        _ort.value = o
        val vorher = zuletztGesendet
        val abstand = vorher?.let { FloatArray(1).also { r -> Location.distanceBetween(it.lat, it.lon, o.lat, o.lon, r) }[0] } ?: Float.MAX_VALUE
        val zeit = vorher?.let { o.zeitMs - it.zeitMs } ?: Long.MAX_VALUE
        if (zeit >= 1_000 && (abstand >= 5 || zeit >= 15_000)) {
            zuletztGesendet = o
            beiPosition(Position(o.lat, o.lon, o.zeitMs, o.genauigkeit, o.tempo?.coerceIn(0.0, 200.0), o.richtung))
        }
    }
}

/**
 * Vordergrund-Dienst, solange der Standort im Dienst geteilt wird: laufende Benachrichtigung „SENTINEL teilt deinen
 * Standort“ (Gegenstück zur Live-Aktivität auf iOS). Außer Dienst wird er beendet; er startet nie von selbst neu.
 */
class StandortDienst : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val modell = (application as SentinelApp).modell
        if (!modell.lage.stand.value.imDienst) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(1, benachrichtigung(), ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        modell.standort.starten()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        (application as SentinelApp).modell.standortHintergrundBeendet()
    }

    private fun benachrichtigung(): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(KANAL, "Standort im Dienst", NotificationManager.IMPORTANCE_LOW).apply {
            description = "Zeigt an, solange SENTINEL deinen Standort an das Einsatzteam teilt."
            setShowBadge(false)
        })
        val oeffnen = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, KANAL)
            .setSmallIcon(R.drawable.ic_schild_klein)
            .setColor(0xFFFF3B30.toInt())
            .setContentTitle("SENTINEL teilt deinen Standort")
            .setContentText("Live an das Einsatzteam")
            .setOngoing(true)
            .setContentIntent(oeffnen)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    companion object {
        private const val KANAL = "standort"

        fun starten(kontext: Context) {
            ContextCompat.startForegroundService(kontext, Intent(kontext, StandortDienst::class.java))
        }

        fun beenden(kontext: Context) {
            kontext.stopService(Intent(kontext, StandortDienst::class.java))
        }
    }
}
