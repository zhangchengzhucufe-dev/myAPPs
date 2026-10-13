package com.zcz.beidan

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import java.io.ByteArrayInputStream
import java.io.File

// 页面通过自建 https 域名加载（等价 WebViewAssetLoader，但不引第三方库）：
// 真实 https 源保证 localStorage 持久可靠、crypto.randomUUID 可用；
// 访问电脑的 http 同步接口靠 MIXED_CONTENT_ALWAYS_ALLOW + usesCleartextTraffic。
private const val VIRTUAL_HOST = "appassets.local"
private const val PAGE_URL = "https://$VIRTUAL_HOST/index.html"

class MainActivity : Activity() {

    private lateinit var web: WebView
    private var fileCallback: android.webkit.ValueCallback<Array<Uri>>? = null

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        web = WebView(this)
        val dark = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_MASK
        // 背景色与页面主题一致，避免启动/过场闪白
        web.setBackgroundColor(if (dark) 0xFF141210.toInt() else 0xFFF7F0DD.toInt())
        setContentView(web)

        web.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            allowFileAccess = false
            allowContentAccess = false
            textZoom = 100 // 固定字号，避免系统字体缩放挤坏布局
        }
        web.addJavascriptInterface(Bridge(), "Beidan")
        web.webChromeClient = object : WebChromeClient() {
            override fun onShowFileChooser(
                view: WebView,
                callback: android.webkit.ValueCallback<Array<Uri>>,
                params: WebChromeClient.FileChooserParams
            ): Boolean {
                fileCallback?.onReceiveValue(null)
                fileCallback = callback
                val intent = params.createIntent().apply { addCategory(Intent.CATEGORY_OPENABLE) }
                return try {
                    startActivityForResult(intent, 1001)
                    true
                } catch (e: Exception) {
                    fileCallback = null
                    false
                }
            }
        }
        web.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
                serveAsset(request.url)

            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (request.url.host == VIRTUAL_HOST) return false
                // 页面内没有外链；万一出现则交给系统浏览器
                return try { startActivity(Intent(Intent.ACTION_VIEW, request.url)); true }
                catch (e: Exception) { true }
            }

            override fun onPageFinished(view: WebView, url: String) {
                if (!url.contains(VIRTUAL_HOST)) return
                // 启动后静默与电脑同步一次：配置了电脑地址、或 adb reverse 生效时才会有结果
                web.postDelayed({
                    web.evaluateJavascript("window.beidanSync && window.beidanSync(true)", null)
                }, 800)
            }
        }
        web.loadUrl(PAGE_URL)
    }

    private fun serveAsset(url: Uri): WebResourceResponse? {
        if (url.host != VIRTUAL_HOST) return null
        var path = url.path ?: return notFound()
        if (path == "/" || path.isEmpty()) path = "index.html" else path = path.trimStart('/')
        if (path.contains("..")) return notFound()
        val stream = try { assets.open(path) } catch (e: Exception) { return notFound() }
        val mime = mimeOf(path)
        val enc = if (mime.startsWith("text/") || mime == "application/json" || mime == "image/svg+xml") "utf-8" else null
        return WebResourceResponse(mime, enc, stream).apply {
            responseHeaders = mapOf("Access-Control-Allow-Origin" to "*", "Cache-Control" to "no-store")
        }
    }

    private fun mimeOf(path: String): String = when (path.substringAfterLast('.', "").lowercase()) {
        "html" -> "text/html"
        "js" -> "text/javascript"
        "css" -> "text/css"
        "json" -> "application/json"
        "svg" -> "image/svg+xml"
        "png" -> "image/png"
        "jpg", "jpeg" -> "image/jpeg"
        "webp" -> "image/webp"
        "ico" -> "image/x-icon"
        "woff2" -> "font/woff2"
        else -> "application/octet-stream"
    }

    private fun notFound() = WebResourceResponse(
        "text/plain", "utf-8", 404, "Not Found",
        mapOf("Access-Control-Allow-Origin" to "*"),
        ByteArrayInputStream(ByteArray(0))
    )

    override fun onBackPressed() {
        web.evaluateJavascript("window.beidanBack ? window.beidanBack() : 'none'") { r ->
            if (r != "\"handled\"") runOnUiThread { finish() }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 1001) {
            val uris = WebChromeClient.FileChooserParams.parseResult(resultCode, data)
            fileCallback?.onReceiveValue(uris)
            fileCallback = null
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onResume() {
        super.onResume()
        web.onResume()
        web.evaluateJavascript("window.beidanResume && window.beidanResume()", null)
    }

    override fun onPause() {
        // 先让页面结算本段计时并保存会话，再暂停 WebView
        web.evaluateJavascript("window.beidanPause && window.beidanPause()", null)
        web.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        web.destroy()
        super.onDestroy()
    }

    inner class Bridge {
        // 背诵/复习时保持屏幕常亮（页面在进入/离开会话时调用）
        @JavascriptInterface
        fun keepScreenOn(on: Boolean) {
            runOnUiThread {
                if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }

        // 备份文件保存到系统「下载」目录
        @JavascriptInterface
        fun saveFile(name: String, text: String) {
            runOnUiThread {
                try {
                    val saved = if (Build.VERSION.SDK_INT >= 29) {
                        val values = ContentValues().apply {
                            put(MediaStore.Downloads.DISPLAY_NAME, name)
                            put(MediaStore.Downloads.MIME_TYPE, "application/json")
                        }
                        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                        uri?.let {
                            contentResolver.openOutputStream(it)?.use { os -> os.write(text.toByteArray(Charsets.UTF_8)) }
                        } != null
                    } else {
                        // Android 8/9：保存到应用外部专属目录（无需存储权限）
                        val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
                        File(dir, name).writeText(text, Charsets.UTF_8)
                        true
                    }
                    toast(if (saved) "备份已保存" else "保存失败")
                } catch (e: Exception) {
                    toast("保存失败：" + (e.message ?: ""))
                }
            }
        }

        @JavascriptInterface
        fun appVersion(): String = try {
            packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0"
        } catch (e: Exception) { "1.0" }
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
