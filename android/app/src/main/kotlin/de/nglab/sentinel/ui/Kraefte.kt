package de.nglab.sentinel.ui

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.TextButton
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.text.input.KeyboardCapitalization
import de.nglab.sentinel.kern.lage.Fahrzeugeditor
import de.nglab.sentinel.kern.lage.Kraeftesuche
import de.nglab.sentinel.kern.lage.Lage
import de.nglab.sentinel.kern.modell.Art
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import de.nglab.sentinel.AppModell
import de.nglab.sentinel.karte.bild
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.lage.Kraefteansicht
import de.nglab.sentinel.kern.lage.Kurzinfo
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.Fortbewegung

/** Kräfte-Tab: Kräfte, eigenes Fahrzeug, Fahrzeuge der Lage (gleich aufgebaut wie auf iOS). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Kraefteliste(modell: AppModell, stand: LageStand, aufKarte: (KartenObjekt) -> Unit) {
    var offen by rememberSaveable { mutableStateOf<String?>(null) }
    var fahrzeug by rememberSaveable { mutableStateOf<String?>(null) }
    var suche by rememberSaveable { mutableStateOf("") }
    offen?.let { id ->
        if (stand.fahnder[id] != null) {
            Kraftansicht(modell, stand, id, zurueck = { offen = null }) { aufKarte(KartenObjekt(Objektart.Kraft, id)) }
            return
        }
    }
    fahrzeug?.let { id ->
        if (id == NEU || stand.fahrzeuge[id] != null) {
            Fahrzeugansicht(modell, stand, id.takeIf { it != NEU }, zurueck = { fahrzeug = null }) { aufKarte(KartenObjekt(Objektart.Fahrzeug, id)) }
            return
        }
    }
    val jetzt = System.currentTimeMillis()
    val kraefte = Kraeftesuche.kraefte(stand, suche)
    val fahrzeuge = Kraeftesuche.fahrzeuge(stand, suche)
    Column(Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("Kräfte") }, actions = { TextButton(onClick = { fahrzeug = NEU }) { Text("Neues Fahrzeug") } })
        OutlinedTextField(
            value = suche, onValueChange = { suche = it },
            placeholder = { Text("Kräfte und Fahrzeuge durchsuchen") },
            leadingIcon = { Icon(Icons.Filled.Search, null) },
            trailingIcon = { if (suche.isNotEmpty()) IconButton(onClick = { suche = "" }) { Icon(Icons.Filled.Close, "Leeren") } },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
        )
        LazyColumn {
            if (suche.isNotBlank() && kraefte.isEmpty() && fahrzeuge.isEmpty()) item { Text("Nichts passt zu „$suche“.", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(20.dp)) }
            if (kraefte.isNotEmpty()) item { Kopf("Kräfte") }
            items(kraefte, key = { it.id }) { f ->
                val info = Kurzinfo.fuer(stand, KartenObjekt(Objektart.Kraft, f.id), jetzt, null)
                ListItem(
                    headlineContent = { Text(f.data.spitzname + if (f.id == stand.ichId) " (ich)" else "") },
                    supportingContent = { Text(Kraefteansicht.status(stand, f, jetzt), maxLines = 1) },
                    leadingContent = {
                        Box(Modifier.size(36.dp).background(hexFarbe(info?.farbe ?: "#5E5CE6").copy(alpha = if (f.data.aktiv) 1f else 0.35f), CircleShape), contentAlignment = Alignment.Center) {
                            info?.let { Icon(it.symbol.bild(), null, tint = Color.White, modifier = Modifier.size(20.dp)) }
                        }
                    },
                    trailingContent = { if (stand.istOnline(f.id)) Box(Modifier.size(10.dp).background(Color(0xFF34C759), CircleShape)) },
                    modifier = Modifier.clickable { offen = f.id }.testTag("Kraft ${f.data.spitzname}"),
                )
            }

            // Eigenes Fahrzeug: Einsteigen setzt die Fortbewegung auf „Fahrzeug“.
            val ich = stand.ich
            val waehlbar = Kraefteansicht.waehlbareFahrzeuge(stand)
            if (ich != null && waehlbar.isNotEmpty() && suche.isBlank()) {
                item { Kopf("Mein Fahrzeug") }
                item {
                    val aktuell = if (ich.data.fortbewegung == Fortbewegung.Fahrzeug) ich.data.fahrzeugId else null
                    Box(Modifier.padding(horizontal = 16.dp)) {
                        Auswahl("Fahrzeug", listOf<Pair<String?, String>>(null to "Kein Fahrzeug") + waehlbar.map { it.id to it.data.funkrufname }, aktuell) { id ->
                            if (id == null) modell.lage.fortbewegungSetzen(Fortbewegung.Fuss) else modell.lage.fortbewegungSetzen(Fortbewegung.Fahrzeug, id)
                        }
                    }
                }
            }

            if (fahrzeuge.isNotEmpty()) {
                item { Kopf("Fahrzeuge") }
                items(fahrzeuge, key = { "v-${it.id}" }) { v ->
                    ListItem(
                        headlineContent = { Text(v.data.funkrufname) },
                        supportingContent = { Text(listOf(v.data.kennzeichen, Kraefteansicht.fahrzeugStatus(stand, v)).filter { it.isNotBlank() }.joinToString(" · "), maxLines = 2) },
                        trailingContent = { Switch(checked = stand.imEinsatz(v), onCheckedChange = { modell.lage.fahrzeugImEinsatz(v.id, it) }) },
                        leadingContent = { v.data.fotoBlob?.let { ServerBild(modell, it, Modifier.size(36.dp), rund = 18.dp) } },
                        modifier = Modifier.clickable { fahrzeug = v.id }.testTag("Fahrzeug ${v.data.funkrufname}"),
                    )
                }
            }
        }
    }
}

private const val NEU = "\u0000neu"

/**
 * Fahrzeug der Flotte anlegen bzw. bearbeiten: Funkrufname, Kennzeichen, Bezeichnung, Foto, Tracker, Aufzeichnung.
 * Felder und Regeln aus dem Kern (gleich wie auf iOS); Änderungen gelten mit „Sichern“.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Fahrzeugansicht(modell: AppModell, stand: LageStand, id: String?, zurueck: () -> Unit, aufKarte: () -> Unit) {
    val vorhanden = id?.let { stand.fahrzeuge[it] }
    var v by remember(id) { mutableStateOf(vorhanden?.data ?: Fahrzeugeditor.neu()) }
    val geaendert = v != (vorhanden?.data ?: Fahrzeugeditor.neu())
    val fehlt = Fahrzeugeditor.fehlt(v)
    var loeschen by remember { mutableStateOf(false) }
    val kontext = LocalContext.current
    val bereich = rememberCoroutineScope()
    var laedt by remember { mutableStateOf(false) }
    val fotoWaehlen = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        val api = modell.api
        if (uri == null || api == null) return@rememberLauncherForActivityResult
        laedt = true
        bereich.launch {
            runCatching {
                val daten = withContext(Dispatchers.IO) { Bildspeicher.verkleinern(kontext, uri) } ?: error("Foto")
                api.hochladen(daten, "image/jpeg").id
            }.onSuccess { blob -> v = Fahrzeugeditor.mitFoto(v, blob) }
            laedt = false
        }
    }
    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(vorhanden?.data?.funkrufname ?: "Neues Fahrzeug", maxLines = 1) },
            navigationIcon = { IconButton(onClick = zurueck) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Zurück") } },
            actions = {
                Button(
                    onClick = {
                        modell.lage.setzen(Art.Fahrzeug, id ?: Lage.neueId(), Fahrzeugeditor.fertig(v))
                        if (id == null) zurueck()
                    },
                    enabled = geaendert && fehlt == null,
                    modifier = Modifier.padding(end = 8.dp).testTag("Sichern"),
                ) { Text(if (id == null) "Anlegen" else "Sichern") }
            },
        )
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            v.fotoBlob?.let { ServerBild(modell, it, Modifier.fillMaxWidth().height(200.dp)) }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedButton(onClick = { fotoWaehlen.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }, enabled = !laedt) { Text(if (v.fotoBlob == null) "Foto hinzufügen" else "Foto ändern") }
                if (v.fotoBlob != null) TextButton(onClick = { v = Fahrzeugeditor.mitFoto(v, null) }) { Text("Foto entfernen") }
                if (laedt) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
            }
            for (f in Fahrzeugeditor.felder()) {
                OutlinedTextField(
                    value = Fahrzeugeditor.wert(v, f.schluessel),
                    onValueChange = { v = Fahrzeugeditor.setzen(v, f.schluessel, it) },
                    label = { Text(f.titel) },
                    placeholder = { if (f.hinweis.isNotBlank()) Text(f.hinweis) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = if (f.grossbuchstaben) KeyboardCapitalization.Characters else KeyboardCapitalization.Sentences),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            val tracker = stand.tracker.values.sortedBy { it.data.name }
            if (tracker.isNotEmpty()) {
                Auswahl("Tracker", listOf<Pair<String?, String>>(null to "Kein Tracker") + tracker.map { it.id to it.data.name }, v.trackerId) { t -> v = Fahrzeugeditor.mitTracker(v, t) }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("Standort aufzeichnen")
                    Text("Für den Verlauf", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Switch(checked = v.aufzeichnung, onCheckedChange = { v = Fahrzeugeditor.mitAufzeichnung(v, it) })
            }
            if (vorhanden != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Im Einsatz", modifier = Modifier.weight(1f))
                    Switch(checked = stand.imEinsatz(vorhanden), onCheckedChange = { modell.lage.fahrzeugImEinsatz(vorhanden.id, it) })
                }
                Text(Kraefteansicht.fahrzeugStatus(stand, vorhanden), color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (stand.ortung(vorhanden) != null) OutlinedButton(onClick = aufKarte) { Text("Auf der Karte") }
                HorizontalDivider()
                OutlinedButton(onClick = { loeschen = true }, modifier = Modifier.fillMaxWidth()) { Text("Fahrzeug löschen", color = MaterialTheme.colorScheme.error) }
            }
        }
    }
    if (loeschen && id != null) {
        AlertDialog(
            onDismissRequest = { loeschen = false },
            title = { Text("Fahrzeug löschen?") },
            text = { Text("„${v.funkrufname}“ wird aus der Flotte entfernt.") },
            confirmButton = { TextButton(onClick = { modell.lage.loeschen(Art.Fahrzeug, id); loeschen = false; zurueck() }) { Text("Löschen", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { loeschen = false }) { Text("Abbrechen") } },
        )
    }
}

@Composable
private fun Kopf(titel: String) {
    Text(titel, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp))
}

/** Kraftansicht: Kurzinfo aus dem Kern, Anrufen, auf der Karte zeigen. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Kraftansicht(modell: AppModell, stand: LageStand, id: String, zurueck: () -> Unit, aufKarte: () -> Unit) {
    val kontext = LocalContext.current
    val info = Kurzinfo.fuer(stand, KartenObjekt(Objektart.Kraft, id), System.currentTimeMillis(), modell.ort.value?.let { de.nglab.sentinel.kern.modell.GeoPunkt(it.lat, it.lon) }) ?: return
    Column(Modifier.fillMaxSize()) {
        TopAppBar(title = { Text(info.titel) }, navigationIcon = { IconButton(onClick = zurueck) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Zurück") } })
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (info.untertitel.isNotBlank()) Text(info.untertitel, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (info.ort != null) Button(onClick = aufKarte, modifier = Modifier.weight(1f)) { Text("Auf der Karte") }
                info.telefon?.let { t ->
                    OutlinedButton(onClick = { kontext.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$t"))) }, modifier = Modifier.weight(1f)) { Text("Anrufen") }
                }
            }
            for (z in info.zeilen) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(z.titel, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(0.4f))
                    Text(z.wert, modifier = Modifier.weight(0.6f))
                }
            }
            info.telefon?.let { Text("Telefon: $it", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}
