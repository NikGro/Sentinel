package de.nglab.sentinel.kern.modell

import kotlinx.serialization.Serializable
import kotlin.math.PI
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** Ort in Grad (WGS 84). */
@Serializable
data class GeoPunkt(val lat: Double, val lon: Double) {
    /** Großkreisentfernung in Metern (Haversine). */
    fun distanz(zu: GeoPunkt): Double {
        val r = 6_371_000.0
        val dLat = (zu.lat - lat).rad
        val dLon = (zu.lon - lon).rad
        val a = sin(dLat / 2) * sin(dLat / 2) + cos(lat.rad) * cos(zu.lat.rad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(sqrt(a.coerceIn(0.0, 1.0)))
    }

    /** Richtung von hier nach `zu` in Grad (0 = Norden, im Uhrzeigersinn). */
    fun richtung(zu: GeoPunkt): Double {
        val y = sin((zu.lon - lon).rad) * cos(zu.lat.rad)
        val x = cos(lat.rad) * sin(zu.lat.rad) - sin(lat.rad) * cos(zu.lat.rad) * cos((zu.lon - lon).rad)
        return (atan2(y, x) * 180 / PI + 360) % 360
    }
}

internal val Double.rad: Double get() = this * PI / 180

/** Ort mit Zeitpunkt (ms seit 1970), z. B. ein abgestelltes Fahrzeug oder ein von Hand gesetztes Ziel. */
@Serializable
data class ZeitPunkt(val lat: Double, val lon: Double, val ts: Long) {
    val punkt: GeoPunkt get() = GeoPunkt(lat, lon)
}

/** Live-Position eines Fahnders oder Trackers; Genauigkeit in m, Tempo in m/s, Kurs in Grad. */
@Serializable
data class Position(
    val lat: Double,
    val lon: Double,
    val ts: Long,
    val acc: Double? = null,
    val spd: Double? = null,
    val hdg: Double? = null,
) {
    val punkt: GeoPunkt get() = GeoPunkt(lat, lon)
}
