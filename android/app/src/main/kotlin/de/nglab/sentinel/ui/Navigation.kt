package de.nglab.sentinel.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.TurnLeft
import androidx.compose.material.icons.filled.TurnRight
import androidx.compose.material.icons.filled.TurnSlightLeft
import androidx.compose.material.icons.filled.TurnSlightRight
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.RoundaboutRight
import androidx.compose.material.icons.filled.Straight
import androidx.compose.material.icons.filled.UTurnLeft
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.nglab.sentinel.kern.format.Format
import de.nglab.sentinel.kern.navi.Manoever
import de.nglab.sentinel.kern.navi.Naviziel
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.navi.Navistand

/** Bild eines Manövers (Material Symbols). */
fun Manoever.bild(): ImageVector = when (this) {
    Manoever.Geradeaus -> Icons.Filled.Straight
    Manoever.Rechts -> Icons.Filled.TurnRight
    Manoever.LeichtRechts -> Icons.Filled.TurnSlightRight
    Manoever.Links -> Icons.Filled.TurnLeft
    Manoever.LeichtLinks -> Icons.Filled.TurnSlightLeft
    Manoever.Wenden -> Icons.Filled.UTurnLeft
    Manoever.Kreisverkehr -> Icons.Filled.RoundaboutRight
    Manoever.Start -> Icons.Filled.Navigation
    Manoever.Ziel -> Icons.Filled.Flag
}

/** Navi-Leiste oben: nächstes Manöver groß, darunter das übernächste und die Fahrspuren (gleich wie auf iOS). */
@Composable
fun NaviLeisteOben(n: Navistand) {
    val f = n.fortschritt
    val farbe = if (n.info.sonderrechte) SentinelFarben.aPosition else Color(0xFF1C6E3D)
    Surface(
        color = farbe,
        contentColor = Color.White,
        shape = RoundedCornerShape(24.dp),
        shadowElevation = 6.dp,
        modifier = Modifier.statusBarsPadding().padding(horizontal = 12.dp, vertical = 8.dp).fillMaxWidth().testTag("Navileiste"),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            when {
                f != null -> {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        Icon(f.manoever.bild(), null, Modifier.size(44.dp))
                        Column(Modifier.weight(1f)) {
                            if (!f.angekommen) Text(Format.entfernung(f.bisManoever), fontSize = 28.sp, fontWeight = FontWeight.Bold)
                            Text(f.anweisung, style = MaterialTheme.typography.titleMedium, maxLines = 2)
                        }
                    }
                    if (f.spuren.size > 1) {
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            for (s in f.spuren) {
                                Box(
                                    Modifier.size(30.dp).background(if (s.aktiv) Color.White else Color.White.copy(alpha = 0.18f), RoundedCornerShape(6.dp)),
                                    contentAlignment = Alignment.Center,
                                ) { Icon((s.symbole.firstOrNull() ?: Manoever.Geradeaus).bild(), null, tint = if (s.aktiv) farbe else Color.White, modifier = Modifier.size(20.dp)) }
                            }
                        }
                    }
                    f.danach?.let { d ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Dann", color = Color.White.copy(alpha = 0.8f))
                            f.danachManoever?.let { Icon(it.bild(), null, Modifier.size(18.dp)) }
                            Text(d, maxLines = 1, color = Color.White.copy(alpha = 0.9f))
                        }
                    }
                }
                n.fehler != null -> Text(n.fehler, style = MaterialTheme.typography.titleMedium)
                else -> {
                    Text("Route wird berechnet …", style = MaterialTheme.typography.titleMedium)
                    LinearProgressIndicator(Modifier.fillMaxWidth(), color = Color.White, trackColor = Color.White.copy(alpha = 0.3f))
                }
            }
        }
    }
}

/** Navi-Leiste unten: Ankunft, Restzeit, Entfernung, Sonderrechte, Beenden. */
@Composable
fun NaviLeisteUnten(n: Navistand, sonderrechte: Boolean, sonderrechteUmschalten: () -> Unit, modusWaehlen: (Naviziel) -> Unit, beenden: () -> Unit, zielImOepnv: Boolean = false) {
    val f = n.fortschritt
    val jetzt = System.currentTimeMillis()
    Surface(shape = RoundedCornerShape(24.dp), tonalElevation = 3.dp, shadowElevation = 4.dp, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(n.titel.ifBlank { "Ziel" }, style = MaterialTheme.typography.titleMedium, maxLines = 1)
                    if (f != null && !f.angekommen) {
                        Text(
                            "${Format.uhrzeit(f.ankunftMs(jetzt))} Ankunft · ${Format.dauer(f.restSekunden)} · ${Format.entfernung(f.restMeter)}",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (n.info.verkehr) Text("Umfährt Stau oder Sperrung", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodySmall)
                }
                Button(
                    onClick = beenden,
                    colors = ButtonDefaults.buttonColors(containerColor = SentinelFarben.aPosition, contentColor = Color.White),
                    modifier = Modifier.height(48.dp).testTag("Navigation beenden"),
                ) { Text("Beenden") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                FilterChip(selected = sonderrechte, onClick = sonderrechteUmschalten, label = { Text("Sonderrechte") })
                // Bei bewegten Zielen: direkt, Vorlauf (Kreuzung davor) oder parallel (Nebenstrecke)
                val basis = n.ziel.basis
                if (basis is Naviziel.APosition || (basis is Naviziel.Objekt && basis.objekt.art in listOf(Objektart.Kraft, Objektart.Fahrzeug, Objektart.Ziel))) {
                    FilterChip(selected = n.ziel is Naviziel.Vorlauf, onClick = { modusWaehlen(if (n.ziel is Naviziel.Vorlauf) basis else Naviziel.Vorlauf(basis)) }, label = { Text("Vorlauf") })
                    FilterChip(selected = n.ziel is Naviziel.Parallel, onClick = { modusWaehlen(if (n.ziel is Naviziel.Parallel) basis else Naviziel.Parallel(basis)) }, label = { Text("Parallel") })
                }
                n.tempolimit?.let { Tempolimit(it) }
            }
            // Ziel im ÖPNV: zum Fahrzeug oder ein bis zwei Halte voraus (rückt mit)
            if (zielImOepnv) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val basis = n.ziel.basis
                for (halte in 1..2) {
                    val gewaehlt = (n.ziel as? Naviziel.HalteVoraus)?.halte == halte
                    FilterChip(selected = gewaehlt, onClick = { modusWaehlen(if (gewaehlt) basis else Naviziel.HalteVoraus(basis, halte)) }, label = { Text(if (halte == 1) "1 Halt voraus" else "2 Halte voraus") })
                }
            }
        }
    }
}

/** Tempolimit-Schild (rot umrandet, wie im Straßenverkehr). */
@Composable
fun Tempolimit(kmh: Int) {
    Box(
        Modifier.size(40.dp).background(Color.White, androidx.compose.foundation.shape.CircleShape)
            .border(4.dp, Color(0xFFE2001A), androidx.compose.foundation.shape.CircleShape),
        contentAlignment = Alignment.Center,
    ) { Text("$kmh", color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 14.sp) }
}
