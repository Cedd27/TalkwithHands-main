package com.example.sign_language_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val exportsChannel = "talkwithhands/training_exports"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            exportsChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportCsvToDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName") ?: "training_data.csv"

                    if (sourcePath.isNullOrBlank()) {
                        result.error("missing_source", "Missing CSV source path.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val exportedPath = exportCsvToDownloads(sourcePath, fileName)
                        result.success(exportedPath)
                    } catch (e: Exception) {
                        result.error("export_failed", e.message ?: "CSV export failed.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun exportCsvToDownloads(sourcePath: String, fileName: String): String {
        val source = File(sourcePath)
        require(source.exists()) { "CSV file does not exist yet." }

        val safeName = fileName
            .substringAfterLast('/')
            .substringAfterLast('\\')
            .ifBlank { "training_data.csv" }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            exportWithMediaStore(source, safeName)
        } else {
            exportWithPublicDownloadPath(source, safeName)
        }
    }

    private fun exportWithMediaStore(source: File, fileName: String): String {
        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "text/csv")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/TalkwithHands")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Could not create Downloads file.")

        try {
            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(source).use { input -> input.copyTo(output) }
            } ?: throw IllegalStateException("Could not open Downloads file.")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Downloads/TalkwithHands/$fileName"
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
    }

    private fun exportWithPublicDownloadPath(source: File, fileName: String): String {
        val downloadsDir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "TalkwithHands"
        )
        if (!downloadsDir.exists() && !downloadsDir.mkdirs()) {
            throw IllegalStateException("Could not create Downloads/TalkwithHands.")
        }

        val destination = File(downloadsDir, fileName)
        FileInputStream(source).use { input ->
            FileOutputStream(destination).use { output -> input.copyTo(output) }
        }
        return destination.absolutePath
    }
}
