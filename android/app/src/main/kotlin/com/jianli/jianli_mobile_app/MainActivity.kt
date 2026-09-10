package com.jianli.jianli_mobile_app

import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/// 文件互传「打开」按钮：原生化文件操作通道（#open-folder）
///
/// 通道 jianli/file_actions：
/// - queryOpenableApps(path) → 可打开该文件的应用列表 [{packageName, activityName, label, icon(base64 PNG)}]
/// - openFolder(path)        → 打开文件所在文件夹（尽力而为，仅目录型文件管理器可响应）
/// - openWithApp(path, packageName, activityName) → 用指定应用打开文件
///
/// 为什么不用 open_filex：它只能打开文件本身，无法打开「所在文件夹」（ActivityNot... 且目录 URI 直接传 file:// 会
/// 触发 FileUriExposedException）。这里自持 FileProvider 生成 content://，由原生侧完成目录浏览与按应用分发。
class MainActivity : FlutterActivity() {
    private val CHANNEL = "jianli/file_actions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "queryOpenableApps" -> {
                    val path = call.argument<String>("path") ?: ""
                    try {
                        result.success(queryOpenableApps(path))
                    } catch (e: Exception) {
                        result.error("QUERY_FAILED", e.message, null)
                    }
                }
                "openFolder" -> {
                    val path = call.argument<String>("path") ?: ""
                    try {
                        result.success(openFolder(path))
                    } catch (e: Exception) {
                        result.error("OPEN_FOLDER_FAILED", e.message, null)
                    }
                }
                "openWithApp" -> {
                    val path = call.argument<String>("path") ?: ""
                    val pkg = call.argument<String>("packageName") ?: ""
                    val act = call.argument<String>("activityName") ?: ""
                    try {
                        result.success(openWithApp(path, pkg, act))
                    } catch (e: Exception) {
                        result.error("OPEN_APP_FAILED", e.message, null)
                    }
                }
                // 读取 Android API level（Dart 侧据此区分 API 30+ 必须「所有文件访问」的边界）
                "getSdkVersion" -> {
                    result.success(Build.VERSION.SDK_INT)
                }
                // 落盘后触发 MediaStore 重新索引，使写入共享 Download 的文件立即被文件管理器/系统媒体可见
                "scanFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    try {
                        MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SCAN_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 用本应用自持 FileProvider 把文件/目录包装成 content://（避免 file:// 触发 FileUriExposedException） */
    private fun fileUri(path: String): Uri =
        FileProvider.getUriForFile(this, "$packageName.fileprovider", File(path))

    private fun guessMime(path: String): String? {
        val ext = path.substringAfterLast('.', "").lowercase()
        if (ext.isEmpty()) return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
    }

    /** 系统解析：能打开该文件的应用（去重到包名，跳过本应用自身），带回应用图标 PNG base64 */
    private fun queryOpenableApps(path: String): List<Map<String, String>> {
        val uri = fileUri(path)
        val mime = contentResolver.getType(uri) ?: guessMime(path) ?: "*/*"
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val pm = packageManager
        val resolveInfos = pm.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        val seen = mutableSetOf<String>()
        val out = mutableListOf<Map<String, String>>()
        for (ri in resolveInfos) {
            val pkg = ri.activityInfo.packageName
            if (pkg == packageName) continue // 跳过本应用（无 VIEW 过滤器，理论上不出现，保险）
            if (seen.contains(pkg)) continue // 同一应用多个 activity 只留首个
            seen.add(pkg)
            out.add(
                mapOf(
                    "packageName" to pkg,
                    "activityName" to ri.activityInfo.name,
                    "label" to ri.loadLabel(pm).toString(),
                    "icon" to drawableToBase64(ri.loadIcon(pm)),
                )
            )
        }
        return out
    }

    /** 打开文件所在文件夹：目录型 VIEW intent，按 mime 候选逐个试探（资源/文件夹型文件管理器才响应） */
    private fun openFolder(path: String): Boolean {
        val file = File(path)
        val dir = file.parentFile ?: file
        val uri = fileUri(dir.absolutePath)
        val pm = packageManager
        val candidates = listOf(
            "vnd.android.document/directory",
            "resource/folder",
            "*/*",
        )
        for (mime in candidates) {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            if (intent.resolveActivity(pm) != null) {
                startActivity(intent)
                return true
            }
        }
        return false
    }

    /** 用指定应用打开文件（精确 setClassName，避免弹出系统选择器） */
    private fun openWithApp(path: String, pkg: String, act: String): Boolean {
        return try {
            val uri = fileUri(path)
            val mime = guessMime(path) ?: "*/*"
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                setClassName(pkg, act)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val stream = ByteArrayOutputStream()
        drawableToBitmap(drawable).compress(Bitmap.CompressFormat.PNG, 100, stream)
        return android.util.Base64.encodeToString(stream.toByteArray(), android.util.Base64.NO_WRAP)
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        val w = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
        val h = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}
