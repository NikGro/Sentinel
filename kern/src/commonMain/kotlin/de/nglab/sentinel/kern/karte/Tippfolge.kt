package de.nglab.sentinel.kern.karte

/**
 * Mehrfach tippen auf dieselbe Stelle schaltet übereinanderliegende Objekte durch (oberstes zuerst). Die Oberfläche
 * gibt die getroffenen Schlüssel („art:kennung“) in der Reihenfolge der Engine; Doppelte fallen weg.
 */
class Tippfolge(private val fristMs: Long = 4_000) {
    private var letzte: List<String> = emptyList()
    private var index = 0
    private var zeit = 0L

    fun waehlen(treffer: List<String>, jetztMs: Long): KartenObjekt? {
        val liste = treffer.distinct()
        if (liste.isEmpty()) { letzte = emptyList(); return null }
        index = if (liste == letzte && jetztMs - zeit <= fristMs) (index + 1) % liste.size else 0
        letzte = liste
        zeit = jetztMs
        return KartenObjekt.von(liste[index])
    }

    /** Wie viele Objekte an der zuletzt getippten Stelle liegen (für einen Hinweis „1 von 3“). */
    val anzahl: Int get() = letzte.size
    val position: Int get() = index + 1
}
