package de.nglab.sentinel.karte

import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.DoorFront
import androidx.compose.material.icons.filled.Euro
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LocalParking
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Radar
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Timeline
import androidx.compose.material.icons.filled.Title
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Work
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.VectorGroup
import androidx.compose.ui.graphics.vector.VectorPath
import androidx.compose.ui.graphics.vector.toPath
import de.nglab.sentinel.kern.karte.Symbol
import org.maplibre.android.maps.Style

/** Material-Symbol zu jedem plattformneutralen Symbol des Kerns. */
fun Symbol.bild(): ImageVector = when (this) {
    Symbol.Fuss, Symbol.Gehen -> Icons.Filled.DirectionsWalk
    Symbol.Fahrzeug, Symbol.Zielfahrzeug, Symbol.Auto -> Icons.Filled.DirectionsCar
    Symbol.Oepnv, Symbol.Bahn -> Icons.Filled.Tram
    Symbol.Person, Symbol.Mensch -> Icons.Filled.Person
    Symbol.Objekt, Symbol.Haus -> Icons.Filled.Home
    Symbol.Nadel -> Icons.Filled.LocationOn
    Symbol.Fahne -> Icons.Filled.Flag
    Symbol.Auge -> Icons.Filled.Visibility
    Symbol.Gebaeude -> Icons.Filled.Apartment
    Symbol.Warnung -> Icons.Filled.Warning
    Symbol.Kamera -> Icons.Filled.PhotoCamera
    Symbol.Tuer -> Icons.Filled.DoorFront
    Symbol.Parken -> Icons.Filled.LocalParking
    Symbol.Kreuz -> Icons.Filled.Add
    Symbol.Stern -> Icons.Filled.Star
    Symbol.Verboten -> Icons.Filled.Cancel
    Symbol.Text -> Icons.Filled.Title
    Symbol.Fahndungsraum -> Icons.Filled.Radar
    Symbol.Haltestelle -> Icons.Filled.DirectionsBus
    Symbol.Geofence, Symbol.Schild -> Icons.Filled.Shield
    Symbol.Verlauf -> Icons.Filled.Timeline
    Symbol.Ordner -> Icons.Filled.Folder
    Symbol.Aktenkoffer -> Icons.Filled.Work
    Symbol.Ziel -> Icons.Filled.MyLocation
    Symbol.Personen -> Icons.Filled.Group
    Symbol.Lkw -> Icons.Filled.LocalShipping
    Symbol.Telefon -> Icons.Filled.Call
    Symbol.Geld -> Icons.Filled.Euro
    Symbol.Schloss -> Icons.Filled.Lock
    Symbol.Glocke -> Icons.Filled.Notifications
}

/**
 * Erzeugt die Bilder, die der gemeinsame Kartenstil anfordert, erst wenn sie gebraucht werden (`grund-#RRGGBB`,
 * `schild-#RRGGBB`, `sym-<schlüssel>`, `zeichen-a`, `ich-*`). Maße wie auf iOS: Symbol 40 pt, Zeichen 22 pt.
 */
object Kartenbilder {
    private val dichte = Resources.getSystem().displayMetrics.density
    private fun px(dp: Float) = dp * dichte

    fun anlegen(style: Style, name: String) {
        when {
            name.startsWith("grund-") -> style.addImage(name, grund(farbe(name.removePrefix("grund-"))))
            name.startsWith("schild-") -> {
                val b = schild(farbe(name.removePrefix("schild-")))
                // Dehnbar in der Mitte, damit das Schild mit dem Text der Linie wächst.
                val rand = px(5f)
                style.addImage(
                    name, b,
                    listOf(org.maplibre.android.maps.ImageStretches(rand, b.width - rand)),
                    listOf(org.maplibre.android.maps.ImageStretches(rand, b.height - rand)),
                    org.maplibre.android.maps.ImageContent(rand, rand, b.width - rand, b.height - rand),
                )
            }
            name.startsWith("sym-") -> Symbol.entries.firstOrNull { it.bildname == name }?.let { style.addImage(name, zeichen(it.bild(), 22f, Color.WHITE)) }
            name == "zeichen-a" -> style.addImage(name, buchstabeA())
            name == "ich-punkt" -> style.addImage(name, ichPunkt())
            name == "ich-pfeil" -> style.addImage(name, ichPfeil())
            name == "ich-fahrzeug" -> style.addImage(name, ichFahrzeug())
        }
    }

    private fun farbe(hex: String): Int = runCatching { Color.parseColor(hex) }.getOrDefault(Color.parseColor("#FF9F0A"))

    /** Abgerundetes Quadrat in der Gruppenfarbe mit weißem Rand und leichtem Schatten. */
    private fun grund(f: Int): Bitmap {
        val groesse = px(44f).toInt()
        val b = Bitmap.createBitmap(groesse, groesse, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        val r = RectF(px(3f), px(2f), groesse - px(3f), groesse - px(4f))
        val schatten = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.TRANSPARENT; setShadowLayer(px(2.5f), 0f, px(1f), Color.argb(90, 0, 0, 0)) }
        c.drawRoundRect(r, px(11f), px(11f), schatten)
        c.drawRoundRect(r, px(11f), px(11f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
        val innen = RectF(r.left + px(2f), r.top + px(2f), r.right - px(2f), r.bottom - px(2f))
        c.drawRoundRect(innen, px(9f), px(9f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = f })
        return b
    }

    /** Linienschild: abgerundetes Rechteck in Linienfarbe mit weißem Rand. */
    private fun schild(f: Int): Bitmap {
        val w = px(30f).toInt()
        val h = px(22f).toInt()
        val b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        val r = RectF(px(1f), px(1f), w - px(1f), h - px(1f))
        c.drawRoundRect(r, px(5f), px(5f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
        c.drawRoundRect(RectF(r.left + px(1.5f), r.top + px(1.5f), r.right - px(1.5f), r.bottom - px(1.5f)), px(4f), px(4f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = f })
        return b
    }

    /** Material-Symbol als Bitmap (Pfade aus dem Vektor, 24er-Raster skaliert). */
    fun zeichen(bild: ImageVector, dp: Float, f: Int): Bitmap {
        val groesse = px(dp).toInt().coerceAtLeast(1)
        val b = Bitmap.createBitmap(groesse, groesse, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        val skala = groesse / bild.viewportWidth
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = f; style = Paint.Style.FILL }
        fun zeichnen(gruppe: VectorGroup) {
            for (knoten in gruppe) {
                when (knoten) {
                    is VectorPath -> {
                        val pfad: Path = knoten.pathData.toPath().asAndroidPath()
                        pfad.transform(Matrix().apply { setScale(skala, skala) })
                        c.drawPath(pfad, paint)
                    }
                    is VectorGroup -> zeichnen(knoten)
                }
            }
        }
        zeichnen(bild.root)
        return b
    }

    private fun buchstabeA(): Bitmap {
        val g = px(18f).toInt()
        val b = Bitmap.createBitmap(g, g, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        c.drawCircle(g / 2f, g / 2f, g / 2f - px(1f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#FF3B30") })
        c.drawCircle(g / 2f, g / 2f, g / 2f - px(1f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; style = Paint.Style.STROKE; strokeWidth = px(1.5f) })
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; textSize = px(11f); typeface = Typeface.DEFAULT_BOLD; textAlign = Paint.Align.CENTER }
        c.drawText("A", g / 2f, g / 2f - (text.descent() + text.ascent()) / 2, text)
        return b
    }

    private fun ichPunkt(): Bitmap {
        val g = px(26f).toInt()
        val b = Bitmap.createBitmap(g, g, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        c.drawCircle(g / 2f, g / 2f, px(11f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; setShadowLayer(px(2f), 0f, px(0.5f), Color.argb(80, 0, 0, 0)) })
        c.drawCircle(g / 2f, g / 2f, px(8f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#0A84FF") })
        return b
    }

    private fun ichPfeil(): Bitmap {
        val g = px(48f).toInt()
        val b = Bitmap.createBitmap(g, g, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        val p = Path().apply {
            moveTo(g / 2f, px(4f)); lineTo(g - px(8f), g - px(6f)); lineTo(g / 2f, g - px(16f)); lineTo(px(8f), g - px(6f)); close()
        }
        c.drawPath(p, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#0A84FF"); setShadowLayer(px(3f), 0f, px(1f), Color.argb(90, 0, 0, 0)) })
        c.drawPath(p, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; style = Paint.Style.STROKE; strokeWidth = px(2.5f); strokeJoin = Paint.Join.ROUND })
        return b
    }

    private fun ichFahrzeug(): Bitmap {
        val g = px(36f).toInt()
        val b = Bitmap.createBitmap(g, g, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        c.drawCircle(g / 2f, g / 2f, g / 2f - px(1f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
        c.drawCircle(g / 2f, g / 2f, g / 2f - px(3f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#0A84FF") })
        val z = zeichen(Icons.Filled.DirectionsCar, 20f, Color.WHITE)
        c.drawBitmap(z, (g - z.width) / 2f, (g - z.height) / 2f, null)
        return b
    }
}
