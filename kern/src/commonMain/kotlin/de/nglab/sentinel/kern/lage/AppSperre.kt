package de.nglab.sentinel.kern.lage

/**
 * App-Sperre: Nach einer Zeit im Hintergrund fragt die App beim Zurückkehren nach Face ID, Fingerabdruck bzw.
 * Gerätecode. Gleiche Regel auf allen Plattformen.
 */
object AppSperre {
    data class Frist(val sekunden: Int, val titel: String)

    val fristen: List<Frist> = listOf(Frist(0, "Sofort"), Frist(60, "Nach 1 Minute"), Frist(300, "Nach 5 Minuten"), Frist(900, "Nach 15 Minuten"))

    /** Muss beim Zurückkehren entsperrt werden? `imHintergrundSeitMs`: wann die App in den Hintergrund ging. */
    fun sperren(an: Boolean, fristSekunden: Int, imHintergrundSeitMs: Long?, jetztMs: Long): Boolean =
        an && imHintergrundSeitMs != null && jetztMs - imHintergrundSeitMs >= fristSekunden * 1000L

    fun fristTitel(sekunden: Int): String = fristen.firstOrNull { it.sekunden == sekunden }?.titel ?: "Sofort"
}
