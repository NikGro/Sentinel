package de.nglab.sentinel.ui

import androidx.compose.runtime.collectAsState
import androidx.compose.foundation.clickable
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.nglab.sentinel.AppModell
import de.nglab.sentinel.R
import de.nglab.sentinel.kern.modell.Art
import de.nglab.sentinel.kern.modell.Fahnder
import kotlinx.coroutines.launch

/** Erste Einrichtung: Server und Zugangscode. Das Profil folgt nach erfolgreicher Anmeldung. */
@Composable
fun Einrichtung(modell: AppModell) {
    var server by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var fehler by remember { mutableStateOf<String?>(null) }
    var laeuft by remember { mutableStateOf(false) }
    val bereich = rememberCoroutineScope()
    Scaffold { innen ->
        Column(
            Modifier.fillMaxSize().padding(innen).imePadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Spacer(Modifier.height(48.dp))
            Image(painterResource(R.drawable.ic_schild), contentDescription = null, modifier = Modifier.size(96.dp))
            Text("SENTINEL", fontSize = 32.sp, fontWeight = FontWeight.Bold, letterSpacing = 4.sp)
            Text("Gemeinsame Lagekarte für Observation und Fahndung", style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(server, { server = it }, label = { Text("Serveradresse") }, singleLine = true, modifier = Modifier.fillMaxWidth().testTag("Serveradresse"),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri))
            OutlinedTextField(code, { code = it }, label = { Text("Zugangscode") }, singleLine = true, modifier = Modifier.fillMaxWidth().testTag("Zugangscode"))
            fehler?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium) }
            Button(
                onClick = {
                    laeuft = true
                    fehler = null
                    bereich.launch {
                        runCatching { modell.anmelden(server, code) }.onFailure { fehler = it.message ?: "Anmeldung fehlgeschlagen." }
                        laeuft = false
                    }
                },
                enabled = !laeuft && server.isNotBlank() && code.length >= 4,
                modifier = Modifier.fillMaxWidth().height(52.dp),
            ) {
                if (laeuft) CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp) else Text("Anmelden")
            }
        }
    }
}

/** Verbindungsaufbau; nach einer Weile kann man sich abmelden (z. B. falscher Server). */
@Composable
fun Verbinde(modell: AppModell) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
            CircularProgressIndicator()
            Text("Verbinde mit dem Server …", style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = { modell.abmelden() }) { Text("Abmelden") }
        }
    }
}

/** Eigenes Profil anlegen (Name, Spitzname, Dienststelle, Handynummer). */
@Composable
fun ProfilAnlegen(modell: AppModell) {
    var name by remember { mutableStateOf("") }
    var spitzname by remember { mutableStateOf("") }
    var dienststelle by remember { mutableStateOf("") }
    var telefon by remember { mutableStateOf("") }
    Scaffold { innen ->
        Column(
            Modifier.fillMaxSize().padding(innen).imePadding().verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Profil anlegen", style = MaterialTheme.typography.headlineMedium)
            Text("So sehen dich die anderen auf der Karte und in der Kräfteliste.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(spitzname, { spitzname = it }, label = { Text("Spitzname") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(dienststelle, { dienststelle = it }, label = { Text("Dienststelle") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(telefon, { telefon = it.filter { c -> c.isDigit() || c in "+ ()/-" } }, label = { Text("Handynummer") }, singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone), modifier = Modifier.fillMaxWidth())
            Button(
                onClick = {
                    val id = modell.zugang.value?.geraetId ?: return@Button
                    modell.lage.setzen(Art.Fahnder, id, Fahnder(name.trim(), spitzname.trim(), dienststelle.trim(), telefon.trim()))
                },
                enabled = name.isNotBlank() && spitzname.isNotBlank() && dienststelle.isNotBlank(),
                modifier = Modifier.fillMaxWidth().height(52.dp),
            ) { Text("Sichern") }
            // Bestehendes Profil übernehmen (etwa nach einem Gerätewechsel)
            val stand by modell.lage.stand.collectAsState()
            val uebernehmbar = de.nglab.sentinel.kern.lage.Kraefteansicht.uebernehmbar(stand)
            var uebernahme by remember { mutableStateOf<de.nglab.sentinel.kern.modell.Versioniert<Fahnder>?>(null) }
            var fehler by remember { mutableStateOf<String?>(null) }
            val bereich = rememberCoroutineScope()
            if (uebernehmbar.isNotEmpty()) {
                Text("Oder ein bestehendes Profil übernehmen", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 12.dp))
                for (f in uebernehmbar) {
                    androidx.compose.material3.ListItem(
                        headlineContent = { Text(f.data.spitzname) },
                        supportingContent = { Text(listOf(f.data.name, f.data.dienststelle).filter { it.isNotBlank() }.joinToString(", ")) },
                        modifier = Modifier.clickable { uebernahme = f },
                    )
                }
                fehler?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            }
            TextButton(onClick = { modell.abmelden() }, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text("Abmelden") }
            uebernahme?.let { f ->
                androidx.compose.material3.AlertDialog(
                    onDismissRequest = { uebernahme = null },
                    title = { Text("Profil übernehmen?") },
                    text = { Text("Dieses Gerät wird „${f.data.spitzname}“. Das alte Gerät wird abgemeldet.") },
                    confirmButton = { TextButton(onClick = {
                        uebernahme = null
                        fehler = null
                        bereich.launch { runCatching { modell.api?.profilUebernehmen(f.id) }.onFailure { fehler = it.message ?: "Übernehmen fehlgeschlagen." } }
                    }) { Text("Übernehmen") } },
                    dismissButton = { TextButton(onClick = { uebernahme = null }) { Text("Abbrechen") } },
                )
            }
        }
    }
}
