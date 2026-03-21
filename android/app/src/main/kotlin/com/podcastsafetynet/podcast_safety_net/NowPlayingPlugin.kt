package com.podcastsafetynet.podcast_safety_net

import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channel: com.podcasts.safetynet/nowplaying → getNowPlaying
 * Requires active media sessions (e.g. Spotify, Apple Music). On some devices
 * [MediaSessionManager.getActiveSessions] needs notification listener permission.
 */
object NowPlayingPlugin {
    private const val CHANNEL_NAME = "com.podcasts.safetynet/nowplaying"

    fun register(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            if (call.method == "getNowPlaying") {
                handleGetNowPlaying(context, result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun handleGetNowPlaying(context: Context, result: MethodChannel.Result) {
        try {
            val manager =
                context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager

            val sessions: List<MediaController> = try {
                manager.getActiveSessions(null)
            } catch (e: SecurityException) {
                result.success(null)
                return
            }

            if (sessions.isEmpty()) {
                result.success(null)
                return
            }

            val controller = sessions[0]
            val meta = controller.metadata
            val state = controller.playbackState

            if (meta == null) {
                result.success(null)
                return
            }

            val isPlaying = state?.state == PlaybackState.STATE_PLAYING
            if (!isPlaying) {
                result.success(null)
                return
            }

            val title = meta.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""
            val artist = meta.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: ""
            val position = ((state?.position ?: 0L) / 1000L).toInt()

            result.success(
                mapOf(
                    "title" to title,
                    "artist" to artist,
                    "position" to position,
                    "isPlaying" to isPlaying
                )
            )
        } catch (e: Exception) {
            result.success(null)
        }
    }
}
