package de.nglab.sentinel.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import de.nglab.sentinel.kern.lage.Dringlichkeit
import de.nglab.sentinel.kern.lage.Meldung
import de.nglab.sentinel.kern.lage.Meldungen
import kotlinx.coroutines.delay

/** Banner oben für Meldungen; Alarme rot und bis zum Wegtippen, sonst nach kurzer Zeit von selbst weg (wie iOS). */
@Composable
fun Banner(m: Meldung?, weg: () -> Unit) {
    LaunchedEffect(m) {
        val dauer = m?.let { Meldungen.anzeigedauerMs(it) } ?: return@LaunchedEffect
        delay(dauer)
        weg()
    }
    AnimatedVisibility(visible = m != null, enter = slideInVertically { -it }, exit = slideOutVertically { -it }) {
        val meldung = m ?: return@AnimatedVisibility
        val alarm = meldung.dringlichkeit == Dringlichkeit.Alarm
        Surface(
            color = if (alarm) SentinelFarben.aPosition else MaterialTheme.colorScheme.inverseSurface,
            contentColor = if (alarm) Color.White else MaterialTheme.colorScheme.inverseOnSurface,
            shape = RoundedCornerShape(20.dp),
            shadowElevation = 8.dp,
            modifier = Modifier.statusBarsPadding().padding(horizontal = 12.dp, vertical = 8.dp).fillMaxWidth().clickable(onClick = weg).testTag("Banner"),
        ) {
            Column(Modifier.padding(horizontal = 18.dp, vertical = 12.dp)) {
                Text(meldung.titel, fontWeight = FontWeight.Bold)
                if (meldung.text.isNotBlank()) Text(meldung.text, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}
