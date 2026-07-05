package com.example.cuoti_doudui

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.print.PrintAttributes
import android.print.PrintManager
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val printChannelName = "zerror/print"
    private val mediaChannelName = "zerror/media"
    private val pickGalleryImageRequestCode = 7301
    private var printWebView: WebView? = null
    private var pendingPickImageResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            printChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "printHtml" -> {
                    val html = call.argument<String>("html").orEmpty()
                    val title = call.argument<String>("title").orEmpty()
                    if (html.isBlank()) {
                        result.error("EMPTY_HTML", "No HTML content to print.", null)
                        return@setMethodCallHandler
                    }
                    printHtml(title.ifBlank { "Zerror handout" }, html)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            mediaChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickGalleryImage" -> pickGalleryImage(result)
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Android framework, still valid for FlutterActivity interop.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == pickGalleryImageRequestCode) {
            val result = pendingPickImageResult ?: return
            pendingPickImageResult = null
            if (resultCode != Activity.RESULT_OK) {
                result.success(null)
                return
            }
            val uri = data?.data
            if (uri == null) {
                result.error("NO_IMAGE_URI", "No image was returned by the gallery.", null)
                return
            }
            try {
                result.success(copyPickedImageToCache(uri))
            } catch (error: Exception) {
                result.error("COPY_IMAGE_FAILED", error.message, null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun pickGalleryImage(result: MethodChannel.Result) {
        if (pendingPickImageResult != null) {
            result.error("PICK_IN_PROGRESS", "Another image picker is already open.", null)
            return
        }

        val intent = buildGalleryImageIntent()
        if (intent == null) {
            result.error("NO_GALLERY_APP", "No gallery app is available.", null)
            return
        }

        pendingPickImageResult = result
        try {
            startActivityForResult(intent, pickGalleryImageRequestCode)
        } catch (error: ActivityNotFoundException) {
            pendingPickImageResult = null
            result.error("NO_GALLERY_APP", "No gallery app is available.", null)
        }
    }

    private fun buildGalleryImageIntent(): Intent? {
        val candidates = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            candidates += Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }
        candidates += Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI).apply {
            type = "image/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        candidates += Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return candidates.firstOrNull { it.resolveActivity(packageManager) != null }
    }

    private fun copyPickedImageToCache(uri: Uri): String {
        val mimeType = contentResolver.getType(uri).orEmpty()
        val rawExtension = MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(mimeType)
            ?.takeIf { it.isNotBlank() }
            ?: "jpg"
        val extension = rawExtension.replace(Regex("[^A-Za-z0-9]"), "").ifBlank { "jpg" }
        val targetDir = File(cacheDir, "picked-images").apply { mkdirs() }
        val targetFile = File(
            targetDir,
            "gallery-${System.currentTimeMillis()}-${UUID.randomUUID()}.$extension",
        )

        val inputStream = contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Unable to open selected image.")
        inputStream.use { input ->
            FileOutputStream(targetFile).use { output ->
                input.copyTo(output)
            }
        }
        return targetFile.absolutePath
    }

    private fun printHtml(title: String, html: String) {
        val webView = WebView(this)
        printWebView = webView
        webView.settings.javaScriptEnabled = true
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                Handler(Looper.getMainLooper()).postDelayed({
                    createPrintJob(title, view)
                }, 800L)
            }
        }
        webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
    }

    private fun createPrintJob(title: String, webView: WebView) {
        val printManager = getSystemService(Context.PRINT_SERVICE) as PrintManager
        val adapter = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            webView.createPrintDocumentAdapter(title)
        } else {
            @Suppress("DEPRECATION")
            webView.createPrintDocumentAdapter()
        }
        val attributes = PrintAttributes.Builder()
            .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
            .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
            .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
            .build()
        printManager.print(title, adapter, attributes)
    }
}
