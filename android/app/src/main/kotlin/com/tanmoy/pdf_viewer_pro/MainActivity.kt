package com.tanmoy.pdf_viewer_pro

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * Receives PDFs opened from outside the app (ACTION_VIEW / ACTION_SEND) and
 * exposes them to Flutter over a MethodChannel.
 *
 * External content:// URIs are copied into the app cache so the Dart side always
 * gets a real, readable file path.
 */
class MainActivity : FlutterActivity() {

    private val channel = "com.tanmoy.pdf_viewer_pro/intent"

    // The file resolved from the intent that launched (or resumed) the app.
    private var pendingPath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter asks for the file the app was launched with (cold start).
                "getInitialFile" -> {
                    val path = pendingPath ?: resolveIntent(intent)
                    pendingPath = null
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Warm start: app already running, user opens another PDF.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val path = resolveIntent(intent)
        if (path != null) {
            // Push it straight to Flutter if the engine is ready, else stash it.
            if (methodChannel != null) {
                methodChannel?.invokeMethod("openFile", path)
            } else {
                pendingPath = path
            }
        }
    }

    /** Extract a usable file path from a VIEW/SEND intent, or null. */
    private fun resolveIntent(intent: Intent?): String? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        } ?: return null

        return try {
            when (uri!!.scheme) {
                "file" -> uri.path
                else -> copyUriToCache(uri) // content:// (and anything else)
            }
        } catch (e: Exception) {
            null
        }
    }

    /** Copy a content:// URI into cache and return the cached file path. */
    private fun copyUriToCache(uri: Uri): String? {
        val name = queryDisplayName(uri) ?: "document_${System.currentTimeMillis()}.pdf"
        val safeName = if (name.lowercase().endsWith(".pdf")) name else "$name.pdf"
        val outDir = File(cacheDir, "opened_pdfs").apply { mkdirs() }
        val outFile = File(outDir, safeName)

        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
            }
        } ?: return null

        return outFile.absolutePath
    }

    private fun queryDisplayName(uri: Uri): String? {
        var name: String? = null
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && cursor.moveToFirst()) {
                name = cursor.getString(idx)
            }
        }
        return name
    }
}
