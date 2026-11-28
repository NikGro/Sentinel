package de.nglab.sentinel.dienst

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import de.nglab.sentinel.MainActivity
import de.nglab.sentinel.R
import de.nglab.sentinel.kern.lage.Dringlichkeit
import de.nglab.sentinel.kern.lage.Meldung

/** Systemmitteilungen für wichtige Meldungen (Notruf, Geofence, A-Wechsel); Inhalt und Dringlichkeit aus dem Kern. */
object Mitteilungen {
    private const val KANAL_ALARM = "alarm"
    private const val KANAL_WICHTIG = "wichtig"

    fun einrichten(kontext: Context) {
        val nm = kontext.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(KANAL_ALARM, "Alarme", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Notruf und Geofence-Alarme, mit Ton und Vibration."
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 400, 200, 400, 200, 800)
        })
        nm.createNotificationChannel(NotificationChannel(KANAL_WICHTIG, "Lage", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Wechsel der A-Position und andere wichtige Hinweise."
        })
    }

    fun zeigen(kontext: Context, m: Meldung) {
        if (!m.systemmitteilung) return
        if (ContextCompat.checkSelfPermission(kontext, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
            android.os.Build.VERSION.SDK_INT >= 33
        ) return
        val oeffnen = PendingIntent.getActivity(kontext, 0, Intent(kontext, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_IMMUTABLE)
        val alarm = m.dringlichkeit == Dringlichkeit.Alarm
        val n = NotificationCompat.Builder(kontext, if (alarm) KANAL_ALARM else KANAL_WICHTIG)
            .setSmallIcon(R.drawable.ic_schild_klein)
            .setColor(0xFFFF3B30.toInt())
            .setContentTitle(m.titel)
            .setContentText(m.text)
            .setPriority(if (alarm) NotificationCompat.PRIORITY_MAX else NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(if (alarm) NotificationCompat.CATEGORY_ALARM else NotificationCompat.CATEGORY_STATUS)
            .setContentIntent(oeffnen)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(kontext).notify(m.kennung.hashCode(), n) }
    }
}
