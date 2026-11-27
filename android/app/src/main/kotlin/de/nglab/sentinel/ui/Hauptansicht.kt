package de.nglab.sentinel.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.PersonSearch
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Traffic
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import de.nglab.sentinel.AppModell
import de.nglab.sentinel.karte.KartenSteuerung
import de.nglab.sentinel.karte.LageKarte
import de.nglab.sentinel.kern.karte.Anheftung
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.Fortbewegung

private enum class Tab(val titel: String, val bild: ImageVector) {
    Lage("Lage", Icons.Filled.Map), Ziele("Ziele", Icons.Filled.PersonSearch), Kraefte("Kräfte", Icons.Filled.Groups), Mehr("Mehr", Icons.Filled.MoreHoriz)
}

/** Außer Dienst nur das Hauptmenü (Instanzen); im Dienst die Tabs Lage, Ziele, Kräfte und Mehr. */
@Composable
fun Hauptansicht(modell: AppModell) {
    val stand by modell.lage.stand.collectAsStateWithLifecycle()
    var hauptmenue by rememberSaveable { mutableStateOf(false) }
    if (!stand.imDienst || hauptmenue) {
        Hauptmenue(modell, stand) { hauptmenue = false }
        return
    }
    var tab by rememberSaveable { mutableStateOf(Tab.Lage) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                for (t in Tab.entries) {
                    NavigationBarItem(selected = tab == t, onClick = { tab = t }, icon = { Icon(t.bild, null) }, label = { Text(t.titel) })
                }
            }
        },
        contentWindowInsets = WindowInsets(0),
    ) { innen ->
        Box(Modifier.fillMaxSize().padding(innen)) {
            when (tab) {
                Tab.Lage -> Lagebildschirm(modell, stand)
                Tab.Ziele -> Zielliste(stand)
                Tab.Kraefte -> Kraefteliste(stand)
                Tab.Mehr -> Mehr(modell) { hauptmenue = true }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Lagebildschirm(modell: AppModell, stand: LageStand) {
    val steuerung = remember { KartenSteuerung() }
    var auswahl by remember { mutableStateOf<KartenObjekt?>(null) }
    var verkehr by rememberSaveable { mutableStateOf(false) }
    Box(Modifier.fillMaxSize()) {
        LageKarte(modell, steuerung, Modifier.fillMaxSize().testTag("Lagekarte")) { auswahl = it }

        // Oben: Suchleiste
        Surface(
            shape = RoundedCornerShape(28.dp),
            tonalElevation = 3.dp,
            shadowElevation = 4.dp,
            modifier = Modifier.statusBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth().height(52.dp),
        ) {
            Row(Modifier.padding(horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Icons.Filled.Search, null)
                Text("Suchen oder navigieren", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        // Rechts: SOS, Kompass, Verkehr, Hinzufügen
        Column(
            Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(top = 72.dp, end = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            horizontalAlignment = Alignment.End,
        ) {
            SosKnopf(stand.eigenerNotruf) { if (stand.eigenerNotruf) modell.lage.notrufBeenden() else modell.lage.notrufAusloesen() }
            // Standort und Kompass in einem Knopf: heftet an (Fahrtrichtung), erneut Norden oben.
            val ort by modell.ort.collectAsStateWithLifecycle()
            Kartenknopf(
                when (steuerung.anheftung) {
                    Anheftung.Frei -> Icons.Filled.NearMe
                    Anheftung.Norden -> Icons.Filled.Explore
                    else -> Icons.Filled.Navigation
                },
                "Standort und Kompass",
                aktiv = steuerung.anheftung != Anheftung.Frei,
            ) { steuerung.anheftenUmschalten(ort?.let { GeoPunkt(it.lat, it.lon) }) }
            Kartenknopf(Icons.Filled.Traffic, "Verkehr", aktiv = verkehr) { verkehr = !verkehr; steuerung.verkehr(verkehr) }
            Kartenknopf(Icons.Filled.Add, "Hinzufügen", hervorgehoben = true) {}
        }

        // Unten: A-Position und Fortbewegung, darüber die Lageleiste
        Column(
            Modifier.align(Alignment.BottomCenter).padding(horizontal = 16.dp, vertical = 12.dp).fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                AKnopf(stand, Modifier.weight(1f)) { if (stand.haeltA) modell.lage.aFreigeben() else modell.lage.aUebernehmen() }
                Fortbewegungswahl(stand.ich?.data?.fortbewegung ?: Fortbewegung.Fuss, Modifier.weight(1.2f)) { modell.lage.fortbewegungSetzen(it) }
            }
            Lageleiste(stand)
        }
    }

    auswahl?.let { a ->
        ModalBottomSheet(onDismissRequest = { auswahl = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)) {
            Kurzuebersicht(stand, a)
        }
    }
}

@Composable
private fun Kartenknopf(bild: ImageVector, beschreibung: String, aktiv: Boolean = false, hervorgehoben: Boolean = false, aktion: () -> Unit) {
    FilledTonalIconButton(
        onClick = aktion,
        modifier = Modifier.size(48.dp),
        colors = if (hervorgehoben || aktiv) IconButtonDefaults.filledTonalIconButtonColors(containerColor = MaterialTheme.colorScheme.primary, contentColor = Color.White)
        else IconButtonDefaults.filledTonalIconButtonColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
    ) { Icon(bild, beschreibung) }
}

/** Notrufknopf: kurz antippen löst noch nicht aus, erst ein langer Druck (wie auf iOS 1,5 s). */
@Composable
private fun SosKnopf(eigenerNotruf: Boolean, aktion: () -> Unit) {
    Surface(
        color = SentinelFarben.aPosition,
        contentColor = Color.White,
        shape = CircleShape,
        shadowElevation = 4.dp,
        modifier = Modifier.size(48.dp).clickable(onClickLabel = if (eigenerNotruf) "Notruf beenden" else "Notruf auslösen", onClick = aktion),
    ) {
        Box(contentAlignment = Alignment.Center) { Text(if (eigenerNotruf) "Ende" else "SOS", fontWeight = FontWeight.Bold) }
    }
}

@Composable
private fun AKnopf(stand: LageStand, modifier: Modifier, aktion: () -> Unit) {
    val text = when {
        stand.haeltA -> "A abgeben"
        stand.aHalter != null -> "A: ${stand.aHalter?.data?.spitzname}"
        else -> "A übernehmen"
    }
    Button(
        onClick = aktion,
        modifier = modifier.height(48.dp),
        colors = ButtonDefaults.buttonColors(containerColor = if (stand.haeltA) SentinelFarben.aPosition else MaterialTheme.colorScheme.surfaceContainerHigh,
            contentColor = if (stand.haeltA) Color.White else MaterialTheme.colorScheme.onSurface),
    ) { Text(text, maxLines = 1) }
}

@Composable
private fun Fortbewegungswahl(aktuell: Fortbewegung, modifier: Modifier, waehlen: (Fortbewegung) -> Unit) {
    val optionen = listOf(Fortbewegung.Fuss to Icons.Filled.DirectionsWalk, Fortbewegung.Fahrzeug to Icons.Filled.DirectionsCar, Fortbewegung.Oepnv to Icons.Filled.Tram)
    SingleChoiceSegmentedButtonRow(modifier.height(48.dp)) {
        optionen.forEachIndexed { i, (art, bild) ->
            SegmentedButton(
                selected = aktuell == art,
                onClick = { waehlen(art) },
                shape = SegmentedButtonDefaults.itemShape(i, optionen.size),
                icon = {},
                label = { Icon(bild, art.name) },
            )
        }
    }
}

@Composable
private fun Lageleiste(stand: LageStand) {
    Surface(shape = RoundedCornerShape(24.dp), tonalElevation = 3.dp, shadowElevation = 3.dp, modifier = Modifier.fillMaxWidth().height(48.dp)) {
        Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stand.einsatz.funkkanal?.let { "Kanal $it" } ?: "Kein Kanal", fontWeight = FontWeight.SemiBold)
            Text(stand.aktuelleInstanz?.data?.name ?: "", color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, modifier = Modifier.weight(1f))
            stand.aHalter?.let { Text("A: ${it.data.spitzname}", color = SentinelFarben.aPosition, fontWeight = FontWeight.SemiBold) }
        }
    }
}

/** Kurzübersicht eines angetippten Objekts (Kopfzeile wie auf iOS: Symbol, Titel, Untertitel). */
@Composable
private fun Kurzuebersicht(stand: LageStand, a: KartenObjekt) {
    val (titel, untertitel, farbe) = when (a.art) {
        Objektart.Kraft -> stand.fahnder[a.id]?.data.let { Triple(it?.spitzname ?: "Fahnder", it?.let(stand::fortbewegungText) ?: "", SentinelFarben.kraefte) }
        Objektart.Fahrzeug -> stand.fahrzeuge[a.id]?.data.let { Triple(it?.funkrufname ?: "Fahrzeug", it?.zusatz ?: "", SentinelFarben.kraefte) }
        Objektart.Ziel -> stand.ziele[a.id]?.data.let { Triple(it?.anzeigename ?: "Ziel", it?.zweiteZeile ?: "", SentinelFarben.ziele) }
        else -> stand.markierungen[a.id]?.data.let { Triple(it?.titel?.ifBlank { null } ?: "Markierung", it?.notiz ?: "", SentinelFarben.akzent) }
    }
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(40.dp).background(farbe, CircleShape))
            Column(Modifier.weight(1f)) {
                Text(titel, style = MaterialTheme.typography.titleLarge)
                if (untertitel.isNotBlank()) Text(untertitel, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Button(onClick = {}, modifier = Modifier.fillMaxWidth().height(52.dp)) { Text("Hinführen") }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Zielliste(stand: LageStand) {
    Column(Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("Ziele") })
        LazyColumn {
            items(stand.zieleSortiert, key = { it.id }) { z ->
                ListItem(headlineContent = { Text(z.data.anzeigename) }, supportingContent = { z.data.zweiteZeile?.let { Text(it) } })
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Kraefteliste(stand: LageStand) {
    Column(Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("Kräfte") })
        LazyColumn {
            items(stand.kraefte, key = { it.id }) { f ->
                ListItem(
                    headlineContent = { Text(f.data.spitzname) },
                    supportingContent = { Text(if (f.data.aktiv) stand.fortbewegungText(f.data) else "Ruhemodus") },
                    trailingContent = { if (stand.istOnline(f.id)) Box(Modifier.size(10.dp).background(Color(0xFF34C759), CircleShape)) },
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Mehr(modell: AppModell, hauptmenue: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("Mehr") })
        ListItem(headlineContent = { Text("Hauptmenü") }, supportingContent = { Text("Instanzen wechseln oder verlassen") }, modifier = Modifier.clickable(onClick = hauptmenue))
        ListItem(headlineContent = { Text("Abmelden", color = MaterialTheme.colorScheme.error) }, modifier = Modifier.clickable { modell.abmelden() })
    }
}

/** Hauptmenü außerhalb jeder Instanz: eigene Instanzen öffnen, anderen beitreten. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Hauptmenue(modell: AppModell, stand: LageStand, schliessen: () -> Unit) {
    Scaffold(topBar = { TopAppBar(title = { Text("SENTINEL") }) }) { innen ->
        LazyColumn(Modifier.fillMaxSize().padding(innen)) {
            item { Text("Instanzen", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(16.dp)) }
            items(stand.eigeneInstanzen, key = { it.id }) { i ->
                ListItem(
                    headlineContent = { Text(i.data.name) },
                    supportingContent = { if (i.id == stand.instanz && stand.imDienst) Text("Geöffnet") },
                    modifier = Modifier.clickable {
                        if (i.id != stand.instanz || !stand.imDienst) modell.lage.instanzWechseln(i.id)
                        schliessen()
                    },
                )
            }
            if (stand.andereInstanzen.isNotEmpty()) {
                item { Text("Beitreten", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(16.dp)) }
                items(stand.andereInstanzen, key = { it.id }) { i ->
                    ListItem(headlineContent = { Text(i.data.name) }, trailingContent = { OutlinedButton(onClick = { modell.lage.instanzBeitreten(i.id) }) { Text("Beitreten") } })
                }
            }
            item {
                Spacer(Modifier.height(24.dp))
                Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.Center) {
                    OutlinedButton(onClick = { modell.abmelden() }) { Text("Abmelden") }
                    Spacer(Modifier.width(12.dp))
                }
            }
        }
    }
}
