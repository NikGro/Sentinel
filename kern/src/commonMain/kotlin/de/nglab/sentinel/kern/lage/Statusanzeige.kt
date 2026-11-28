package de.nglab.sentinel.kern.lage

/**
 * Zweite Zeile der Daueranzeige im Dienst (Live-Aktivität auf iOS, Benachrichtigung auf Android): Instanz, Funkkanal
 * und ob man die A hält bzw. ein Notruf läuft. Gleicher Text auf allen Plattformen.
 */
object Statusanzeige {
    const val TITEL = "SENTINEL teilt deinen Standort"

    fun detail(stand: LageStand): String {
        val teile = ArrayList<String>()
        stand.fremderNotruf?.let { return "NOTRUF: ${it.data.spitzname}" }
        if (stand.eigenerNotruf) return "Notruf ausgelöst"
        teile += stand.aktuelleInstanz?.data?.name ?: "KSOD"
        stand.einsatz.funkkanal?.let { teile += "Kanal $it" }
        when {
            stand.haeltA -> teile += "Sie haben die A"
            stand.aHalter != null -> teile += "A: ${stand.aHalter!!.data.spitzname}"
        }
        return teile.joinToString(" · ")
    }

    /** Höchstens so oft wird die Anzeige ohne Textänderung verlängert (iOS begrenzt Aktualisierungen). */
    const val VERLAENGERN_MS = 60_000L
}
