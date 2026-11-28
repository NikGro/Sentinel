package de.nglab.sentinel.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import de.nglab.sentinel.AppModell
import de.nglab.sentinel.kern.format.Format
import de.nglab.sentinel.kern.lage.Lage
import de.nglab.sentinel.kern.oepnv.Abfahrt
import de.nglab.sentinel.kern.oepnv.Fahrt
import de.nglab.sentinel.kern.oepnv.LiveHalt
import de.nglab.sentinel.kern.oepnv.Linienart
import de.nglab.sentinel.kern.oepnv.OepnvLive

/** Liniennummer im Schild (Farbe nach Art bzw. Linie, wie auf der Karte). */
@Composable
fun Linienschild(name: String, mode: String, eigene: String? = null) {
    val farbe = hexFarbe(Linienart.farbe(Linienart.typ(mode), name, eigene))
    Box(Modifier.background(farbe, RoundedCornerShape(6.dp)).padding(horizontal = 7.dp, vertical = 2.dp)) {
        Text(name, color = if (farbe.luminanz() > 0.65f) Color.Black else Color.White, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelLarge)
    }
}

private fun Color.luminanz() = 0.299f * red + 0.587f * green + 0.114f * blue

/**
 * Fahrtverlauf eines ÖPNV-Fahrzeugs (Halte mit Zeiten) und Übernehmen in die Lage: nur Fahrzeug (verschwindet nach
 * der Ankunft) oder mit Strecke und Halten. Gleich aufgebaut wie auf iOS.
 */
@Composable
fun FahrtAnsicht(modell: AppModell, tripId: String, fertig: () -> Unit) {
    var fahrt by remember(tripId) { mutableStateOf<Fahrt?>(null) }
    var laedt by remember(tripId) { mutableStateOf(true) }
    var strecke by remember { mutableStateOf(true) }
    var halte by remember { mutableStateOf(true) }
    LaunchedEffect(tripId) {
        fahrt = modell.api?.let { OepnvLive.fahrt(it, tripId) }
        laedt = false
    }
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        val f = fahrt
        when {
            laedt -> CircularProgressIndicator()
            f == null -> Text("Fahrt konnte nicht geladen werden.", color = MaterialTheme.colorScheme.error)
            else -> {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Linienschild(f.name, f.mode, f.color)
                    Text(f.headsign.ifBlank { Linienart.titel(Linienart.typ(f.mode), f.name) }, style = MaterialTheme.typography.titleMedium)
                }
                Text(if (f.realTime) "Mit Echtzeit" else "Nach Fahrplan", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = strecke, onClick = { strecke = !strecke }, label = { Text("Strecke") })
                    FilterChip(selected = halte, onClick = { halte = !halte }, label = { Text("Halte") })
                }
                Button(
                    onClick = {
                        OepnvLive.alsStrecke(f, fahrzeug = true, strecke = strecke, halte = halte, jetztMs = System.currentTimeMillis())?.let { modell.lage.markierungSichern(it, Lage.neueId()) }
                        fertig()
                    },
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                ) { Text(if (!strecke && !halte) "Fahrzeug übernehmen" else "In die Lage übernehmen") }
                HorizontalDivider()
                val jetzt = System.currentTimeMillis()
                LazyColumn(Modifier.height(320.dp)) {
                    items(f.stops) { h ->
                        val zeit = h.dep ?: h.arr
                        val vorbei = zeit != null && zeit < jetzt
                        Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(zeit?.let { Format.uhrzeit(it) } ?: "–", modifier = Modifier.width(52.dp), color = if (vorbei) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
                            Text(h.name, color = if (vorbei) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
                        }
                    }
                }
            }
        }
    }
}

/** Abfahrten einer Haltestelle; Antippen zeigt den Fahrtverlauf. Haltestelle selbst lässt sich übernehmen. */
@Composable
fun AbfahrtenAnsicht(modell: AppModell, halt: LiveHalt, fahrtWaehlen: (String) -> Unit, fertig: () -> Unit) {
    var abfahrten by remember(halt.stopId) { mutableStateOf<List<Abfahrt>?>(null) }
    LaunchedEffect(halt.stopId) { abfahrten = modell.api?.let { OepnvLive.abfahrten(it, halt.stopId) } ?: emptyList() }
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(halt.name, style = MaterialTheme.typography.titleLarge)
        OutlinedButton(onClick = { modell.lage.markierungSichern(OepnvLive.alsHaltestelle(halt), Lage.neueId()); fertig() }) { Text("Haltestelle übernehmen") }
        val liste = abfahrten
        when {
            liste == null -> CircularProgressIndicator()
            liste.isEmpty() -> Text("Keine Abfahrten in nächster Zeit.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            else -> LazyColumn(Modifier.height(360.dp)) {
                items(liste, key = { it.tripId + it.time }) { a ->
                    val minuten = ((a.time - System.currentTimeMillis()) / 60_000).coerceAtLeast(0)
                    ListItem(
                        leadingContent = { Linienschild(a.name, a.mode, a.color) },
                        headlineContent = { Text(a.headsign) },
                        supportingContent = {
                            val spaet = ((a.time - a.scheduled) / 1000).toInt()
                            Text("${Format.uhrzeit(a.time)} · ${Linienart.verspaetung(spaet, a.realTime)}")
                        },
                        trailingContent = { Text(if (minuten == 0L) "jetzt" else "$minuten Min.", fontWeight = FontWeight.SemiBold) },
                        modifier = Modifier.clickable { fahrtWaehlen(a.tripId) },
                    )
                }
            }
        }
    }
}
