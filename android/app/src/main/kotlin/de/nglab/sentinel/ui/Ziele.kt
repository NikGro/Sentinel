package de.nglab.sentinel.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Search
import de.nglab.sentinel.kern.lage.Zielgruppen
import de.nglab.sentinel.kern.lage.Zielverzeichnis
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
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

/**
 * Ziele-Tab: Suche, nach Gruppen geordnet, Antippen öffnet die Zielansicht. Lange drücken startet den Auswahlmodus
 * (mehrere Ziele einer Gruppe zuordnen). Gruppen lassen sich anlegen, umbenennen, umfärben und löschen.
 */
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun Zielliste(modell: AppModell, stand: LageStand, aufKarte: (KartenObjekt) -> Unit) {
    var offen by rememberSaveable { mutableStateOf<String?>(null) }
    var suche by rememberSaveable { mutableStateOf("") }
    var auswahl by remember { mutableStateOf(setOf<String>()) }
    var gruppeBearbeiten by remember { mutableStateOf<Pair<String?, de.nglab.sentinel.kern.modell.Zielgruppe>?>(null) }
    var zuordnenMenue by remember { mutableStateOf(false) }
    offen?.let { id ->
        if (stand.ziele[id] != null) {
            Zielansicht(modell, stand, id, zurueck = { offen = null }, aufKarte = { aufKarte(KartenObjekt(Objektart.Ziel, id)) }, oeffnen = { offen = it })
            return
        }
    }
    val auswahlModus = auswahl.isNotEmpty()
    Column(Modifier.fillMaxSize()) {
        if (auswahlModus) {
            TopAppBar(
                title = { Text("${auswahl.size} ausgewählt") },
                navigationIcon = { IconButton(onClick = { auswahl = emptySet() }) { Icon(Icons.Filled.Close, "Auswahl beenden") } },
                actions = {
                    Box {
                        TextButton(onClick = { zuordnenMenue = true }) { Text("Zur Gruppe") }
                        androidx.compose.material3.DropdownMenu(expanded = zuordnenMenue, onDismissRequest = { zuordnenMenue = false }) {
                            for (g in stand.zielgruppenSortiert) androidx.compose.material3.DropdownMenuItem(text = { Text(g.data.name) }, onClick = {
                                zuordnenMenue = false
                                for ((id, z) in Zielverzeichnis.zuordnen(stand, auswahl.toList(), g.id)) modell.lage.setzen(Art.Ziel, id, z)
                                auswahl = emptySet()
                            })
                            androidx.compose.material3.DropdownMenuItem(text = { Text("Neue Gruppe …") }, onClick = {
                                zuordnenMenue = false
                                gruppeBearbeiten = null to Zielgruppen.neu("", Zielgruppen.vorschlag(stand))
                            })
                            androidx.compose.material3.DropdownMenuItem(text = { Text("Aus der Gruppe nehmen") }, onClick = {
                                zuordnenMenue = false
                                for ((id, z) in Zielverzeichnis.zuordnen(stand, auswahl.toList(), null)) modell.lage.setzen(Art.Ziel, id, z)
                                auswahl = emptySet()
                            })
                        }
                    }
                },
            )
        } else {
            TopAppBar(
                title = { Text("Ziele") },
                actions = { TextButton(onClick = { gruppeBearbeiten = null to Zielgruppen.neu("", Zielgruppen.vorschlag(stand)) }) { Text("Neue Gruppe") } },
            )
        }
        OutlinedTextField(
            value = suche, onValueChange = { suche = it },
            placeholder = { Text("Ziele durchsuchen") },
            leadingIcon = { Icon(Icons.Filled.Search, null) },
            trailingIcon = { if (suche.isNotEmpty()) IconButton(onClick = { suche = "" }) { Icon(Icons.Filled.Close, "Leeren") } },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
        )
        LazyColumn {
            for (a in Zielverzeichnis.abschnitte(stand, suche)) {
                item(key = "g-${a.gruppeId}") {
                    Abschnittskopf(a.titel, a.farbe?.let { hexFarbe(it) }, bearbeiten = a.gruppeId?.let { gid -> { stand.zielgruppen[gid]?.let { gruppeBearbeiten = gid to it.data } } })
                }
                if (a.ziele.isEmpty()) item(key = "leer-${a.gruppeId}") { Text("Keine Ziele in dieser Gruppe.", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) }
                items(a.ziele, key = { it.id }) { z ->
                    Zielzeile(
                        modell, stand, z.id,
                        gewaehlt = if (auswahlModus) z.id in auswahl else null,
                        oeffnen = { if (auswahlModus) auswahl = if (z.id in auswahl) auswahl - z.id else auswahl + z.id else offen = z.id },
                        langDruecken = { auswahl = auswahl + z.id },
                    )
                }
            }
            if (stand.ziele.isEmpty()) item { Text("Noch keine Ziele. Über „+“ auf der Karte anlegen.", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(20.dp)) }
            else if (suche.isNotBlank() && Zielverzeichnis.abschnitte(stand, suche).isEmpty()) item { Text("Kein Ziel passt zu „$suche“.", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(20.dp)) }
        }
    }
    gruppeBearbeiten?.let { (gid, g) ->
        GruppeBearbeiten(gid != null, g, abbrechen = { gruppeBearbeiten = null }, loeschen = gid?.let { id -> {
            for ((zid, z) in Zielverzeichnis.gruppeLoesen(stand, id)) modell.lage.setzen(Art.Ziel, zid, z)
            modell.lage.loeschen(Art.Zielgruppe, id)
            gruppeBearbeiten = null
        } }) { neu ->
            val id = gid ?: Lage.neueId()
            modell.lage.setzen(Art.Zielgruppe, id, neu)
            if (gid == null && auswahl.isNotEmpty()) {
                for ((zid, z) in Zielverzeichnis.zuordnen(stand, auswahl.toList(), id)) modell.lage.setzen(Art.Ziel, zid, z)
                auswahl = emptySet()
            }
            gruppeBearbeiten = null
        }
    }
}

/** Gruppe anlegen bzw. bearbeiten: Name, Farbe, Löschen (die Ziele bleiben, ohne Gruppe). */
@Composable
private fun GruppeBearbeiten(vorhanden: Boolean, g: de.nglab.sentinel.kern.modell.Zielgruppe, abbrechen: () -> Unit, loeschen: (() -> Unit)?, sichern: (de.nglab.sentinel.kern.modell.Zielgruppe) -> Unit) {
    var name by remember { mutableStateOf(g.name) }
    var farbe by remember { mutableStateOf(g.farbe) }
    AlertDialog(
        onDismissRequest = abbrechen,
        title = { Text(if (vorhanden) "Gruppe bearbeiten" else "Neue Gruppe") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (f in Zielgruppen.farben) {
                        Box(
                            Modifier.size(28.dp).background(hexFarbe(f), CircleShape)
                                .then(if (f == farbe) Modifier.border(3.dp, MaterialTheme.colorScheme.onSurface, CircleShape) else Modifier)
                                .clickable { farbe = f },
                        )
                    }
                }
                loeschen?.let { TextButton(onClick = it) { Text("Gruppe löschen", color = MaterialTheme.colorScheme.error) } }
            }
        },
        confirmButton = { TextButton(onClick = { sichern(Zielgruppen.aendern(g, name, farbe)) }, enabled = Zielgruppen.gueltig(name)) { Text(if (vorhanden) "Sichern" else "Anlegen") } },
        dismissButton = { TextButton(onClick = abbrechen) { Text("Abbrechen") } },
    )
}

@Composable
private fun Abschnittskopf(titel: String, farbe: Color?, bearbeiten: (() -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 4.dp, top = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        farbe?.let { Box(Modifier.size(10.dp).background(it, CircleShape)) }
        Text(titel, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.weight(1f).padding(vertical = 10.dp))
        bearbeiten?.let { IconButton(onClick = it) { Icon(Icons.Filled.Edit, "Gruppe bearbeiten", tint = MaterialTheme.colorScheme.onSurfaceVariant) } }
    }
}

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun Zielzeile(modell: AppModell, stand: LageStand, id: String, gewaehlt: Boolean? = null, oeffnen: () -> Unit, langDruecken: () -> Unit = {}) {
    val info = Kurzinfo.fuer(stand, KartenObjekt(Objektart.Ziel, id), System.currentTimeMillis(), null) ?: return
    val sichtbar = stand.zielEingeblendet(id)
    ListItem(
        headlineContent = { Text(info.titel) },
        supportingContent = { Text(info.zeilen.firstOrNull { it.titel == "Stand" }?.wert ?: info.untertitel, maxLines = 1) },
        leadingContent = {
            val foto = stand.ziele[id]?.data?.let { de.nglab.sentinel.kern.lage.Anhaenge.titelfoto(it) }
            if (foto != null) ServerBild(modell, foto, Modifier.size(36.dp), rund = 18.dp)
            else Box(Modifier.size(36.dp).background(hexFarbe(info.farbe).copy(alpha = if (sichtbar) 1f else 0.35f), CircleShape), contentAlignment = Alignment.Center) {
                Icon(info.symbol.bild(), null, tint = Color.White, modifier = Modifier.size(20.dp))
            }
        },
        trailingContent = gewaehlt?.let { g -> { androidx.compose.material3.Checkbox(checked = g, onCheckedChange = { oeffnen() }) } },
        modifier = Modifier.combinedClickable(onClick = oeffnen, onLongClick = langDruecken).testTag("Ziel ${info.titel}"),
    )
}

/**
 * Zielansicht: alle Angaben eines Ziels, Standortquelle, Unterwegs (Personen), Gruppe, Beziehungen, Sichtbarkeit.
 * Felder und Regeln kommen aus dem Kern (gleich wie auf iOS). Änderungen gelten erst mit „Sichern“.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Zielansicht(modell: AppModell, stand: LageStand, id: String, zurueck: () -> Unit, aufKarte: () -> Unit, standortSetzen: (() -> Unit)? = null, oeffnen: ((String) -> Unit)? = null) {
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
            de.nglab.sentinel.kern.lage.Anhaenge.titelfoto(z)?.let { ServerBild(modell, it, Modifier.fillMaxWidth().height(220.dp)) }

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
                if (Zieleditor.mitVorschlaegen(f.schluessel)) {
                    AnschriftFeld(modell, f.titel, z.anschrift, aendern = { z = Zieleditor.setzen(z, f.schluessel, it) }) { t -> z = Zieleditor.anschriftUebernehmen(z, t, System.currentTimeMillis()) }
                    continue
                }
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

            // Fotos und Dateien: sofort wirksam
            Abschnittstitel("Fotos und Dateien")
            AnhaengeAbschnitt(modell, z) { aenderung ->
                stand.ziele[id]?.data?.let { modell.lage.setzen(Art.Ziel, id, aenderung(it)) }
                z = aenderung(z)
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

            // Aufzeichnung: sofort wirksam
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("Standort aufzeichnen")
                    Text("Für den Verlauf", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Switch(checked = v.data.aufzeichnung, onCheckedChange = { an ->
                    modell.lage.setzen(Art.Ziel, id, Zieleditor.mitAufzeichnung(v.data, an))
                    z = Zieleditor.mitAufzeichnung(z, an)
                })
            }

            // Insassen (Zielfahrzeug, Zielobjekt)
            val insassen = Zielverzeichnis.insassen(stand, id)
            if (z.art != de.nglab.sentinel.kern.modell.Zielart.Person) {
                Abschnittstitel(if (z.art == de.nglab.sentinel.kern.modell.Zielart.Fahrzeug) "Insassen" else "Im Gebäude")
                if (insassen.isEmpty()) Text("Niemand bekannt.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                for (p in insassen) ListItem(
                    headlineContent = { Text(p.data.anzeigename) },
                    modifier = if (oeffnen != null) Modifier.clickable { oeffnen(p.id) } else Modifier,
                )
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

/** Anschrift mit Vorschlägen aus der Ortssuche; ein Vorschlag übernimmt die Anschrift und setzt den Standort. */
@Composable
private fun AnschriftFeld(modell: AppModell, titel: String, wert: String, aendern: (String) -> Unit, waehlen: (de.nglab.sentinel.kern.netz.Suchtreffer) -> Unit) {
    var tippt by remember { mutableStateOf(false) }
    var vorschlaege by remember { mutableStateOf(emptyList<de.nglab.sentinel.kern.netz.Suchtreffer>()) }
    androidx.compose.runtime.LaunchedEffect(wert, tippt) {
        if (!tippt || wert.trim().length < 3) { vorschlaege = emptyList(); return@LaunchedEffect }
        kotlinx.coroutines.delay(300)
        vorschlaege = runCatching { modell.api?.suche(wert, null) ?: emptyList() }.getOrDefault(emptyList()).filter { it.art != "objekt" }.take(5)
    }
    Column {
        OutlinedTextField(value = wert, onValueChange = { tippt = true; aendern(it) }, label = { Text(titel) }, singleLine = true, modifier = Modifier.fillMaxWidth())
        for (t in vorschlaege) ListItem(
            headlineContent = { Text(t.titel) },
            supportingContent = { if (t.untertitel.isNotBlank()) Text(t.untertitel) },
            leadingContent = { Icon(Icons.Filled.Place, null) },
            modifier = Modifier.clickable { tippt = false; vorschlaege = emptyList(); waehlen(t) },
        )
    }
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
