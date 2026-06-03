package com.example.groww_expense_tracker

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.groww_expense_tracker/save_file"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveFileToDownloads") {
                val fileName = call.argument<String>("fileName")
                val fileBytes = call.argument<ByteArray>("fileBytes")
                val mimeType = call.argument<String>("mimeType")

                if (fileName != null && fileBytes != null && mimeType != null) {
                    val success = saveFileToDownloads(fileName, fileBytes, mimeType)
                    if (success) {
                        result.success(true)
                    } else {
                        result.error("SAVE_FAILED", "Failed to save file to downloads", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing arguments", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveFileToDownloads(fileName: String, fileBytes: ByteArray, mimeType: String): Boolean {
        return try {
            val resolver = contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }

            // For Android Q and above, use MediaStore Downloads collection
            val collectionUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Downloads.EXTERNAL_CONTENT_URI
            } else {
                MediaStore.Files.getContentUri("external")
            }

            val fileUri: Uri? = resolver.insert(collectionUri, contentValues)

            if (fileUri != null) {
                resolver.openOutputStream(fileUri).use { outputStream ->
                    outputStream?.write(fileBytes)
                    outputStream?.flush()
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    contentValues.clear()
                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(fileUri, contentValues, null, null)
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
