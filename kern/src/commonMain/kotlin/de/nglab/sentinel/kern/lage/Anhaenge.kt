package de.nglab.sentinel.kern.lage

import de.nglab.sentinel.kern.modell.Anhang
import de.nglab.sentinel.kern.modell.Anhangart
import de.nglab.sentinel.kern.modell.Ziel
import de.nglab.sentinel.kern.netz.HochgeladeneDatei

/**
 * Fotos und Dateien an Zielen, gemeinsam für alle Plattformen. Die Datei liegt einmal auf dem Server (Blob); am Ziel
 * steht nur der Verweis. Ein Bild kann Titelfoto sein (`fotoBlob`), es erscheint dann in Kopfzeile und Liste.
 */
object Anhaenge {
    /** Höchste Kantenlänge, auf die Fotos vor dem Hochladen verkleinert werden (spart Speicher und Datenvolumen). */
    const val FOTO_KANTE = 2048
    const val FOTO_QUALITAET = 0.82

    fun aus(d: HochgeladeneDatei, name: String): Anhang = Anhang(
        blobId = d.id,
        art = when {
            d.mime.startsWith("image/") -> Anhangart.Bild
            d.mime.startsWith("audio/") -> Anhangart.Audio
            else -> Anhangart.Datei
        },
        name = name.take(120),
        mime = d.mime,
        groesse = d.groesse,
    )

    /** Anhang hinzufügen; das erste Bild wird Titelfoto, solange keines gesetzt ist. */
    fun hinzufuegen(z: Ziel, a: Anhang): Ziel {
        val neu = z.copy(anhaenge = z.anhaenge.filter { it.blobId != a.blobId } + a)
        return if (neu.fotoBlob == null && a.art == Anhangart.Bild) neu.copy(fotoBlob = a.blobId) else neu
    }

    /** Anhang entfernen; war es das Titelfoto, rückt das nächste Bild nach. */
    fun entfernen(z: Ziel, blobId: String): Ziel {
        val rest = z.anhaenge.filter { it.blobId != blobId }
        val titel = if (z.fotoBlob == blobId) rest.firstOrNull { it.art == Anhangart.Bild }?.blobId else z.fotoBlob
        return z.copy(anhaenge = rest, fotoBlob = titel)
    }

    fun alsTitelfoto(z: Ziel, blobId: String): Ziel = z.copy(fotoBlob = blobId)

    /** Titelfoto, auch bei älteren Ständen mit eigenem Fahrzeugfoto. */
    fun titelfoto(z: Ziel): String? = z.fotoBlob ?: z.fahrzeugFotoBlob

    fun bilder(z: Ziel): List<Anhang> = z.anhaenge.filter { it.art == Anhangart.Bild }
    fun dateien(z: Ziel): List<Anhang> = z.anhaenge.filter { it.art != Anhangart.Bild }

    fun groesseText(bytes: Long): String = when {
        bytes >= 1_000_000 -> "${(bytes / 100_000) / 10.0} MB"
        bytes >= 1_000 -> "${bytes / 1_000} kB"
        else -> "$bytes B"
    }
}
