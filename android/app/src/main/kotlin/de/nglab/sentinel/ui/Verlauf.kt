package de.nglab.sentinel.ui

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import de.nglab.sentinel.kern.format.Format
import de.nglab.sentinel.kern.spur.Verlauf
import de.nglab.sentinel.kern.spur.Zeitraum

/**
 * Leiste unten im Verlauf: Titel mit Schließen (in der Leiste, nicht oben), Zeitraum, Zusammenfassung, Zeitregler
 * und „Auf der Karte behalten“. Gleich aufgebaut wie auf iOS.
 */
@Composable
fun VerlaufLeiste(
    v: Verlauf,
    stand: Int,
    anteil: Float,
    anteilSetzen: (Float) -> Unit,
    zeitraumWaehlen: (Zeitraum) -> Unit,
    behalten: () -> Unit,
    schliessen: () -> Unit,
) {
    @Suppress("UNUSED_EXPRESSION") stand // neu zeichnen nach dem Laden
    Surface(shape = RoundedCornerShape(24.dp), tonalElevation = 3.dp, shadowElevation = 4.dp, modifier = Modifier.fillMaxWidth().testTag("Verlaufleiste")) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("Verlauf ${v.titel}", style = MaterialTheme.typography.titleMedium, maxLines = 1)
                    Text(v.zusammenfassung(), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                }
                IconButton(onClick = schliessen) { Icon(Icons.Filled.Close, "Verlauf schließen") }
            }
            val jetzt = System.currentTimeMillis()
            val mitternacht = java.time.LocalDate.now().atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for (z in Verlauf.zeitraeume(jetzt, mitternacht)) {
                    FilterChip(selected = v.zeitraum?.titel == z.titel, onClick = { zeitraumWaehlen(z) }, label = { Text(z.titel) })
                }
            }
            v.zeitBei(anteil.toDouble())?.let { t ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(Format.uhrzeit(t), style = MaterialTheme.typography.labelLarge)
                    Slider(value = anteil, onValueChange = anteilSetzen, modifier = Modifier.weight(1f))
                }
            }
            if (v.spur?.punkte?.isNotEmpty() == true) OutlinedButton(onClick = behalten) { Text("Auf der Karte behalten") }
        }
    }
}
