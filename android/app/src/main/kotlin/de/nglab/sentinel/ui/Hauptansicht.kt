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
import androidx.compose.material.icons.filled.Layers
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import de.nglab.sentinel.AppModell
import kotlinx.coroutines.launch
import de.nglab.sentinel.karte.KartenSteuerung
import de.nglab.sentinel.karte.LageKarte
import de.nglab.sentinel.kern.karte.Anheftung
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.Fortbewegung
import de.nglab.sentinel.kern.karte.Anlegbar
import de.nglab.sentinel.kern.lage.Kurzaktion
import de.nglab.sentinel.kern.navi.Naviziel
import de.nglab.sentinel.kern.lage.Kurzinfo
import de.nglab.sentinel.karte.bild
import de.nglab.sentinel.kern.karte.Platzierung
import de.nglab.sentinel.kern.lage.Lage
import de.nglab.sentinel.kern.modell.Art
import de.nglab.sentinel.kern.modell.Ebene
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.Ziel

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
    // Objekt, das die Karte beim Wechsel zum Lage-Tab zeigen soll (z. B. aus der Zielansicht)
    var fokus by remember { mutableStateOf<KartenObjekt?>(null) }
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
                Tab.Lage -> Lagebildschirm(modell, stand, fokus) { fokus = null }
                Tab.Ziele -> Zielliste(modell, stand) { fokus = it; tab = Tab.Lage }
                Tab.Kraefte -> Kraefteliste(modell, stand) { fokus = it; tab = Tab.Lage }
                Tab.Mehr -> Mehr(modell, stand) { hauptmenue = true }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun Lagebildschirm(modell: AppModell, stand: LageStand, fokus: KartenObjekt?, fokusErledigt: () -> Unit) {
    val steuerung = remember { KartenSteuerung() }
    var auswahl by remember { mutableStateOf<KartenObjekt?>(null) }
    // Zuschaltbare Ebenen (Verkehr, ÖPNV live, Bestreifung, Weg-Zeit)
    var ebenen by remember { mutableStateOf(de.nglab.sentinel.kern.karte.Kartenebenen()) }
    var ebenenWahl by remember { mutableStateOf(false) }
    val flaechen = remember { de.nglab.sentinel.kern.karte.Lageflaechen() }
    var flaechenStand by remember { mutableStateOf(0) }
    androidx.compose.runtime.LaunchedEffect(ebenen.verkehr) { steuerung.verkehr(ebenen.verkehr) }
    androidx.compose.runtime.LaunchedEffect(ebenen) {
        while (true) {
            val api = modell.api
            if (api != null && flaechen.aktualisieren(api, modell.lage.stand.value, ebenen, System.currentTimeMillis())) flaechenStand++
            kotlinx.coroutines.delay(de.nglab.sentinel.kern.karte.Lageflaechen.TAKT_MS)
        }
    }
    var sucht by remember { mutableStateOf(false) }
    var ortTreffer by remember { mutableStateOf<de.nglab.sentinel.kern.netz.Suchtreffer?>(null) }
    // Anlegen: Plus-Menü (optional an einem Ort), Platzierungsmodus, danach Editor
    var plus by remember { mutableStateOf(false) }
    var plusOrt by remember { mutableStateOf<GeoPunkt?>(null) }
    var platzierung by remember { mutableStateOf<Platzierung?>(null) }
    var editor by remember { mutableStateOf<Markierungsbearbeitung?>(null) }
    var neuesZiel by remember { mutableStateOf<Ziel?>(null) }
    var lageUebersicht by remember { mutableStateOf(false) }
    // Tempolimit an der eigenen Position, auch ohne Navigation (Straßenverzeichnis, gedrosselt im Kern)
    val tempolimitAbfrage = remember { de.nglab.sentinel.kern.navi.Tempolimitabfrage() }
    var tempolimitJetzt by remember { mutableStateOf<Int?>(null) }
    val ortFuerTempo by modell.ort.collectAsStateWithLifecycle()
    androidx.compose.runtime.LaunchedEffect(ortFuerTempo) {
        val o = ortFuerTempo ?: return@LaunchedEffect
        val api = modell.api ?: return@LaunchedEffect
        if ((o.tempo ?: 0.0) * 3.6 < 5 && tempolimitJetzt == null) return@LaunchedEffect
        if (tempolimitAbfrage.aktualisieren(api, GeoPunkt(o.lat, o.lon), System.currentTimeMillis())) tempolimitJetzt = tempolimitAbfrage.kmh
    }
    var zielansicht by remember { mutableStateOf<String?>(null) }
    // ÖPNV live: Fahrzeuge und Haltestellen im Kartenausschnitt
    val liveAn = ebenen.oepnvLive
    val live = remember { de.nglab.sentinel.kern.oepnv.OepnvLive() }
    var liveStand by remember { mutableStateOf(0) }
    var liveAnstoss by remember { mutableStateOf(0) }
    var fahrtAnsicht by remember { mutableStateOf<String?>(null) }
    // Verlauf eines Objekts und Spur-Markierungen
    var verlauf by remember { mutableStateOf<de.nglab.sentinel.kern.spur.Verlauf?>(null) }
    var verlaufStand by remember { mutableStateOf(0) }
    var verlaufAnteil by remember { mutableStateOf(1f) }
    var spurenStand by remember { mutableStateOf(0) }
    val bereich = androidx.compose.runtime.rememberCoroutineScope()
    androidx.compose.runtime.LaunchedEffect(Unit) {
        while (true) {
            val api = modell.api
            if (api != null && modell.spuren.aktualisieren(api, modell.lage.stand.value, System.currentTimeMillis())) spurenStand++
            kotlinx.coroutines.delay(10_000)
        }
    }
    val spurenJson = remember(spurenStand, verlaufStand, stand) { modell.spuren.geoJson(stand, verlauf) }

    fun verlaufLaden(v: de.nglab.sentinel.kern.spur.Verlauf, z: de.nglab.sentinel.kern.spur.Zeitraum) {
        val api = modell.api ?: return
        bereich.launch {
            v.laden(api, z)
            verlaufAnteil = 1f
            verlaufStand++
            v.rahmen()?.let { steuerung.einpassen(it) }
        }
    }
    var abfahrten by remember { mutableStateOf<de.nglab.sentinel.kern.oepnv.LiveHalt?>(null) }
    androidx.compose.runtime.LaunchedEffect(liveAn, liveAnstoss) {
        if (!liveAn) { live.leeren(); liveStand++; return@LaunchedEffect }
        while (true) {
            val b = steuerung.ausschnitt()
            val api = modell.api
            if (b != null && api != null) {
                live.laden(api, b[0], b[1], b[2], b[3], b[4])
                liveStand++
            }
            kotlinx.coroutines.delay(de.nglab.sentinel.kern.oepnv.OepnvLive.AKTUALISIEREN_MS)
        }
    }
    // Navigation
    val navi by modell.navigator.stand.collectAsStateWithLifecycle()
    var sonderrechte by rememberSaveable { mutableStateOf(false) }
    val ortJetzt by modell.ort.collectAsStateWithLifecycle()

    fun hinfuehren(ziel: Naviziel) {
        modell.navigator.starten(ziel, sonderrechte, zuFuss = stand.ich?.data?.fortbewegung == Fortbewegung.Fuss) { modell.lage.stand.value }
        steuerung.navigation(ortJetzt?.let { GeoPunkt(it.lat, it.lon) })
    }

    fun naviBeenden() {
        modell.navigator.stoppen()
        steuerung.navigation(null)
    }

    fun ergebnis(e: Platzierung.Ergebnis?) {
        when (e) {
            is Platzierung.Ergebnis.NeueMarkierung -> editor = Markierungsbearbeitung(Lage.neueId(), e.markierung, neu = true)
            is Platzierung.Ergebnis.NeuesZiel -> neuesZiel = e.ziel
            is Platzierung.Ergebnis.Verschoben -> modell.lage.markierungSichern(e.markierung, e.id)
            is Platzierung.Ergebnis.ZielVersetzt -> modell.lage.setzen(Art.Ziel, e.id, e.ziel)
            null -> Unit
        }
    }

    fun anlegen(was: Anlegbar) {
        plus = false
        if (was == Anlegbar.Standortspur) {
            val o = modell.ort.value
            val m = o?.let { de.nglab.sentinel.kern.spur.Verlauf.standortspur(stand, GeoPunkt(it.lat, it.lon), System.currentTimeMillis()) }
            if (m != null) modell.lage.markierungSichern(m, Lage.neueId())
            plusOrt = null
            return
        }
        val ort = plusOrt
        plusOrt = null
        steuerung.markieren(null)
        val p = Platzierung.anlegen(was, ort)
        // Einzelner Ort schon bekannt (Suchtreffer): direkt weiter, sonst Platzierungsmodus.
        if (ort != null && !p.mehrpunkt) ergebnis(p.bestaetigen(System.currentTimeMillis(), Ebene.LAGE)) else platzierung = p
    }

    Box(Modifier.fillMaxSize()) {
        LageKarte(
            modell, steuerung, Modifier.fillMaxSize().testTag("Lagekarte"),
            platzierung = platzierung,
            beiTipp = { punkt -> platzierung = platzierung?.tippen(punkt) },
            beiLangemDruck = { punkt ->
                if (platzierung == null && navi == null) {
                    steuerung.markieren(punkt)
                    bereich.launch { ortTreffer = de.nglab.sentinel.kern.netz.Ortsauswahl.aufloesen(modell.api, punkt) }
                }
            },
            live = if (liveAn) live else null,
            liveStand = liveStand,
            ebenen = ebenen,
            beiKameraRuhe = { if (liveAn) liveAnstoss++ },
            spurenJson = spurenJson,
            wegZeitJson = remember(flaechenStand) { flaechen.wegZeitGeoJson() },
            bestreifungJson = remember(flaechenStand) { flaechen.bestreifungGeoJson(System.currentTimeMillis()) },
        ) { auswahl = it }

        platzierung?.let { p ->
            Platzierungsleiste(
                p,
                zuruecknehmen = { platzierung = p.zuruecknehmen() },
                abbrechen = { platzierung = null },
                fertig = {
                    platzierung = null
                    val z = p.zweck
                    ergebnis(p.bestaetigen(
                        System.currentTimeMillis(), Ebene.LAGE,
                        markierung = (z as? Platzierung.Zweck.Verschieben)?.let { stand.markierungen[it.markierungId]?.data },
                        ziel = (z as? Platzierung.Zweck.ZielOrt)?.let { stand.ziele[it.zielId]?.data },
                    ))
                },
            )
        }

        navi?.let { n -> if (platzierung == null) NaviLeisteOben(n) }

        // Notruf-Leiste (rot), solange ein Notruf läuft: wer, und direkt hinführen
        val notruf = stand.fremderNotruf
        if (notruf != null && platzierung == null) {
            Surface(
                color = SentinelFarben.aPosition, contentColor = Color.White, shape = RoundedCornerShape(20.dp), shadowElevation = 6.dp,
                modifier = Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(top = if (navi != null) 150.dp else 68.dp).padding(horizontal = 16.dp).fillMaxWidth().testTag("Notrufleiste"),
            ) {
                Row(Modifier.padding(start = 16.dp, end = 8.dp).height(48.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("NOTRUF: ${notruf.data.spitzname}", fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    androidx.compose.material3.TextButton(onClick = { hinfuehren(Naviziel.Objekt(KartenObjekt(Objektart.Kraft, notruf.id))) }) {
                        Text("Hinführen", color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        // Oben: Suchleiste
        if (platzierung == null && navi == null) Surface(
            shape = RoundedCornerShape(28.dp),
            tonalElevation = 3.dp,
            shadowElevation = 4.dp,
            modifier = Modifier.statusBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth().height(52.dp).clickable { sucht = true },
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
            SosKnopf(stand.eigenerNotruf, ausloesen = { modell.lage.notrufAusloesen() }, beenden = { modell.lage.notrufBeenden() })
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
            Kartenknopf(Icons.Filled.Layers, "Ebenen", aktiv = ebenen.veraendert) { ebenenWahl = true }
            Kartenknopf(Icons.Filled.Add, "Hinzufügen", hervorgehoben = true) { plusOrt = null; plus = true }
        }

        // Unten: in der Navigation die Navi-Leiste, sonst A-Position, Fortbewegung und Lageleiste
        navi?.let { n ->
            Box(Modifier.align(Alignment.BottomCenter).padding(horizontal = 16.dp, vertical = 12.dp)) {
                NaviLeisteUnten(n, sonderrechte, sonderrechteUmschalten = {
                    sonderrechte = !sonderrechte
                    hinfuehren(n.ziel)
                }, modusWaehlen = { hinfuehren(it) }, beenden = ::naviBeenden,
                    zielImOepnv = de.nglab.sentinel.kern.navi.Navizielaufloesung.oepnvFahrzeug(n.ziel, stand) != null)
            }
        }
        verlauf?.let { v ->
            Box(Modifier.align(Alignment.BottomCenter).padding(horizontal = 16.dp, vertical = 12.dp)) {
                VerlaufLeiste(
                    v, verlaufStand, verlaufAnteil,
                    anteilSetzen = { a -> verlaufAnteil = a; v.zeitBei(a.toDouble())?.let { t -> steuerung.markieren(v.ort(t)) } },
                    zeitraumWaehlen = { verlaufLaden(v, it) },
                    behalten = { v.alsMarkierung()?.let { modell.lage.markierungSichern(it, Lage.neueId()) }; verlauf = null; steuerung.markieren(null) },
                    schliessen = { verlauf = null; verlaufStand++; steuerung.markieren(null) },
                )
            }
        }
        if (navi == null && verlauf == null) Column(
            Modifier.align(Alignment.BottomCenter).padding(horizontal = 16.dp, vertical = 12.dp).fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                AKnopf(stand, Modifier.weight(1f)) { if (stand.haeltA) modell.lage.aFreigeben() else modell.lage.aUebernehmen() }
                Fortbewegungswahl(stand.ich?.data?.fortbewegung ?: Fortbewegung.Fuss, Modifier.weight(1.2f)) { art ->
                    when (art) {
                        // ÖPNV braucht eine Fahrt: Live-Ansicht einschalten, Fahrzeug antippen, „Selbst einsteigen“
                        Fortbewegung.Oepnv -> if (stand.ich?.data?.oepnv == null) {
                            ebenen = ebenen.copy(oepnvLive = true)
                            modell.zeigeHinweis("ÖPNV-Fahrzeug antippen, dann „Details“ und „Selbst einsteigen“.")
                        } else modell.lage.fortbewegungSetzen(art, oepnv = stand.ich?.data?.oepnv)
                        // Fahrzeug: im Kräfte-Tab unter „Mein Fahrzeug“ gewählt; ohne Wahl das erste im Einsatz
                        Fortbewegung.Fahrzeug -> modell.lage.fortbewegungSetzen(art, stand.ich?.data?.fahrzeugId ?: de.nglab.sentinel.kern.lage.Kraefteansicht.waehlbareFahrzeuge(stand).firstOrNull()?.id)
                        Fortbewegung.Fuss -> modell.lage.fortbewegungSetzen(art)
                    }
                }
            }
            Lageleiste(stand) { lageUebersicht = true }
        }

        // Tempo und Tempolimit unten links (in Bewegung, auch ohne Navigation)
        if (navi == null && verlauf == null) {
            val o = ortJetzt
            val kmh = o?.tempo?.let { (it * 3.6).toInt() }?.takeIf { it >= 5 }
            if (kmh != null || tempolimitJetzt != null) Row(
                Modifier.align(Alignment.BottomStart).padding(start = 16.dp, bottom = 132.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically,
            ) {
                kmh?.let {
                    Surface(shape = RoundedCornerShape(12.dp), tonalElevation = 3.dp, shadowElevation = 3.dp) {
                        Column(Modifier.padding(horizontal = 10.dp, vertical = 4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("$it", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                            Text("km/h", style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
                tempolimitJetzt?.let { Tempolimit(it) }
            }
        }
    }

    if (sucht) {
        ModalBottomSheet(onDismissRequest = { sucht = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            Suche(modell, stand, schliessen = { sucht = false }) { e ->
                sucht = false
                when (e) {
                    is Suchergebnis.Objekt -> {
                        e.punkt?.let { steuerung.zeigen(it) }
                        auswahl = e.objekt
                    }
                    is Suchergebnis.Ort -> {
                        steuerung.zeigen(e.treffer.punkt, 17.0)
                        steuerung.markieren(e.treffer.punkt)
                        ortTreffer = e.treffer
                    }
                }
            }
        }
    }

    ortTreffer?.let { t ->
        ModalBottomSheet(onDismissRequest = { ortTreffer = null; steuerung.markieren(null) }) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(t.titel, style = MaterialTheme.typography.titleLarge)
                if (t.untertitel.isNotBlank()) Text(t.untertitel, color = MaterialTheme.colorScheme.onSurfaceVariant)
                StrassenbildVorschau(modell, t.punkt)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(onClick = { ortTreffer = null; steuerung.markieren(null); hinfuehren(Naviziel.Ort(t.punkt, t.titel)) }, modifier = Modifier.weight(1f).height(52.dp)) { Text("Hinführen") }
                    OutlinedButton(onClick = { ortTreffer = null; plusOrt = t.punkt; plus = true }, modifier = Modifier.weight(1f).height(52.dp)) { Text("Hier anlegen") }
                }
            }
        }
    }

    auswahl?.let { a ->
        ModalBottomSheet(onDismissRequest = { auswahl = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)) {
            val ort by modell.ort.collectAsStateWithLifecycle()
            val kontext = androidx.compose.ui.platform.LocalContext.current
            Kurzuebersicht(modell, stand, a, ort?.let { GeoPunkt(it.lat, it.lon) }, live) { k, info ->
                auswahl = null
                when (k) {
                    Kurzaktion.Hinfuehren -> when (a.art) {
                        Objektart.OepnvLive, Objektart.HaltLive -> info.ort?.let { hinfuehren(Naviziel.Ort(it, info.titel)) }
                        else -> hinfuehren(if (stand.einsatz.a?.memberId == a.id && a.art == Objektart.Kraft) Naviziel.APosition else Naviziel.Objekt(a))
                    }
                    Kurzaktion.Bearbeiten -> stand.markierungen[a.id]?.let { editor = Markierungsbearbeitung(a.id, it.data, neu = false) }
                    Kurzaktion.Verschieben -> platzierung = Platzierung(Platzierung.Zweck.Verschieben(a.id))
                    Kurzaktion.StandortSetzen -> platzierung = Platzierung(Platzierung.Zweck.ZielOrt(a.id))
                    Kurzaktion.Verlauf -> {
                        val v = de.nglab.sentinel.kern.spur.Verlauf(a, info.titel)
                        verlauf = v
                        val jetzt = System.currentTimeMillis()
                        val mitternacht = java.time.LocalDate.now().atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
                        verlaufLaden(v, de.nglab.sentinel.kern.spur.Verlauf.zeitraeume(jetzt, mitternacht)[1])
                    }
                    Kurzaktion.Anrufen -> info.telefon?.let {
                        kontext.startActivity(android.content.Intent(android.content.Intent.ACTION_DIAL, android.net.Uri.parse("tel:$it")))
                    }
                    Kurzaktion.Details -> when (a.art) {
                        Objektart.OepnvLive -> fahrtAnsicht = a.id
                        Objektart.HaltLive -> abfahrten = live.halt(a.id)
                        else -> zielansicht = a.id
                    }
                }
            }
        }
    }

    // Aus einem anderen Tab: Objekt zeigen und Kurzübersicht öffnen
    androidx.compose.runtime.LaunchedEffect(fokus) {
        val f = fokus ?: return@LaunchedEffect
        Kurzinfo.fuer(stand, f, System.currentTimeMillis(), null)?.ort?.let { steuerung.zeigen(it, 17.0) }
        auswahl = f
        fokusErledigt()
    }

    fahrtAnsicht?.let { id ->
        ModalBottomSheet(onDismissRequest = { fahrtAnsicht = null }) { FahrtAnsicht(modell, id) { fahrtAnsicht = null } }
    }
    abfahrten?.let { h ->
        ModalBottomSheet(onDismissRequest = { abfahrten = null }) {
            AbfahrtenAnsicht(modell, h, fahrtWaehlen = { abfahrten = null; fahrtAnsicht = it }) { abfahrten = null }
        }
    }

    zielansicht?.let { id ->
        ModalBottomSheet(onDismissRequest = { zielansicht = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            Zielansicht(
                modell, stand, id,
                zurueck = { zielansicht = null },
                aufKarte = {
                    zielansicht = null
                    Kurzinfo.fuer(stand, KartenObjekt(Objektart.Ziel, id), System.currentTimeMillis(), null)?.ort?.let { steuerung.zeigen(it, 17.0) }
                },
                standortSetzen = { zielansicht = null; platzierung = Platzierung(Platzierung.Zweck.ZielOrt(id)) },
                oeffnen = { zielansicht = it },
            )
        }
    }

    if (lageUebersicht) {
        ModalBottomSheet(onDismissRequest = { lageUebersicht = false }) { LageUebersicht(stand) }
    }

    if (ebenenWahl) {
        ModalBottomSheet(onDismissRequest = { ebenenWahl = false }) {
            Column(Modifier.fillMaxWidth().then(Modifier.verticalScroll(androidx.compose.foundation.rememberScrollState())).padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
                Text("Ebenen", style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(bottom = 8.dp))
                // Grundkarte und 3D
                androidx.compose.material3.SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    val karten = de.nglab.sentinel.kern.karte.Kartenebenen.grundkarten
                    karten.forEachIndexed { i, (schluessel, titel) ->
                        androidx.compose.material3.SegmentedButton(
                            selected = ebenen.grundkarte == schluessel,
                            onClick = { ebenen = ebenen.mitGrundkarte(schluessel) },
                            shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(i, karten.size),
                        ) { Text(titel) }
                    }
                }
                Row(Modifier.fillMaxWidth().height(52.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("Gebäude in 3D", modifier = Modifier.weight(1f))
                    androidx.compose.material3.Switch(checked = ebenen.dreiD, onCheckedChange = { ebenen = ebenen.mitDreiD(it) })
                }
                androidx.compose.material3.HorizontalDivider()
                for ((schluessel, titel) in de.nglab.sentinel.kern.karte.Kartenebenen.schalter) {
                    Row(Modifier.fillMaxWidth().height(52.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(titel, modifier = Modifier.weight(1f))
                        androidx.compose.material3.Switch(checked = ebenen.an(schluessel), onCheckedChange = { ebenen = ebenen.mit(schluessel, it) })
                    }
                }
                Text("Weg-Zeit-Flächen zeigen, wie weit jemand seit einer Sichtung gekommen sein kann.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                // Ziele nach Art und Gruppe ausblenden (nur auf diesem Gerät)
                Text("Ziele auf der Karte", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 16.dp, bottom = 4.dp))
                androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for ((art, titel) in de.nglab.sentinel.kern.karte.Kartenebenen.zielarten) {
                        androidx.compose.material3.FilterChip(selected = ebenen.zielartAn(art), onClick = { ebenen = ebenen.mitZielart(art, !ebenen.zielartAn(art)) }, label = { Text(titel) })
                    }
                    for (g in stand.zielgruppenSortiert) {
                        androidx.compose.material3.FilterChip(selected = ebenen.gruppeAn(g.id), onClick = { ebenen = ebenen.mitGruppe(g.id, !ebenen.gruppeAn(g.id)) }, label = { Text(g.data.name) })
                    }
                }
            }
        }
    }

    if (plus) {
        ModalBottomSheet(onDismissRequest = { plus = false; plusOrt = null; steuerung.markieren(null) }) { PlusMenue(::anlegen) }
    }

    editor?.let { b ->
        ModalBottomSheet(onDismissRequest = { editor = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            MarkierungsEditor(
                stand, b.markierung, b.neu,
                zuletzt = stand.markierungen[b.id]?.let { "Zuletzt geändert von ${stand.name(it.updatedBy)}" },
                abbrechen = { editor = null },
                sichern = { modell.lage.markierungSichern(it, b.id); editor = null },
                verschieben = { editor = null; platzierung = Platzierung(Platzierung.Zweck.Verschieben(b.id)) },
                loeschen = { modell.lage.loeschen(Art.Markierung, b.id); editor = null },
            )
        }
    }

    neuesZiel?.let { z ->
        ModalBottomSheet(onDismissRequest = { neuesZiel = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            ZielAnlegen(z, abbrechen = { neuesZiel = null }) { modell.lage.setzen(Art.Ziel, Lage.neueId(), it); neuesZiel = null }
        }
    }
}

/** Offener Markierungseditor: Kennung, Ausgangsstand, neu angelegt oder bestehend. */
private data class Markierungsbearbeitung(val id: String, val markierung: Markierung, val neu: Boolean)

@Composable
private fun Kartenknopf(bild: ImageVector, beschreibung: String, aktiv: Boolean = false, hervorgehoben: Boolean = false, aktion: () -> Unit) {
    FilledTonalIconButton(
        onClick = aktion,
        modifier = Modifier.size(48.dp),
        colors = if (hervorgehoben || aktiv) IconButtonDefaults.filledTonalIconButtonColors(containerColor = MaterialTheme.colorScheme.primary, contentColor = Color.White)
        else IconButtonDefaults.filledTonalIconButtonColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
    ) { Icon(bild, beschreibung) }
}

/**
 * Notrufknopf wie auf iOS: auslösen erst nach 1,5 s Halten (Ring füllt sich), damit ein versehentlicher Tipp nichts
 * auslöst. Den eigenen Notruf beendet ein Tipp mit Rückfrage.
 */
@Composable
private fun SosKnopf(eigenerNotruf: Boolean, ausloesen: () -> Unit, beenden: () -> Unit) {
    var fortschritt by remember { mutableStateOf(0f) }
    var rueckfrage by remember { mutableStateOf(false) }
    val bereich = androidx.compose.runtime.rememberCoroutineScope()
    var halten by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    val haptik = androidx.compose.ui.platform.LocalHapticFeedback.current
    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(48.dp)) {
        Surface(
            color = SentinelFarben.aPosition,
            contentColor = Color.White,
            shape = CircleShape,
            shadowElevation = 4.dp,
            modifier = Modifier.size(48.dp).testTag("SOS").pointerInput(eigenerNotruf) {
                detectTapGestures(
                    onPress = {
                        if (eigenerNotruf) return@detectTapGestures
                        halten = bereich.launch {
                            val start = System.currentTimeMillis()
                            while (fortschritt < 1f) {
                                fortschritt = ((System.currentTimeMillis() - start) / 1500f).coerceAtMost(1f)
                                kotlinx.coroutines.delay(16)
                            }
                            haptik.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                            ausloesen()
                        }
                        tryAwaitRelease()
                        halten?.cancel()
                        fortschritt = 0f
                    },
                    onTap = { if (eigenerNotruf) rueckfrage = true },
                )
            },
        ) {
            Box(contentAlignment = Alignment.Center) { Text(if (eigenerNotruf) "Ende" else "SOS", fontWeight = FontWeight.Bold) }
        }
        if (fortschritt > 0f) androidx.compose.material3.CircularProgressIndicator(progress = { fortschritt }, modifier = Modifier.size(54.dp), color = Color.White, strokeWidth = 4.dp)
    }
    if (rueckfrage) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { rueckfrage = false },
            title = { Text("Notruf beenden?") },
            confirmButton = { androidx.compose.material3.TextButton(onClick = { rueckfrage = false; beenden() }) { Text("Beenden") } },
            dismissButton = { androidx.compose.material3.TextButton(onClick = { rueckfrage = false }) { Text("Abbrechen") } },
        )
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
private fun Lageleiste(stand: LageStand, oeffnen: () -> Unit) {
    Surface(onClick = oeffnen, shape = RoundedCornerShape(24.dp), tonalElevation = 3.dp, shadowElevation = 3.dp, modifier = Modifier.fillMaxWidth().height(48.dp).testTag("Lageleiste")) {
        Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stand.einsatz.funkkanal?.let { "Kanal $it" } ?: "Kein Kanal", fontWeight = FontWeight.SemiBold)
            Text(stand.aktuelleInstanz?.data?.name ?: "", color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, modifier = Modifier.weight(1f))
            stand.aHalter?.let { Text("A: ${it.data.spitzname}", color = SentinelFarben.aPosition, fontWeight = FontWeight.SemiBold) }
        }
    }
}

/** Kurzübersicht eines angetippten Objekts: Inhalt aus dem Kern (gleich wie auf iOS), Aktionen als Knöpfe. */
@Composable
private fun Kurzuebersicht(modell: AppModell, stand: LageStand, a: KartenObjekt, ich: GeoPunkt?, live: de.nglab.sentinel.kern.oepnv.OepnvLive, aktion: (Kurzaktion, Kurzinfo) -> Unit) {
    val jetzt = System.currentTimeMillis()
    val info = (live.kurzinfo(a, jetzt) ?: Kurzinfo.fuer(stand, a, jetzt, ich)) ?: run {
        Text("Nicht mehr in der Lage", modifier = Modifier.padding(20.dp))
        return
    }
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(44.dp).background(hexFarbe(info.farbe), CircleShape), contentAlignment = Alignment.Center) {
                Icon(info.symbol.bild(), null, tint = Color.White)
            }
            Column(Modifier.weight(1f)) {
                Text(info.titel, style = MaterialTheme.typography.titleLarge, maxLines = 2)
                if (info.untertitel.isNotBlank()) Text(info.untertitel, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        val knoepfe = info.aktionen.filter { it in UMGESETZT }
        if (knoepfe.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                knoepfe.forEachIndexed { i, k ->
                    if (i == 0) Button(onClick = { aktion(k, info) }, modifier = Modifier.weight(1f).height(48.dp)) { Text(k.titel, maxLines = 1) }
                    else OutlinedButton(onClick = { aktion(k, info) }, modifier = Modifier.weight(1f).height(48.dp)) { Text(k.titel, maxLines = 1) }
                }
            }
        }
        // Straßenbild bei festen Orten (Ziele, Markierungen), nicht bei bewegten Kräften und Fahrzeugen
        if (a.art == Objektart.Ziel || a.art == Objektart.Markierung) info.ort?.let { StrassenbildVorschau(modell, it) }
        if (info.zeilen.isNotEmpty()) {
            Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surfaceContainerHigh) {
                Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp)) {
                    info.zeilen.forEachIndexed { i, z ->
                        if (i > 0) androidx.compose.material3.HorizontalDivider()
                        Row(Modifier.padding(vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(z.titel, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(110.dp))
                            Text(z.wert, modifier = Modifier.weight(1f))
                        }
                    }
                }
            }
        }
    }
}

/** Aktionen, die es in dieser Ausbaustufe schon gibt (Details folgen mit der Zielansicht). */
private val UMGESETZT = Kurzaktion.entries.toSet()

/** Lageübersicht (aus der Lageleiste): Einsatz, Funkkanal, A-Position und Erreichbarkeit der Kräfte mit Anrufen. */
@Composable
private fun LageUebersicht(stand: LageStand) {
    val kontext = androidx.compose.ui.platform.LocalContext.current
    val jetzt = System.currentTimeMillis()
    LazyColumn(Modifier.fillMaxWidth().padding(bottom = 24.dp)) {
        item {
            Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(stand.einsatz.titel.ifBlank { stand.aktuelleInstanz?.data?.name ?: "Lage" }, style = MaterialTheme.typography.titleLarge)
                Text(listOfNotNull(stand.einsatz.funkkanal?.let { "Kanal $it" }, stand.aHalter?.let { "A: ${it.data.spitzname} (${stand.fortbewegungText(it.data)})" }).joinToString(" · ").ifBlank { "Kein Kanal, keine A" }, color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (stand.einsatz.hinweise.isNotBlank()) Text(stand.einsatz.hinweise)
                Text("Kräfte", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 12.dp))
            }
        }
        items(de.nglab.sentinel.kern.lage.Kraefteansicht.sortiert(stand), key = { it.id }) { f ->
            ListItem(
                headlineContent = { Text(f.data.spitzname) },
                supportingContent = { Text(de.nglab.sentinel.kern.lage.Kraefteansicht.status(stand, f, jetzt), maxLines = 1) },
                trailingContent = {
                    if (f.data.telefon.isNotBlank() && f.id != stand.ichId) androidx.compose.material3.FilledTonalButton(onClick = {
                        kontext.startActivity(android.content.Intent(android.content.Intent.ACTION_DIAL, android.net.Uri.parse("tel:${f.data.telefon}")))
                    }) { Text("Anrufen") }
                },
            )
        }
    }
}
