package de.nglab.sentinel.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import de.nglab.sentinel.karte.bild
import de.nglab.sentinel.kern.format.Format
import de.nglab.sentinel.kern.karte.Anlegbar
import de.nglab.sentinel.kern.karte.Farben
import de.nglab.sentinel.kern.karte.Formen
import de.nglab.sentinel.kern.karte.Markierungseditor
import de.nglab.sentinel.kern.karte.Platzierung
import de.nglab.sentinel.kern.karte.Symbol
import de.nglab.sentinel.kern.karte.Zielerfassung
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.Ausloeser
import de.nglab.sentinel.kern.modell.Ebene
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.Ziel
import de.nglab.sentinel.kern.modell.Zielart
import kotlin.math.roundToInt

/** Farbe aus „#RRGGBB“. */
fun hexFarbe(hex: String): Color = runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(SentinelFarben.akzent)

/**
 * Plus-Menü: Ziele und Markierungen anlegen, gleiche Reihenfolge und Begriffe wie auf iOS (aus dem Kern).
 * `ort`: angelegt wird direkt an diesem Ort (Suchtreffer, gedrückter Ort), sonst folgt der Platzierungsmodus.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PlusMenue(waehlen: (Anlegbar) -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Hinzufügen", style = MaterialTheme.typography.titleLarge)
        for ((titel, eintraege) in listOf("Ziel" to Anlegbar.ziele, "Markierung" to Anlegbar.markierungen)) {
            Text(titel, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp), maxItemsInEachRow = 4) {
                for (e in eintraege) Anlegekachel(e, Modifier.weight(1f)) { waehlen(e) }
            }
        }
    }
}

@Composable
private fun Anlegekachel(e: Anlegbar, modifier: Modifier, aktion: () -> Unit) {
    val farbe = when (e) {
        is Anlegbar.NeuesZiel -> SentinelFarben.ziele
        is Anlegbar.NeueForm -> hexFarbe(Formen.farbe(e.form))
        Anlegbar.Standortspur -> hexFarbe("#FF375F")
    }
    Column(
        modifier.clickable(onClick = aktion).padding(vertical = 4.dp).testTag("Anlegen ${e.titel}"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(Modifier.size(52.dp).background(farbe.copy(alpha = 0.18f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(e.symbol.bild(), null, tint = farbe)
        }
        Text(e.titel, style = MaterialTheme.typography.labelMedium, maxLines = 2)
    }
}

/** Gelbe Leiste oben im Platzierungsmodus: Hinweis, Zurücknehmen, Abbrechen, Fertig. */
@Composable
fun Platzierungsleiste(p: Platzierung, zuruecknehmen: () -> Unit, abbrechen: () -> Unit, fertig: () -> Unit) {
    Surface(
        color = SentinelFarben.setzen,
        contentColor = Color.Black,
        shape = RoundedCornerShape(24.dp),
        shadowElevation = 4.dp,
        modifier = Modifier.statusBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth().testTag("Platzierungsleiste"),
    ) {
        Row(Modifier.padding(start = 6.dp, end = 8.dp).height(52.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = abbrechen) { Icon(Icons.Filled.Close, "Abbrechen") }
            Text(p.hinweis, fontWeight = FontWeight.SemiBold, maxLines = 2, modifier = Modifier.weight(1f))
            if (p.mehrpunkt) IconButton(onClick = zuruecknehmen, enabled = p.kannZuruecknehmen) { Icon(Icons.AutoMirrored.Filled.Undo, "Letzten Punkt entfernen") }
            Button(
                onClick = fertig,
                enabled = p.kannBestaetigen,
                colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = Color.Black, contentColor = SentinelFarben.setzen),
            ) { Text(if (p.mehrpunkt) "Fertig" else "Bestätigen") }
        }
    }
}

/**
 * Editor einer Markierung (neu oder bestehend). Felder je nach Form, Prüfen und Bereinigen im Kern.
 * `sichern` erhält den bereinigten Stand.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MarkierungsEditor(
    stand: LageStand,
    start: Markierung,
    neu: Boolean,
    zuletzt: String?,
    abbrechen: () -> Unit,
    sichern: (Markierung) -> Unit,
    verschieben: () -> Unit,
    loeschen: () -> Unit,
) {
    var m by remember { mutableStateOf(start) }
    var lebensdauer by remember { mutableStateOf<Int?>(if (neu) 0 else null) }
    val fehlt = Markierungseditor.fehlt(m)
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = abbrechen) { Text("Abbrechen") }
            Text(if (neu) "Neu: ${Formen.titel(m.typ)}" else Formen.titel(m.typ), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f), maxLines = 1)
            Button(onClick = { sichern(Markierungseditor.sichern(m, lebensdauer, System.currentTimeMillis())) }, enabled = fehlt == null, modifier = Modifier.testTag("Sichern")) { Text("Sichern") }
        }
        fehlt?.let { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall) }

        OutlinedTextField(m.titel, { m = m.copy(titel = it) }, label = { Text(if (m.typ == Form.Text) "Text" else "Bezeichnung") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(m.notiz, { m = m.copy(notiz = it) }, label = { Text("Notiz") }, minLines = 2, modifier = Modifier.fillMaxWidth())

        if (Markierungseditor.zeigtFarbe(m)) {
            Abschnitt("Farbe")
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                for ((name, hex) in Farben.palette) {
                    val gewaehlt = m.farbe.equals(hex, ignoreCase = true)
                    Box(
                        Modifier.size(34.dp).then(if (gewaehlt) Modifier.border(3.dp, MaterialTheme.colorScheme.onSurface, CircleShape) else Modifier)
                            .padding(4.dp).background(hexFarbe(hex), CircleShape).clickable(onClickLabel = name) { m = m.copy(farbe = hex) },
                    )
                }
            }
        }

        if (Markierungseditor.zeigtSymbol(m)) {
            Abschnitt("Symbol")
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp), maxItemsInEachRow = 8) {
                val aktuell = Symbol.vonGespeichert(m.symbol)
                for (s in Symbol.marker) {
                    val gewaehlt = s == aktuell
                    Box(
                        Modifier.size(38.dp).background(if (gewaehlt) hexFarbe(m.farbe).copy(alpha = 0.35f) else MaterialTheme.colorScheme.surfaceContainerHigh, CircleShape)
                            .clickable { m = m.copy(symbol = s.schluessel) },
                        contentAlignment = Alignment.Center,
                    ) { Icon(s.bild(), s.schluessel, Modifier.size(20.dp)) }
                }
            }
        }

        if (Markierungseditor.zeigtRadius(m)) {
            val r = Markierungseditor.radius(m).coerceAtMost(Markierungseditor.reglerMax(m))
            Abschnitt(if (m.typ == Form.Haltestellen) "Umkreis" else "Radius")
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Slider(
                    value = r.toFloat(),
                    onValueChange = { m = m.copy(radius = ((it / 10).roundToInt() * 10).toDouble()) },
                    valueRange = Markierungseditor.radiusMin(m).toFloat()..Markierungseditor.reglerMax(m).toFloat(),
                    modifier = Modifier.weight(1f),
                )
                Text(Format.entfernung(r), modifier = Modifier.width(72.dp))
            }
        }

        if (Markierungseditor.zeigtZiele(m)) {
            Abschnitt("Alarm beim")
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                val optionen = listOf(Ausloeser.Verlassen to "Verlassen", Ausloeser.Betreten to "Betreten")
                optionen.forEachIndexed { i, (a, t) ->
                    SegmentedButton(selected = (m.ausloeser ?: Ausloeser.Verlassen) == a, onClick = { m = m.copy(ausloeser = a) }, shape = SegmentedButtonDefaults.itemShape(i, optionen.size)) { Text(t) }
                }
            }
            Abschnitt("Überwachte Ziele")
            for (z in stand.zieleSortiert) {
                val drin = z.id in m.ziele
                ListItem(
                    headlineContent = { Text(z.data.anzeigename) },
                    leadingContent = { Checkbox(drin, { m = m.copy(ziele = if (drin) m.ziele - z.id else m.ziele + z.id) }) },
                    modifier = Modifier.clickable { m = m.copy(ziele = if (drin) m.ziele - z.id else m.ziele + z.id) },
                )
            }
        }

        val ebenen = stand.ebenenSortiert.filter { it.data.art == Ebene.LAGE || it.data.art == Ebene.DAUERHAFT }
        if (ebenen.size > 1) {
            Auswahlfeld("Ebene", ebenen.map { it.id to it.data.name }, m.layerId) { m = m.copy(layerId = it) }
        }

        if (Markierungseditor.zeigtLebensdauer(m)) {
            val optionen = buildList {
                if (!neu) add(null to (m.ablauf?.let { "Bis ${Format.datumUhrzeit(it)}" } ?: "Unverändert"))
                addAll(Markierungseditor.lebensdauern.map { it.sekunden to it.titel })
            }
            Auswahlfeld("Lebensdauer", optionen, lebensdauer) { lebensdauer = it }
            Text(
                if (lebensdauer == 0 || (lebensdauer == null && m.ablauf == null)) "Bleibt, bis sie jemand löscht." else "Löscht sich danach von selbst, damit die Karte übersichtlich bleibt.",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        if (!neu) {
            HorizontalDivider()
            if (!m.typ.istOepnv) OutlinedButton(onClick = verschieben, modifier = Modifier.fillMaxWidth()) { Text("Auf der Karte verschieben") }
            OutlinedButton(onClick = loeschen, modifier = Modifier.fillMaxWidth()) { Text("Löschen", color = MaterialTheme.colorScheme.error) }
            zuletzt?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}

/** Schnellerfassung eines neuen Ziels nach dem Platzieren: die Felder, die es auf der Karte benennen. */
@Composable
fun ZielAnlegen(start: Ziel, abbrechen: () -> Unit, sichern: (Ziel) -> Unit) {
    var z by remember { mutableStateOf(start) }
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = abbrechen) { Text("Abbrechen") }
            Text("Neu: ${Anlegbar.NeuesZiel(z.art).titel}", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            Button(onClick = { sichern(Zielerfassung.fertig(z, z.vorname, z.nachname, z.bezeichnung, z.kennzeichen, z.anschrift, z.hinweise)) }, modifier = Modifier.testTag("Sichern")) { Text("Sichern") }
        }
        when (z.art) {
            Zielart.Person -> {
                OutlinedTextField(z.vorname, { z = z.copy(vorname = it) }, label = { Text("Vorname") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(z.nachname, { z = z.copy(nachname = it) }, label = { Text("Nachname") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(z.bezeichnung, { z = z.copy(bezeichnung = it) }, label = { Text("Bezeichnung (falls Name unbekannt)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            }
            Zielart.Fahrzeug -> {
                OutlinedTextField(z.kennzeichen, { z = z.copy(kennzeichen = it) }, label = { Text("Kennzeichen") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(z.bezeichnung, { z = z.copy(bezeichnung = it) }, label = { Text("Fahrzeug (Marke, Modell, Farbe)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            }
            Zielart.Objekt -> {
                OutlinedTextField(z.bezeichnung, { z = z.copy(bezeichnung = it) }, label = { Text("Bezeichnung") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(z.anschrift, { z = z.copy(anschrift = it) }, label = { Text("Anschrift") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            }
        }
        OutlinedTextField(z.hinweise, { z = z.copy(hinweise = it) }, label = { Text("Hinweise") }, minLines = 3, modifier = Modifier.fillMaxWidth())
    }
}

@Composable
private fun Abschnitt(titel: String) {
    Text(titel, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <T> Auswahlfeld(titel: String, optionen: List<Pair<T, String>>, wert: T, waehlen: (T) -> Unit) {
    var offen by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = offen, onExpandedChange = { offen = it }) {
        OutlinedTextField(
            value = optionen.firstOrNull { it.first == wert }?.second ?: "",
            onValueChange = {},
            readOnly = true,
            label = { Text(titel) },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(offen) },
            modifier = Modifier.fillMaxWidth().menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable),
        )
        ExposedDropdownMenu(expanded = offen, onDismissRequest = { offen = false }) {
            for ((w, t) in optionen) DropdownMenuItem(text = { Text(t) }, onClick = { waehlen(w); offen = false })
        }
    }
}
