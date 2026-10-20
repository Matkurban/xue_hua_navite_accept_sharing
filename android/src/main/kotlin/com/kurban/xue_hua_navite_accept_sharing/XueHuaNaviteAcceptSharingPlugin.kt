package com.kurban.xue_hua_navite_accept_sharing

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import java.util.concurrent.Executors

/** XueHuaNaviteAcceptSharingPlugin */
class XueHuaNaviteAcceptSharingPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener {

    companion object {
        private const val METHOD_CHANNEL_NAME = "xue_hua_navite_accept_sharing"
        private const val EVENT_CHANNEL_NAME = "xue_hua_navite_accept_sharing/events"
        private const val INTENT_CONSUMED_KEY =
            "com.kurban.xue_hua_navite_accept_sharing.INTENT_CONSUMED"
        private const val SHARED_CACHE_DIR = "shared_files"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var applicationContext: Context? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var eventSink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()

    @Volatile
    internal var initialPayload: Map<String, Any?>? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getInitialSharing" -> result.success(initialPayload)
            "clearInitialSharing" -> {
                initialPayload = null
                result.success(null)
            }
            "cleanupTempFiles" -> {
                ioExecutor.execute {
                    val cleaned = cleanupSharedCacheDirectory()
                    mainHandler.post {
                        if (cleaned) {
                            result.success(null)
                        } else {
                            result.error("CLEANUP_ERROR", "Failed to clean up temporary files.", null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        binding.activity.intent?.let { intent ->
            processIntent(intent, isInitial = true)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
    }

    override fun onNewIntent(intent: Intent): Boolean {
        activityBinding?.activity?.intent = intent
        return processIntent(intent, isInitial = false)
    }

    internal fun processIntent(intent: Intent, isInitial: Boolean): Boolean {
        val action = intent.action ?: return false
        if (action != Intent.ACTION_SEND &&
            action != Intent.ACTION_SEND_MULTIPLE &&
            action != Intent.ACTION_VIEW
        ) {
            return false
        }

        if (isInitial && intent.getBooleanExtra(INTENT_CONSUMED_KEY, false)) {
            return false
        }
        intent.putExtra(INTENT_CONSUMED_KEY, true)

        ioExecutor.execute {
            val payload = extractPayloadFromIntent(intent)
            if (payload != null) {
                if (isInitial) {
                    initialPayload = payload
                } else {
                    mainHandler.post {
                        eventSink?.success(payload)
                    }
                }
            }
        }
        return true
    }

    internal fun extractPayloadFromIntent(intent: Intent): Map<String, Any?>? {
        val action = intent.action ?: return null
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            ?: intent.getStringExtra(Intent.EXTRA_TITLE)
        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        val items = mutableListOf<Map<String, Any?>>()

        when (action) {
            Intent.ACTION_SEND -> {
                val streamUri = getParcelableUriExtra(intent, Intent.EXTRA_STREAM)
                    ?: extractFirstClipDataUri(intent.clipData)
                if (streamUri != null) {
                    resolveUriItem(streamUri, intent.type, subject)?.let { items.add(it) }
                }
                if (!sharedText.isNullOrBlank()) {
                    // Add text item if no stream URI was provided, or keep as accompanying text
                    if (items.isEmpty()) {
                        items.add(buildTextItem(sharedText, subject))
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = getParcelableUriArrayListExtra(intent, Intent.EXTRA_STREAM)
                    ?: extractAllClipDataUris(intent.clipData)
                for (uri in uris) {
                    resolveUriItem(uri, intent.type, subject)?.let { items.add(it) }
                }
                if (items.isEmpty() && !sharedText.isNullOrBlank()) {
                    items.add(buildTextItem(sharedText, subject))
                }
            }
            Intent.ACTION_VIEW -> {
                val dataUri = intent.data ?: extractFirstClipDataUri(intent.clipData)
                if (dataUri != null) {
                    val scheme = dataUri.scheme?.lowercase(Locale.ROOT)
                    if (scheme == "http" || scheme == "https") {
                        items.add(
                            mapOf(
                                "type" to "url",
                                "content" to dataUri.toString(),
                                "mimeType" to "text/uri-list",
                                "extra" to if (subject != null) mapOf("subject" to subject) else null
                            )
                        )
                    } else {
                        resolveUriItem(dataUri, intent.type, subject)?.let { items.add(it) }
                    }
                }
            }
        }

        if (items.isEmpty() && sharedText.isNullOrBlank()) {
            return null
        }

        return mapOf(
            "items" to items,
            "text" to sharedText,
            "subject" to subject
        )
    }

    internal fun buildTextItem(text: String, subject: String?): Map<String, Any?> {
        val trimmed = text.trim()
        val isUrl = !trimmed.contains(" ") &&
            !trimmed.contains("\n") &&
            (trimmed.startsWith("http://", ignoreCase = true) ||
                trimmed.startsWith("https://", ignoreCase = true))
        return mapOf(
            "type" to if (isUrl) "url" else "text",
            "content" to text,
            "mimeType" to if (isUrl) "text/uri-list" else "text/plain",
            "extra" to if (subject != null) mapOf("subject" to subject) else null
        )
    }

    private fun resolveUriItem(
        uri: Uri,
        intentMimeType: String?,
        subject: String?
    ): Map<String, Any?>? {
        val context = applicationContext ?: activityBinding?.activity?.applicationContext ?: return null
        val scheme = uri.scheme?.lowercase(Locale.ROOT)

        if (scheme == "file") {
            val path = uri.path ?: return null
            val file = File(path)
            val fileName = file.name.ifEmpty { "shared_file" }
            val mimeType = resolveMimeType(context, uri, fileName, intentMimeType)
            val itemType = classifyMimeType(mimeType)
            return mapOf(
                "type" to itemType,
                "content" to file.absolutePath,
                "fileName" to fileName,
                "mimeType" to mimeType,
                "fileSize" to if (file.exists()) file.length() else null,
                "extra" to if (subject != null) mapOf("subject" to subject) else null
            )
        }

        val resolver = context.contentResolver
        var displayName: String? = null
        var fileSize: Long? = null

        try {
            resolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIdx >= 0 && !cursor.isNull(nameIdx)) {
                        displayName = cursor.getString(nameIdx)
                    }
                    val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIdx >= 0 && !cursor.isNull(sizeIdx)) {
                        fileSize = cursor.getLong(sizeIdx)
                    }
                }
            }
        } catch (_: Exception) {
            // Ignore metadata query failures and fallback to URI segment.
        }

        val mimeType = resolveMimeType(context, uri, displayName, intentMimeType)
        val safeFileName = sanitizeFileName(displayName ?: uri.lastPathSegment, mimeType)
        val copiedFile = copyUriToCache(context, uri, safeFileName) ?: return null
        val resolvedSize = fileSize ?: copiedFile.length()
        val itemType = classifyMimeType(mimeType)

        return mapOf(
            "type" to itemType,
            "content" to copiedFile.absolutePath,
            "fileName" to safeFileName,
            "mimeType" to mimeType,
            "fileSize" to resolvedSize,
            "extra" to if (subject != null) mapOf("subject" to subject) else null
        )
    }

    private fun copyUriToCache(context: Context, uri: Uri, fileName: String): File? {
        return try {
            val dir = File(context.cacheDir, SHARED_CACHE_DIR)
            if (!dir.exists()) {
                dir.mkdirs()
            }
            val destFile = File(dir, "${System.currentTimeMillis()}_$fileName")
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output, bufferSize = 64 * 1024)
                }
            } ?: return null
            destFile
        } catch (_: Exception) {
            null
        }
    }

    private fun cleanupSharedCacheDirectory(): Boolean {
        val context = applicationContext ?: activityBinding?.activity?.applicationContext ?: return true
        return try {
            val dir = File(context.cacheDir, SHARED_CACHE_DIR)
            if (dir.exists()) {
                dir.deleteRecursively()
            } else {
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun resolveMimeType(
        context: Context,
        uri: Uri,
        fileName: String?,
        fallbackMime: String?
    ): String {
        val resolverType = try {
            context.contentResolver.getType(uri)
        } catch (_: Exception) {
            null
        }
        if (!resolverType.isNullOrBlank() && resolverType != "*/*") {
            return resolverType
        }
        if (!fileName.isNullOrBlank()) {
            val ext = fileName.substringAfterLast('.', "").lowercase(Locale.ROOT)
            if (ext.isNotEmpty()) {
                val mapped = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
                if (!mapped.isNullOrBlank()) {
                    return mapped
                }
            }
        }
        if (!fallbackMime.isNullOrBlank() && fallbackMime != "*/*") {
            return fallbackMime
        }
        return "application/octet-stream"
    }

    internal fun classifyMimeType(mimeType: String): String {
        val lower = mimeType.lowercase(Locale.ROOT)
        return when {
            lower.startsWith("image/") -> "image"
            lower.startsWith("video/") -> "video"
            lower.startsWith("audio/") -> "audio"
            else -> "file"
        }
    }

    private fun sanitizeFileName(rawName: String?, mimeType: String): String {
        val cleaned = (rawName ?: "shared_file")
            .substringAfterLast('/')
            .replace(Regex("[^a-zA-Z0-9._\\-\\u4e00-\\u9fa5 ()]"), "_")
            .ifBlank { "shared_file" }
        if (cleaned.contains('.')) {
            return cleaned
        }
        val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
        return if (!ext.isNullOrBlank()) "$cleaned.$ext" else cleaned
    }

    private fun getParcelableUriExtra(intent: Intent, name: String): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(name, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(name)
        }
    }

    private fun getParcelableUriArrayListExtra(intent: Intent, name: String): List<Uri>? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(name, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra(name)
        }
    }

    private fun extractFirstClipDataUri(clipData: ClipData?): Uri? {
        if (clipData == null || clipData.itemCount == 0) return null
        return clipData.getItemAt(0)?.uri
    }

    private fun extractAllClipDataUris(clipData: ClipData?): List<Uri> {
        if (clipData == null) return emptyList()
        val list = mutableListOf<Uri>()
        for (i in 0 until clipData.itemCount) {
            clipData.getItemAt(i)?.uri?.let { list.add(it) }
        }
        return list
    }
}
