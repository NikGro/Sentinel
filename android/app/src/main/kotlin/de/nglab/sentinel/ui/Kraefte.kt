package de.nglab.sentinel.ui

import android.content.Intent
import android.net.Uri
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
    offen?.let { id ->
        if (stand.fahnder[id] != null) {
            Kraftansicht(modell, stand, id, zurueck = { offen = null }) { aufKarte(KartenObjekt(Objektart.Kraft, id)) }
            return
        }
    }
    val jetzt = System.currentTimeMillis()
    Column(Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("Kräfte") })
        LazyColumn {
            item { Kopf("Kräfte") }
            items(Kraefteansicht.sortiert(stand), key = { it.id }) { f ->
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
            if (ich != null && waehlbar.isNotEmpty()) {
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

            if (stand.fahrzeuge.isNotEmpty()) {
                item { Kopf("Fahrzeuge") }
                items(stand.fahrzeugeSortiert, key = { "v-${it.id}" }) { v ->
                    ListItem(
                        headlineContent = { Text(v.data.funkrufname) },
                        supportingContent = { Text(listOf(v.data.kennzeichen, Kraefteansicht.fahrzeugStatus(stand, v)).filter { it.isNotBlank() }.joinToString(" · "), maxLines = 2) },
                        trailingContent = { Switch(checked = stand.imEinsatz(v), onCheckedChange = { modell.lage.fahrzeugImEinsatz(v.id, it) }) },
                        modifier = Modifier.clickable { if (stand.ortung(v) != null) aufKarte(KartenObjekt(Objektart.Fahrzeug, v.id)) },
                    )
                }
            }
        }
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
