package com.example.cuoti_doudui

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.print.PrintAttributes
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val printChannelName = "zerror/print"
    private var printWebView: WebView? = null

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
