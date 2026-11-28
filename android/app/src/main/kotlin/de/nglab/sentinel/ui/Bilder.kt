package de.nglab.sentinel.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.OpenableColumns
import android.util.LruCache
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import de.nglab.sentinel.AppModell
import de.nglab.sentinel.kern.lage.Anhaenge
import de.nglab.sentinel.kern.modell.Ziel
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Bilder vom eigenen Server, im Speicher zwischengehalten (etwa 32 MB). */
object Bildspeicher {
    private val speicher = object : LruCache<String, Bitmap>(32 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

    suspend fun laden(modell: AppModell, blobId: String): ImageBitmap? {
        speicher.get(blobId)?.let { return it.asImageBitmap() }
        val api = modell.api ?: return null
        return withContext(Dispatchers.IO) {
            runCatching {
                val bytes = api.datei(blobId)
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.also { speicher.put(blobId, it) }?.asImageBitmap()
            }.getOrNull()
        }
    }

    /** Bild von einer offenen Quelle (Straßenbilder: Panoramax, Mapillary), ohne Anmeldung. */
    suspend fun ladenUrl(url: String): ImageBitmap? {
        speicher.get(url)?.let { return it.asImageBitmap() }
        return withContext(Dispatchers.IO) {
            runCatching {
                val verbindung = java.net.URL(url).openConnection().apply { connectTimeout = 8000; readTimeout = 15000 }
                verbindung.getInputStream().use { BitmapFactory.decodeStream(it) }?.also { speicher.put(url, it) }?.asImageBitmap()
            }.getOrNull()
        }
    }

    /** Foto verkleinern (längste Kante `Anhaenge.FOTO_KANTE`) und als JPEG verpacken. */
    fun verkleinern(kontext: Context, uri: Uri): ByteArray? = runCatching {
        val grenzen = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        kontext.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, grenzen) }
        var stichprobe = 1
        while (maxOf(grenzen.outWidth, grenzen.outHeight) / (stichprobe * 2) >= Anhaenge.FOTO_KANTE) stichprobe *= 2
        val roh = kontext.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = stichprobe }) } ?: return null
        val faktor = Anhaenge.FOTO_KANTE.toFloat() / maxOf(roh.width, roh.height)
        val bild = if (faktor < 1f) Bitmap.createScaledBitmap(roh, (roh.width * faktor).toInt(), (roh.height * faktor).toInt(), true) else roh
        ByteArrayOutputStream().also { bild.compress(Bitmap.CompressFormat.JPEG, (Anhaenge.FOTO_QUALITAET * 100).toInt(), it) }.toByteArray()
    }.getOrNull()

    fun dateiname(kontext: Context, uri: Uri): String = runCatching {
        kontext.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    }.getOrNull() ?: "Foto.jpg"
}

/** Bild vom Server; zeigt bis zum Laden einen Platzhalter. */
@Composable
fun ServerBild(modell: AppModell, blobId: String, modifier: Modifier, rund: Dp = 12.dp, inhalt: ContentScale = ContentScale.Crop) {
    var bild by remember(blobId) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(blobId) { bild = Bildspeicher.laden(modell, blobId) }
    Box(modifier.clip(RoundedCornerShape(rund)).background(MaterialTheme.colorScheme.surfaceContainerHigh), contentAlignment = Alignment.Center) {
        bild?.let { Image(it, null, Modifier.fillMaxSize(), contentScale = inhalt) } ?: CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
    }
}

/**
 * Fotos und Dateien eines Ziels: Vorschaubilder, Antippen zeigt das Bild groß, langes Drücken bietet Titelfoto und
 * Entfernen. Änderungen wirken sofort (`aendern` erhält den neuen Stand).
 */
@OptIn(ExperimentalLayoutApi::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun AnhaengeAbschnitt(modell: AppModell, z: Ziel, aendern: ((Ziel) -> Ziel) -> Unit) {
    val kontext = LocalContext.current
    val bereich = rememberCoroutineScope()
    var laedt by remember { mutableStateOf(false) }
    var fehler by remember { mutableStateOf<String?>(null) }
    var gross by remember { mutableStateOf<String?>(null) }
    var menue by remember { mutableStateOf<String?>(null) }
    val waehlen = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val api = modell.api ?: return@rememberLauncherForActivityResult
        laedt = true
        fehler = null
        bereich.launch {
            runCatching {
                val daten = withContext(Dispatchers.IO) { Bildspeicher.verkleinern(kontext, uri) } ?: error("Foto konnte nicht gelesen werden.")
                val d = api.hochladen(daten, "image/jpeg")
                Anhaenge.aus(d, Bildspeicher.dateiname(kontext, uri))
            }.onSuccess { a -> aendern { Anhaenge.hinzufuegen(it, a) } }
                .onFailure { fehler = it.message ?: "Hochladen fehlgeschlagen." }
            laedt = false
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        val bilder = Anhaenge.bilder(z)
        if (bilder.isNotEmpty()) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (a in bilder) {
                    Box {
                        ServerBild(
                            modell, a.blobId,
                            Modifier.size(96.dp).combinedClickable(onClick = { gross = a.blobId }, onLongClick = { menue = a.blobId }),
                        )
                        if (Anhaenge.titelfoto(z) == a.blobId) Icon(Icons.Filled.Star, "Titelfoto", tint = Color(0xFFFFD60A), modifier = Modifier.align(Alignment.TopEnd).padding(4.dp).size(18.dp))
                        DropdownMenu(expanded = menue == a.blobId, onDismissRequest = { menue = null }) {
                            DropdownMenuItem(text = { Text("Als Titelfoto") }, onClick = { menue = null; aendern { Anhaenge.alsTitelfoto(it, a.blobId) } })
                            DropdownMenuItem(text = { Text("Entfernen", color = MaterialTheme.colorScheme.error) }, onClick = { menue = null; aendern { Anhaenge.entfernen(it, a.blobId) } })
                        }
                    }
                }
            }
        }
        for (a in Anhaenge.dateien(z)) {
            ListItem(
                headlineContent = { Text(a.name.ifBlank { "Datei" }) },
                supportingContent = { Text(Anhaenge.groesseText(a.groesse)) },
                leadingContent = { Icon(Icons.Filled.Description, null) },
                trailingContent = { androidx.compose.material3.TextButton(onClick = { aendern { Anhaenge.entfernen(it, a.blobId) } }) { Text("Entfernen") } },
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedButton(onClick = { waehlen.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }, enabled = !laedt) { Text("Foto hinzufügen") }
            if (laedt) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
        }
        fehler?.let { Text(it, color = MaterialTheme.colorScheme.error) }
    }

    gross?.let { id ->
        Dialog(onDismissRequest = { gross = null }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            Box(Modifier.fillMaxSize().background(Color.Black).clickable { gross = null }) {
                ServerBild(modell, id, Modifier.fillMaxSize(), rund = 0.dp, inhalt = ContentScale.Fit)
            }
        }
    }
}

/**
 * Straßenbild am Ort (Panoramax, Mapillary über den eigenen Server): Vorschau, Antippen zeigt es groß mit Quelle und
 * Urheber. Ohne Bild in der Nähe erscheint nichts.
 */
@Composable
fun StrassenbildVorschau(modell: AppModell, ort: de.nglab.sentinel.kern.modell.GeoPunkt) {
    val schluessel = "${"%.4f".format(java.util.Locale.ROOT, ort.lat)},${"%.4f".format(java.util.Locale.ROOT, ort.lon)}"
    var info by remember(schluessel) { mutableStateOf<de.nglab.sentinel.kern.netz.Strassenbild?>(null) }
    var vorschau by remember(schluessel) { mutableStateOf<ImageBitmap?>(null) }
    var gross by remember { mutableStateOf(false) }
    LaunchedEffect(schluessel) {
        info = runCatching { modell.api?.strassenbild(ort) }.getOrNull()
        vorschau = info?.let { Bildspeicher.ladenUrl(it.vorschau) }
    }
    val b = info ?: return
    val v = vorschau ?: return
    val kontext = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Image(v, "Straßenbild", Modifier.fillMaxWidth().height(140.dp).clip(RoundedCornerShape(12.dp)).clickable { gross = true }, contentScale = ContentScale.Crop)
        Text(de.nglab.sentinel.kern.netz.Strassenbilder.beschriftung(b), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    if (gross) {
        var bild by remember { mutableStateOf<ImageBitmap?>(null) }
        LaunchedEffect(b.bild) { bild = Bildspeicher.ladenUrl(b.bild) }
        Dialog(onDismissRequest = { gross = false }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            Column(Modifier.fillMaxSize().background(Color.Black).clickable { gross = false }, verticalArrangement = Arrangement.Center) {
                (bild ?: v).let { Image(it, null, Modifier.fillMaxWidth().weight(1f), contentScale = ContentScale.Fit) }
                Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(de.nglab.sentinel.kern.netz.Strassenbilder.beschriftung(b), color = Color.White, style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                    androidx.compose.material3.TextButton(onClick = {
                        kontext.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(b.link)))
                    }) { Text("Quelle öffnen") }
                }
            }
        }
    }
}
