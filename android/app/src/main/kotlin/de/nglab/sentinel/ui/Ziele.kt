package de.nglab.sentinel.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import de.nglab.sentinel.AppModell
import de.nglab.sentinel.karte.bild
import de.nglab.sentinel.kern.format.Format
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.lage.Beziehungen
import de.nglab.sentinel.kern.lage.Kurzinfo
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.lage.Lage
import de.nglab.sentinel.kern.lage.Zieleditor
import de.nglab.sentinel.kern.modell.Art
import de.nglab.sentinel.kern.modell.Standortquelle
import de.nglab.sentinel.kern.modell.Ziel

/** Ziele-Tab: nach Gruppen geordnet, Antippen öffnet die Zielansicht. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Zielliste(modell: AppModell, stand: LageStand, aufKarte: (KartenObjekt) -> Unit) {
    var offen by rememberSaveable { mutableStateOf<String?>(null) }
    offen?.let { id ->
        if (stand.ziele[id] != null) {
            Zielansicht(modell, stand, id, zurueck = { offen = null }, aufKarte = { aufKarte(KartenObjekt(Objektart.Ziel, id)) })
            return
        }
    }
    Column(Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("Ziele") })
        LazyColumn {
            val gruppen = stand.zielgruppenSortiert
            val ohne = stand.zieleSortiert.filter { z -> z.data.gruppeId == null || stand.zielgruppen[z.data.gruppeId] == null }
            for (g in gruppen) {
                val drin = stand.zieleSortiert.filter { it.data.gruppeId == g.id }
                item(key = "g-${g.id}") { Abschnittskopf(g.data.name, hexFarbe(g.data.farbe)) }
                items(drin, key = { it.id }) { z -> Zielzeile(stand, z.id) { offen = z.id } }
            }
            if (ohne.isNotEmpty()) {
                if (gruppen.isNotEmpty()) item(key = "ohne") { Abschnittskopf("Ohne Gruppe", null) }
                items(ohne, key = { it.id }) { z -> Zielzeile(stand, z.id) { offen = z.id } }
            }
            if (stand.ziele.isEmpty()) item { Text("Noch keine Ziele. Über „+“ auf der Karte anlegen.", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(20.dp)) }
        }
    }
}

@Composable
private fun Abschnittskopf(titel: String, farbe: Color?) {
    Row(Modifier.padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        farbe?.let { Box(Modifier.size(10.dp).background(it, CircleShape)) }
        Text(titel, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
private fun Zielzeile(stand: LageStand, id: String, oeffnen: () -> Unit) {
    val info = Kurzinfo.fuer(stand, KartenObjekt(Objektart.Ziel, id), System.currentTimeMillis(), null) ?: return
    val sichtbar = stand.zielEingeblendet(id)
    ListItem(
        headlineContent = { Text(info.titel) },
        supportingContent = { Text(info.zeilen.firstOrNull { it.titel == "Stand" }?.wert ?: info.untertitel, maxLines = 1) },
        leadingContent = {
            Box(Modifier.size(36.dp).background(hexFarbe(info.farbe).copy(alpha = if (sichtbar) 1f else 0.35f), CircleShape), contentAlignment = Alignment.Center) {
                Icon(info.symbol.bild(), null, tint = Color.White, modifier = Modifier.size(20.dp))
            }
        },
        modifier = Modifier.clickable(onClick = oeffnen).testTag("Ziel ${info.titel}"),
    )
}

/**
 * Zielansicht: alle Angaben eines Ziels, Standortquelle, Unterwegs (Personen), Gruppe, Beziehungen, Sichtbarkeit.
 * Felder und Regeln kommen aus dem Kern (gleich wie auf iOS). Änderungen gelten erst mit „Sichern“.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Zielansicht(modell: AppModell, stand: LageStand, id: String, zurueck: () -> Unit, aufKarte: () -> Unit, standortSetzen: (() -> Unit)? = null) {
    val v = stand.ziele[id] ?: return
    var z by remember(id) { mutableStateOf(v.data) }
    val geaendert = z != v.data
    var loeschen by remember { mutableStateOf(false) }
    var beziehungNeu by remember { mutableStateOf(false) }
    val fehlt = Zieleditor.fehlt(z)
    val jetzt = System.currentTimeMillis()

    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(v.data.anzeigename, maxLines = 1) },
            navigationIcon = { IconButton(onClick = zurueck) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Zurück") } },
            actions = {
                if (geaendert) TextButton(onClick = { z = v.data }) { Text("Verwerfen") }
                Button(
                    onClick = { modell.lage.setzen(Art.Ziel, id, Zieleditor.fertig(z)) },
                    enabled = geaendert && fehlt == null,
                    modifier = Modifier.padding(end = 8.dp).testTag("Sichern"),
                ) { Text("Sichern") }
            },
        )
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            fehlt?.let { Text(it, color = MaterialTheme.colorScheme.error) }

            // Ort und Quelle
            Abschnittstitel("Standort")
            val o = stand.ortung(v, jetzt)
            Text(o?.let { "Stand ${Format.vor(it.zeitMs, jetzt)}" } ?: "Keine Position", color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (o != null) OutlinedButton(onClick = aufKarte) { Text("Auf der Karte") }
                standortSetzen?.let { OutlinedButton(onClick = it) { Text("Standort setzen") } }
            }
            val quellen = Zieleditor.quellen(z)
            if (quellen.size > 1) {
                Auswahl("Standortquelle", quellen.map { it to Zieleditor.quelleTitel(it) }, z.gewaehlteQuelle) { q ->
                    z = Zieleditor.mitQuelle(z, q, z.trackerId ?: stand.tracker.keys.firstOrNull())
                }
                if (z.gewaehlteQuelle == Standortquelle.Tracker) {
                    val tracker = stand.tracker.values.sortedBy { it.data.name }
                    if (tracker.isEmpty()) Text("Kein Tracker angelegt.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    else Auswahl("Tracker", tracker.map { it.id to it.data.name }, z.trackerId) { t -> z = Zieleditor.mitQuelle(z, Standortquelle.Tracker, t) }
                }
            }

            // Unterwegs: sofort wirksam, unabhängig von „Sichern“
            val bindungen = Zieleditor.bindungsziele(stand, id)
            if (bindungen.size > 1) {
                Abschnittstitel("Unterwegs")
                val aktuell = Zieleditor.aktuelleBindung(stand, id)
                Auswahl("Wo ist die Person?", bindungen.map { it.schluessel to it.titel }, aktuell?.schluessel) { s ->
                    val b = bindungen.first { it.schluessel == s }
                    Zieleditor.binden(stand, id, b, System.currentTimeMillis())?.let { neu ->
                        modell.lage.setzen(Art.Ziel, id, neu)
                        z = z.copy(bindung = neu.bindung, quelle = neu.quelle, standort = neu.standort)
                    }
                }
            }

            // Angaben
            Abschnittstitel("Angaben")
            for (f in Zieleditor.felder(z.art)) {
                OutlinedTextField(
                    value = Zieleditor.wert(z, f.schluessel),
                    onValueChange = { z = Zieleditor.setzen(z, f.schluessel, it) },
                    label = { Text(f.titel) },
                    placeholder = { if (f.hinweis.isNotBlank()) Text(f.hinweis) },
                    singleLine = !f.mehrzeilig,
                    minLines = if (f.mehrzeilig) 4 else 1,
                    keyboardOptions = KeyboardOptions(capitalization = if (f.grossbuchstaben) KeyboardCapitalization.Characters else KeyboardCapitalization.Sentences),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (z.art == de.nglab.sentinel.kern.modell.Zielart.Person) {
                val heute = java.time.LocalDate.now()
                Zieleditor.alter(z.geburtsdatum, heute.year, heute.monthValue, heute.dayOfMonth)?.let { Text("$it Jahre", color = MaterialTheme.colorScheme.onSurfaceVariant) }
            }

            // Gruppe
            if (stand.zielgruppen.isNotEmpty()) {
                Auswahl("Gruppe", listOf<Pair<String?, String>>(null to "Keine") + stand.zielgruppenSortiert.map { it.id to it.data.name }, z.gruppeId) { g -> z = z.copy(gruppeId = g) }
            }

            // Sichtbarkeit: sofort wirksam
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Auf der Karte zeigen", modifier = Modifier.weight(1f))
                Switch(checked = stand.zielEingeblendet(id), onCheckedChange = { modell.lage.zielEinblenden(id, it) })
            }

            // Beziehungen: sofort wirksam
            Abschnittstitel("Beziehungen")
            val verbunden = stand.verbundeneZiele(id)
            if (verbunden.isEmpty()) Text("Keine. Halter, Fahrer, Bewohner usw. als eigene Ziele anlegen und hier verbinden.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            for (b in verbunden) {
                ListItem(
                    headlineContent = { Text(b.anderes.data.anzeigename) },
                    supportingContent = { Text(listOf(b.beziehung.data.bezeichnung, Beziehungen.statusTitel(b.beziehung.data.status)).filter { it.isNotBlank() }.joinToString(" · ")) },
                    trailingContent = { TextButton(onClick = { modell.lage.loeschen(Art.Beziehung, b.beziehung.id) }) { Text("Lösen") } },
                )
            }
            if (Beziehungen.kandidaten(stand, id).isNotEmpty()) OutlinedButton(onClick = { beziehungNeu = true }) { Text("Verbinden") }

            HorizontalDivider()
            OutlinedButton(onClick = { loeschen = true }, modifier = Modifier.fillMaxWidth()) { Text("Ziel löschen", color = MaterialTheme.colorScheme.error) }
            Text("Zuletzt geändert von ${stand.name(v.updatedBy)}, ${Format.vor(v.updatedAt, jetzt)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }

    if (loeschen) {
        AlertDialog(
            onDismissRequest = { loeschen = false },
            title = { Text("Ziel löschen?") },
            text = { Text("„${v.data.anzeigename}“ wird für alle entfernt.") },
            confirmButton = { TextButton(onClick = { modell.lage.loeschen(Art.Ziel, id); loeschen = false; zurueck() }) { Text("Löschen", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { loeschen = false }) { Text("Abbrechen") } },
        )
    }
    if (beziehungNeu) BeziehungAnlegen(stand, id, abbrechen = { beziehungNeu = false }) { b ->
        modell.lage.setzen(Art.Beziehung, Lage.neueId(), b)
        beziehungNeu = false
    }
}

@Composable
private fun BeziehungAnlegen(stand: LageStand, id: String, abbrechen: () -> Unit, sichern: (de.nglab.sentinel.kern.modell.Beziehung) -> Unit) {
    val kandidaten = Beziehungen.kandidaten(stand, id)
    var anderes by remember { mutableStateOf(kandidaten.firstOrNull()?.id) }
    var bezeichnung by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = abbrechen,
        title = { Text("Verbinden") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Auswahl("Mit", kandidaten.map { it.id to it.data.anzeigename }, anderes) { anderes = it }
                OutlinedTextField(bezeichnung, { bezeichnung = it }, label = { Text("Beziehung") }, placeholder = { Text("z. B. Halter, Fahrer, Bewohner") }, singleLine = true)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (v in Beziehungen.vorschlaege.take(3)) androidx.compose.material3.AssistChip(onClick = { bezeichnung = v }, label = { Text(v) })
                }
            }
        },
        confirmButton = { TextButton(onClick = { anderes?.let { sichern(Beziehungen.neu(id, it, bezeichnung, stand.ichId)) } }, enabled = anderes != null) { Text("Verbinden") } },
        dismissButton = { TextButton(onClick = abbrechen) { Text("Abbrechen") } },
    )
}

@Composable
private fun Abschnittstitel(titel: String) {
    Text(titel, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 8.dp))
}

/** Auswahlfeld (aufklappbar) mit Titel; gleiche Bedienung wie im Markierungseditor. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> Auswahl(titel: String, optionen: List<Pair<T, String>>, wert: T, waehlen: (T) -> Unit) {
    var offen by remember { mutableStateOf(false) }
    androidx.compose.material3.ExposedDropdownMenuBox(expanded = offen, onExpandedChange = { offen = it }) {
        OutlinedTextField(
            value = optionen.firstOrNull { it.first == wert }?.second ?: "",
            onValueChange = {},
            readOnly = true,
            label = { Text(titel) },
            trailingIcon = { androidx.compose.material3.ExposedDropdownMenuDefaults.TrailingIcon(offen) },
            modifier = Modifier.fillMaxWidth().menuAnchor(androidx.compose.material3.ExposedDropdownMenuAnchorType.PrimaryNotEditable),
        )
        ExposedDropdownMenu(expanded = offen, onDismissRequest = { offen = false }) {
            for ((w, t) in optionen) androidx.compose.material3.DropdownMenuItem(text = { Text(t) }, onClick = { waehlen(w); offen = false })
        }
    }
}
