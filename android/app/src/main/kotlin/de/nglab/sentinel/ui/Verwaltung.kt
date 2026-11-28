package de.nglab.sentinel.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import de.nglab.sentinel.AppModell
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.lage.AppSperre
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import de.nglab.sentinel.kern.lage.Verwaltung
import de.nglab.sentinel.kern.modell.Art
import de.nglab.sentinel.kern.modell.Instanz
import de.nglab.sentinel.kern.modell.Versioniert

/** Mehr-Tab: Hauptmenü, eigenes Profil, Funkkanal und Lage, Version, Abmelden (gleich aufgebaut wie auf iOS). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Mehr(modell: AppModell, stand: LageStand, hauptmenue: () -> Unit) {
    var profil by remember { mutableStateOf(false) }
    var lage by remember { mutableStateOf(false) }
    var abmelden by remember { mutableStateOf(false) }
    val kontext = LocalContext.current
    val version = runCatching { kontext.packageManager.getPackageInfo(kontext.packageName, 0).versionName }.getOrNull() ?: ""
    Column(Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("Mehr") })
        LazyColumn {
            item {
                ListItem(
                    headlineContent = { Text("Hauptmenü") },
                    supportingContent = { Text("Im Dienst · ${stand.aktuelleInstanz?.data?.name ?: "KSOD"}") },
                    modifier = Modifier.clickable(onClick = hauptmenue),
                )
            }
            stand.ich?.let { ich ->
                item {
                    ListItem(
                        headlineContent = { Text("Mein Profil") },
                        supportingContent = { Text(listOf(ich.data.spitzname, ich.data.dienststelle).filter { it.isNotBlank() }.joinToString(" · ")) },
                        modifier = Modifier.clickable { profil = true },
                    )
                }
            }
            item {
                ListItem(
                    headlineContent = { Text("Funkkanal und Lage") },
                    supportingContent = { Text(listOfNotNull(stand.einsatz.funkkanal?.let { "Kanal $it" }, stand.einsatz.titel.ifBlank { null }).joinToString(" · ").ifBlank { "Nicht gesetzt" }) },
                    modifier = Modifier.clickable { lage = true },
                )
            }
            item {
                val an by modell.sperreAn.collectAsStateWithLifecycle()
                val frist by modell.sperreFrist.collectAsStateWithLifecycle()
                ListItem(
                    headlineContent = { Text("App-Sperre") },
                    supportingContent = { Text(if (an) "Fingerabdruck oder Gerätecode · ${AppSperre.fristTitel(frist)}" else "Aus") },
                    trailingContent = { androidx.compose.material3.Switch(checked = an, onCheckedChange = { modell.sperreSetzen(it, frist) }) },
                )
                if (an) Box(Modifier.padding(horizontal = 16.dp)) {
                    Auswahl("Sperren", AppSperre.fristen.map { it.sekunden to it.titel }, frist) { modell.sperreSetzen(true, it) }
                }
            }
            item { HorizontalDivider() }
            item { ListItem(headlineContent = { Text("Version") }, trailingContent = { Text(version) }) }
            item {
                ListItem(headlineContent = { Text("Abmelden", color = MaterialTheme.colorScheme.error) }, modifier = Modifier.clickable { abmelden = true })
            }
        }
    }
    if (profil) stand.ich?.let { ich -> ProfilDialog(modell, ich.id, ich.data) { profil = false } }
    if (lage) LageDialog(modell, stand) { lage = false }
    if (abmelden) {
        AlertDialog(
            onDismissRequest = { abmelden = false },
            title = { Text("Abmelden?") },
            text = { Text("Die Anmeldung und alle Einsatzdaten werden von diesem Gerät entfernt.") },
            confirmButton = { TextButton(onClick = { abmelden = false; modell.abmelden() }) { Text("Abmelden", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { abmelden = false }) { Text("Abbrechen") } },
        )
    }
}

@Composable
private fun ProfilDialog(modell: AppModell, id: String, f: de.nglab.sentinel.kern.modell.Fahnder, schliessen: () -> Unit) {
    var name by remember { mutableStateOf(f.name) }
    var spitzname by remember { mutableStateOf(f.spitzname) }
    var dienststelle by remember { mutableStateOf(f.dienststelle) }
    var telefon by remember { mutableStateOf(f.telefon) }
    val fehlt = Verwaltung.profilFehlt(spitzname)
    AlertDialog(
        onDismissRequest = schliessen,
        title = { Text("Mein Profil") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(spitzname, { spitzname = it }, label = { Text("Spitzname") }, singleLine = true, isError = fehlt != null)
                OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true)
                OutlinedTextField(dienststelle, { dienststelle = it }, label = { Text("Dienststelle") }, singleLine = true)
                OutlinedTextField(telefon, { telefon = it }, label = { Text("Telefon") }, singleLine = true)
                fehlt?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            }
        },
        confirmButton = {
            TextButton(onClick = { modell.lage.setzen(Art.Fahnder, id, Verwaltung.profil(f, name, spitzname, dienststelle, telefon)); schliessen() }, enabled = fehlt == null) { Text("Sichern") }
        },
        dismissButton = { TextButton(onClick = schliessen) { Text("Abbrechen") } },
    )
}

@Composable
private fun LageDialog(modell: AppModell, stand: LageStand, schliessen: () -> Unit) {
    var kanal by remember { mutableStateOf(stand.einsatz.funkkanal ?: "") }
    var titel by remember { mutableStateOf(stand.einsatz.titel) }
    var hinweise by remember { mutableStateOf(stand.einsatz.hinweise) }
    AlertDialog(
        onDismissRequest = schliessen,
        title = { Text("Funkkanal und Lage") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(kanal, { kanal = it }, label = { Text("Funkkanal") }, singleLine = true)
                OutlinedTextField(titel, { titel = it }, label = { Text("Lage") }, singleLine = true)
                OutlinedTextField(hinweise, { hinweise = it }, label = { Text("Hinweise") }, minLines = 3)
            }
        },
        confirmButton = {
            TextButton(onClick = {
                if (kanal.trim() != (stand.einsatz.funkkanal ?: "")) modell.lage.funkkanalSetzen(kanal.trim().ifBlank { null })
                if (titel != stand.einsatz.titel || hinweise != stand.einsatz.hinweise) modell.lage.lageSetzen(titel.trim(), hinweise)
                schliessen()
            }) { Text("Sichern") }
        },
        dismissButton = { TextButton(onClick = schliessen) { Text("Abbrechen") } },
    )
}

/** Hauptmenü außerhalb bzw. oberhalb der Instanzen: öffnen, beitreten, anlegen, umbenennen, löschen; Pakete. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Hauptmenue(modell: AppModell, stand: LageStand, schliessen: () -> Unit) {
    var neu by remember { mutableStateOf<Boolean?>(null) } // true = Paket, false = Instanz
    var umbenennen by remember { mutableStateOf<Versioniert<Instanz>?>(null) }
    var loeschen by remember { mutableStateOf<Versioniert<Instanz>?>(null) }
    Scaffold(topBar = {
        TopAppBar(title = { Text("SENTINEL") }, actions = { if (stand.imDienst) TextButton(onClick = schliessen) { Text("Zur Lage") } })
    }) { innen ->
        LazyColumn(Modifier.fillMaxSize().padding(innen)) {
            item { Kopfzeile("Instanzen") }
            items(stand.eigeneInstanzen, key = { it.id }) { i ->
                InstanzZeile(stand, i, oeffnen = {
                    if (i.id != stand.instanz || !stand.imDienst) modell.lage.instanzWechseln(i.id)
                    schliessen()
                }, umbenennen = { umbenennen = i }, loeschen = { loeschen = i }, verlassen = { modell.lage.instanzVerlassen(i.id) })
            }
            item { OutlinedButton(onClick = { neu = false }, modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp).testTag("Neue Instanz")) { Text("Neue Instanz") } }
            if (stand.andereInstanzen.isNotEmpty()) {
                item { Kopfzeile("Beitreten") }
                items(stand.andereInstanzen, key = { it.id }) { i ->
                    ListItem(
                        headlineContent = { Text(i.data.name) },
                        supportingContent = { Text(Verwaltung.beschreibung(stand, i)) },
                        trailingContent = { OutlinedButton(onClick = { modell.lage.instanzBeitreten(i.id) }) { Text("Beitreten") } },
                    )
                }
            }
            item { Kopfzeile("Pakete") }
            items(stand.pakete, key = { it.id }) { p ->
                var menue by remember { mutableStateOf(false) }
                ListItem(
                    headlineContent = { Text(p.data.name) },
                    supportingContent = { if (p.data.beschreibung.isNotBlank()) Text(p.data.beschreibung) },
                    trailingContent = {
                        Box {
                            IconButton(onClick = { menue = true }) { Icon(Icons.Filled.MoreVert, "Aktionen") }
                            DropdownMenu(expanded = menue, onDismissRequest = { menue = false }) {
                                DropdownMenuItem(text = { Text("Bearbeiten") }, onClick = { menue = false; modell.lage.instanzWechseln(p.id); schliessen() })
                                stand.aktuelleInstanz?.takeIf { !it.data.istPaket }?.let { ziel ->
                                    DropdownMenuItem(text = { Text("In „${ziel.data.name}“ übernehmen") }, onClick = { menue = false; modell.lage.paketUebernehmen(p.id) })
                                }
                                if (Verwaltung.darfBearbeiten(stand, p)) {
                                    DropdownMenuItem(text = { Text("Umbenennen") }, onClick = { menue = false; umbenennen = p })
                                    DropdownMenuItem(text = { Text("Löschen", color = MaterialTheme.colorScheme.error) }, onClick = { menue = false; loeschen = p })
                                }
                            }
                        }
                    },
                )
            }
            item { OutlinedButton(onClick = { neu = true }, modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) { Text("Neues Paket") } }
            item {
                TextButton(onClick = { modell.abmelden() }, modifier = Modifier.fillMaxWidth().padding(16.dp)) { Text("Abmelden", color = MaterialTheme.colorScheme.error) }
            }
        }
    }
    neu?.let { paket ->
        NamenDialog(if (paket) "Neues Paket" else "Neue Instanz", "", "") { name, beschreibung ->
            if (name != null) modell.lage.instanzErstellen(name.trim(), beschreibung.trim(), paket)
            neu = null
        }
    }
    umbenennen?.let { i ->
        NamenDialog("Umbenennen", i.data.name, i.data.beschreibung) { name, beschreibung ->
            if (name != null) modell.lage.instanzBearbeiten(i.id, name.trim(), beschreibung.trim())
            umbenennen = null
        }
    }
    loeschen?.let { i ->
        AlertDialog(
            onDismissRequest = { loeschen = null },
            title = { Text("„${i.data.name}“ löschen?") },
            text = { Text("Alle Inhalte darin werden für alle entfernt.") },
            confirmButton = { TextButton(onClick = { modell.lage.instanzLoeschen(i.id); loeschen = null }) { Text("Löschen", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { loeschen = null }) { Text("Abbrechen") } },
        )
    }
}

@Composable
private fun Kopfzeile(titel: String) {
    Text(titel, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(start = 16.dp, top = 16.dp, bottom = 4.dp))
}

@Composable
private fun InstanzZeile(stand: LageStand, i: Versioniert<Instanz>, oeffnen: () -> Unit, umbenennen: () -> Unit, loeschen: () -> Unit, verlassen: () -> Unit) {
    var menue by remember { mutableStateOf(false) }
    ListItem(
        headlineContent = { Text(i.data.name) },
        supportingContent = { Text(Verwaltung.beschreibung(stand, i)) },
        trailingContent = {
            if (Verwaltung.darfVerlassen(i)) Box {
                IconButton(onClick = { menue = true }) { Icon(Icons.Filled.MoreVert, "Aktionen") }
                DropdownMenu(expanded = menue, onDismissRequest = { menue = false }) {
                    if (Verwaltung.darfBearbeiten(stand, i)) DropdownMenuItem(text = { Text("Umbenennen") }, onClick = { menue = false; umbenennen() })
                    DropdownMenuItem(text = { Text("Verlassen") }, onClick = { menue = false; verlassen() })
                    if (Verwaltung.darfBearbeiten(stand, i)) DropdownMenuItem(text = { Text("Löschen", color = MaterialTheme.colorScheme.error) }, onClick = { menue = false; loeschen() })
                }
            }
        },
        modifier = Modifier.clickable(onClick = oeffnen),
    )
}

/** Name und Beschreibung eingeben; `fertig(null, …)` = abgebrochen. */
@Composable
private fun NamenDialog(titel: String, name0: String, beschreibung0: String, fertig: (String?, String) -> Unit) {
    var name by remember { mutableStateOf(name0) }
    var beschreibung by remember { mutableStateOf(beschreibung0) }
    val fehlt = Verwaltung.nameFehlt(name)
    AlertDialog(
        onDismissRequest = { fertig(null, "") },
        title = { Text(titel) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true)
                OutlinedTextField(beschreibung, { beschreibung = it }, label = { Text("Beschreibung (optional)") })
            }
        },
        confirmButton = { TextButton(onClick = { fertig(name, beschreibung) }, enabled = fehlt == null) { Text("Sichern") } },
        dismissButton = { TextButton(onClick = { fertig(null, "") }) { Text("Abbrechen") } },
    )
}
