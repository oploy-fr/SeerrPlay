package app.seerrplay.client

import android.content.Context
import androidx.mediarouter.app.MediaRouteChooserDialogFragment
import androidx.mediarouter.media.MediaRouteSelector
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.SessionProvider
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "seerrplay/cast")
        CastCoordinator.attach(this, channel)
        channel.setMethodCallHandler { call, result ->
            CastCoordinator.handle(call, result)
        }
    }

    override fun onDestroy() {
        CastCoordinator.detach()
        super.onDestroy()
    }
}

class CastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context): CastOptions =
        CastOptions.Builder()
            .setReceiverApplicationId(CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID)
            .build()

    override fun getAdditionalSessionProviders(context: Context): List<SessionProvider>? = null
}

private data class PendingCastMedia(
    val url: String,
    val title: String,
    val contentType: String,
    val positionMs: Long,
)

private object CastCoordinator : SessionManagerListener<CastSession> {
    private var castContext: CastContext? = null
    private var activity: MainActivity? = null
    private var channel: MethodChannel? = null
    private var pendingMedia: PendingCastMedia? = null
    private var loadedUrl: String? = null
    fun attach(context: MainActivity, methodChannel: MethodChannel) {
        activity = context
        channel = methodChannel
        castContext = try {
            CastContext.getSharedInstance(context).also {
                it.sessionManager.addSessionManagerListener(this, CastSession::class.java)
            }
        } catch (_: RuntimeException) {
            // Cast is optional. Devices without Google Play services must still
            // be able to launch the app and use local playback normally.
            null
        }
    }

    fun detach() {
        castContext?.sessionManager?.removeSessionManagerListener(this, CastSession::class.java)
        castContext = null
        activity = null
        channel = null
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                val url = call.argument<String>("url")
                val title = call.argument<String>("title")
                val contentType = call.argument<String>("contentType")
                if (url == null || title == null || contentType == null) {
                    result.error("invalid_media", "Incomplete Cast media information", null)
                    return
                }
                pendingMedia = PendingCastMedia(
                    url = url,
                    title = title,
                    contentType = contentType,
                    positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L,
                )
                loadPendingMediaIfNeeded()
                result.success(null)
            }
            "play" -> {
                castContext?.sessionManager?.currentCastSession?.remoteMediaClient?.play()
                result.success(null)
            }
            "pause" -> {
                castContext?.sessionManager?.currentCastSession?.remoteMediaClient?.pause()
                result.success(null)
            }
            "seek" -> {
                val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                castContext?.sessionManager?.currentCastSession?.remoteMediaClient?.seek(positionMs)
                result.success(null)
            }
            "stop" -> {
                castContext?.sessionManager?.currentCastSession?.remoteMediaClient?.stop()
                result.success(null)
            }
            "volume" -> {
                val volume = call.argument<Number>("volume")?.toDouble() ?: 1.0
                castContext?.sessionManager?.currentCastSession?.volume = volume
                result.success(null)
            }
            "showRouteChooser" -> {
                val currentActivity = activity
                if (currentActivity == null || castContext == null) {
                    result.error(
                        "cast_dialog_unavailable",
                        "The Google Cast device selector is unavailable.",
                        null,
                    )
                } else {
                    val fragmentManager = currentActivity.supportFragmentManager
                    val tag = "seerrplay:cast-route-chooser"
                    if (fragmentManager.findFragmentByTag(tag) == null) {
                        val selector = MediaRouteSelector.Builder()
                            .addControlCategory(
                                CastMediaControlIntent.categoryForCast(
                                    CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID,
                                ),
                            )
                            .build()
                        MediaRouteChooserDialogFragment().apply {
                            routeSelector = selector
                        }.show(fragmentManager, tag)
                    }
                    result.success(true)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun loadPendingMediaIfNeeded() {
        val media = pendingMedia ?: return
        val session = castContext?.sessionManager?.currentCastSession ?: return
        val remoteClient = session.remoteMediaClient ?: return
        if (loadedUrl == media.url && remoteClient.hasMediaSession()) return

        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
            putString(MediaMetadata.KEY_TITLE, media.title)
        }
        val mediaInfo = MediaInfo.Builder(media.url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(media.contentType)
            .setMetadata(metadata)
            .build()
        remoteClient.load(
            MediaLoadRequestData.Builder()
                .setMediaInfo(mediaInfo)
                .setAutoplay(true)
                .setCurrentTime(media.positionMs)
                .build(),
        )
        loadedUrl = media.url
        remoteClient.registerCallback(remoteMediaCallback)
        channel?.invokeMethod(
            "castConnected",
            mapOf("deviceName" to session.castDevice?.friendlyName),
        )
    }

    override fun onSessionStarted(session: CastSession, sessionId: String) {
        loadedUrl = null
        loadPendingMediaIfNeeded()
    }

    override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) {
        loadPendingMediaIfNeeded()
    }

    override fun onSessionEnded(session: CastSession, error: Int) {
        session.remoteMediaClient?.unregisterCallback(remoteMediaCallback)
        loadedUrl = null
        channel?.invokeMethod("castDisconnected", null)
    }

    override fun onSessionStarting(session: CastSession) = Unit
    override fun onSessionStartFailed(session: CastSession, error: Int) = Unit
    override fun onSessionEnding(session: CastSession) = Unit
    override fun onSessionResuming(session: CastSession, sessionId: String) = Unit
    override fun onSessionResumeFailed(session: CastSession, error: Int) = Unit
    override fun onSessionSuspended(session: CastSession, reason: Int) = Unit

    private val remoteMediaCallback = object : RemoteMediaClient.Callback() {
        override fun onStatusUpdated() {
            val remoteClient = castContext
                ?.sessionManager
                ?.currentCastSession
                ?.remoteMediaClient ?: return
            channel?.invokeMethod(
                "castStatus",
                mapOf(
                    "playing" to (remoteClient.playerState == MediaStatus.PLAYER_STATE_PLAYING),
                    "positionMs" to remoteClient.approximateStreamPosition,
                ),
            )
        }
    }
}
