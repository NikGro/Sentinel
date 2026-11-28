package de.nglab.sentinel.kern.format

import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlin.math.roundToInt

/** Formate der App, durchgehend deutsch und auf allen Plattformen gleich. */
object Format {
    private val monate = listOf("Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sept.", "Okt.", "Nov.", "Dez.")

    private fun zwei(n: Int) = n.toString().padStart(2, '0')

    /** „14:30“ */
    fun uhrzeit(ms: Long, zone: TimeZone = TimeZone.currentSystemDefault()): String {
        val t = kotlin.time.Instant.fromEpochMilliseconds(ms).toLocalDateTime(zone)
        return "${zwei(t.hour)}:${zwei(t.minute)}"
    }

    /** „27. Nov. 2026, 14:30“ */
    fun datumUhrzeit(ms: Long, zone: TimeZone = TimeZone.currentSystemDefault()): String {
        val t = kotlin.time.Instant.fromEpochMilliseconds(ms).toLocalDateTime(zone)
        return "${t.dayOfMonth}. ${monate[t.monthNumber - 1]} ${t.year}, ${zwei(t.hour)}:${zwei(t.minute)}"
    }

    /** „vor 3 Min.“ bzw. „gerade eben“. */
    fun vor(ms: Long, jetztMs: Long): String {
        val s = (jetztMs - ms) / 1000
        return when {
            s < 20 -> "gerade eben"
            s < 90 -> "vor 1 Min."
            s < 3600 -> "vor ${s / 60} Min."
            s < 86_400 -> "vor ${s / 3600} Std."
            else -> datumUhrzeit(ms)
        }
    }

    /** Ablauf einer Lebensdauer, z. B. „in 25 Min. (14:30)“. */
    fun ablauf(ms: Long, jetztMs: Long): String {
        val s = (ms - jetztMs) / 1000
        return when {
            s <= 60 -> "gleich"
            s < 3600 -> "in ${s / 60} Min. (${uhrzeit(ms)})"
            s < 86_400 -> "in ${s / 3600} Std. (${uhrzeit(ms)})"
            else -> datumUhrzeit(ms)
        }
    }

    /** „350 m“, „1,2 km“, „12 km“ */
    fun entfernung(meter: Double): String = when {
        meter < 1000 -> "${(meter / 10).roundToInt() * 10} m"
        meter < 10_000 -> "${((meter / 100).roundToInt() / 10.0).toString().replace('.', ',')} km"
        else -> "${(meter / 1000).roundToInt()} km"
    }

    /** „5 Min.“, „1 Std. 20 Min.“ */
    fun dauer(sekunden: Double): String {
        if (!sekunden.isFinite()) return "–"
        val min = (sekunden / 60).roundToInt()
        return if (min < 60) "$min Min." else "${min / 60} Std. ${min % 60} Min."
    }

    /** Minuten und Sekunden, z. B. „1:05“. */
    fun uhr(sekunden: Double): String {
        if (!sekunden.isFinite()) return "–"
        val s = sekunden.roundToInt().coerceAtLeast(0)
        return "${s / 60}:${zwei(s % 60)}"
    }

    /** Tempo in km/h aus m/s. */
    fun kmh(meterJeSekunde: Double): String = "${(meterJeSekunde * 3.6).roundToInt()} km/h"
}
