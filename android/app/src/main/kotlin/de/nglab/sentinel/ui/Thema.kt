package de.nglab.sentinel.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** Farben der Rollen, gleich wie auf iOS und im Web (kern: `Farben`). */
object SentinelFarben {
    val akzent = Color(0xFF0A84FF)
    val kraefte = Color(0xFF5E5CE6)
    val ziele = Color(0xFFFF375F)
    val aPosition = Color(0xFFFF3B30)
    val sonderbereich = Color(0xFFAF52DE)
    val setzen = Color(0xFFFFD60A)
}

private val hell = lightColorScheme(
    primary = SentinelFarben.akzent,
    onPrimary = Color.White,
    secondary = SentinelFarben.kraefte,
    tertiary = SentinelFarben.ziele,
    error = SentinelFarben.aPosition,
)

private val dunkel = darkColorScheme(
    primary = SentinelFarben.akzent,
    onPrimary = Color.White,
    secondary = SentinelFarben.kraefte,
    tertiary = SentinelFarben.ziele,
    error = SentinelFarben.aPosition,
)

/** Material 3 mit den SENTINEL-Farben (keine dynamischen Systemfarben: die Rollenfarben tragen Bedeutung). */
@Composable
fun SentinelThema(inhalt: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) dunkel else hell, content = inhalt)
}
