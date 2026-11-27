package de.nglab.sentinel.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LocationCity
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SwapCalls
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.unit.dp
import de.nglab.sentinel.AppModell
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.netz.Suchtreffer
import kotlinx.coroutines.delay

/** Was die Suche zurückgibt: ein Ort (Anschrift, Kreuzung, Einrichtung) oder ein Objekt der Lage. */
sealed interface Suchergebnis {
    data class Ort(val treffer: Suchtreffer) : Suchergebnis
    data class Objekt(val objekt: KartenObjekt, val punkt: GeoPunkt?) : Suchergebnis
}

/**
 * Suche wie in einer Navi-App: Objekte der Lage (A-Position zuerst, Kräfte, Ziele, Markierungen) und Orte aus der eigenen
 * Ortssuche (Anschriften, Kreuzungen, Orte, Einrichtungen). Gleicher Aufbau wie auf iOS.
 */
@Composable
fun Suche(modell: AppModell, stand: LageStand, schliessen: () -> Unit, waehlen: (Suchergebnis) -> Unit) {
    var text by remember { mutableStateOf("") }
    var orte by remember { mutableStateOf<List<Suchtreffer>>(emptyList()) }
    var fehler by remember { mutableStateOf<String?>(null) }
    val fokus = remember { FocusRequester() }
    val ort = modell.ort.value?.let { GeoPunkt(it.lat, it.lon) }

    LaunchedEffect(Unit) { fokus.requestFocus() }
    LaunchedEffect(text) {
        orte = emptyList()
        fehler = null
        if (text.trim().length < 2) return@LaunchedEffect
        delay(220)
        runCatching { modell.api?.suche(text, ort) ?: emptyList() }
            .onSuccess { orte = it }
            .onFailure { fehler = it.message }
    }

    val objekte = remember(text, stand) { objektTreffer(stand, text) }

    Column(Modifier.fillMaxSize()) {
        OutlinedTextField(
            value = text,
            onValueChange = { text = it },
            placeholder = { Text("Adresse, Kreuzung, Ort oder Objekt") },
            leadingIcon = { Icon(Icons.Filled.Search, null) },
            trailingIcon = { IconButton(onClick = { if (text.isEmpty()) schliessen() else text = "" }) { Icon(Icons.Filled.Close, "Leeren") } },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().padding(16.dp).focusRequester(fokus),
        )
        LazyColumn(Modifier.fillMaxSize()) {
            if (objekte.isNotEmpty()) {
                item { Text("In der Lage", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) }
                items(objekte, key = { it.first.objekt.schluessel }) { (e, titel) ->
                    ListItem(headlineContent = { Text(titel) }, supportingContent = { Text(artTitel(e.objekt.art)) },
                        leadingContent = { Icon(Icons.Filled.Place, null) }, modifier = Modifier.clickable { waehlen(e) })
                }
                item { HorizontalDivider() }
            }
            items(orte, key = { it.id }) { t ->
                ListItem(
                    headlineContent = { Text(t.titel) },
                    supportingContent = { if (t.untertitel.isNotBlank()) Text(t.untertitel) },
                    leadingContent = {
                        Icon(when (t.art) {
                            "kreuzung" -> Icons.Filled.SwapCalls
                            "adresse" -> Icons.Filled.Home
                            "ort" -> Icons.Filled.LocationCity
                            "poi" -> Icons.Filled.Apartment
                            else -> Icons.Filled.Place
                        }, null)
                    },
                    modifier = Modifier.clickable { waehlen(Suchergebnis.Ort(t)) },
                )
            }
            fehler?.let { item { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp)) } }
        }
    }
}

private fun artTitel(a: Objektart) = when (a) {
    Objektart.Kraft -> "Fahnder"
    Objektart.Fahrzeug -> "Fahrzeug"
    Objektart.Ziel -> "Ziel"
    else -> "Markierung"
}

/** Objekte der Lage, die zur Eingabe passen; die A-Position steht immer oben. */
private fun objektTreffer(stand: LageStand, text: String): List<Pair<Suchergebnis.Objekt, String>> {
    val t = text.trim().lowercase()
    val jetzt = System.currentTimeMillis()
    val ergebnis = ArrayList<Pair<Suchergebnis.Objekt, String>>()
    stand.aHalter?.let { a ->
        if (t.isEmpty() || "a-position".contains(t) || a.data.spitzname.lowercase().contains(t)) {
            ergebnis += Suchergebnis.Objekt(KartenObjekt(Objektart.Kraft, a.id), stand.positionen[a.id]?.punkt) to "A-Position (${a.data.spitzname})"
        }
    }
    if (t.isEmpty()) return ergebnis
    for (f in stand.aktiveKraefte) if (f.id != stand.einsatz.a?.memberId && f.data.spitzname.lowercase().contains(t)) {
        ergebnis += Suchergebnis.Objekt(KartenObjekt(Objektart.Kraft, f.id), stand.positionen[f.id]?.punkt) to f.data.spitzname
    }
    for (z in stand.zieleSortiert) if (z.data.anzeigename.lowercase().contains(t) || z.data.kennzeichen.lowercase().contains(t)) {
        ergebnis += Suchergebnis.Objekt(KartenObjekt(Objektart.Ziel, z.id), stand.ortung(z, jetzt, 0)?.punkt) to z.data.anzeigename
    }
    for (m in stand.sichtbareMarkierungen(jetzt, emptySet())) if (m.data.titel.isNotBlank() && m.data.titel.lowercase().contains(t)) {
        ergebnis += Suchergebnis.Objekt(KartenObjekt(Objektart.Markierung, m.id), m.data.anker) to m.data.titel
    }
    return ergebnis.take(8)
}
