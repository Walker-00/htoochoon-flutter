package site.kargate.test.htoochoon

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.DisplayMetrics
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Self-contained pausable screen recorder using MediaProjection + MediaRecorder.
 *
 * Supports start -> pause -> resume -> stop. MediaRecorder.pause()/resume() need
 * API 24+. This is best-effort: if MediaProjection setup throws (e.g. Android 14
 * foreground-service-type enforcement), the Dart side catches the failure and
 * falls back to the flutter_screen_recording plugin (no true pause).
 */
class ScreenRecorderManager(private val activity: Activity) {

    private var projection: MediaProjection? = null
    private var recorder: MediaRecorder? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var outputFile: File? = null
    private var lastFinishedFile: File? = null
    private var includeMic: Boolean = true

    // Result of the pending `start` MethodChannel call, completed once the user
    // grants (or denies) the screen-capture permission dialog.
    private var pendingStartResult: MethodChannel.Result? = null

    val isRecording: Boolean get() = recorder != null

    fun supported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N

    /** Kick off the permission dialog; completes [result] in [onProjectionResult]. */
    fun start(includeMic: Boolean, requestCode: Int, result: MethodChannel.Result) {
        if (recorder != null) { result.success(true); return }
        this.includeMic = includeMic
        pendingStartResult = result
        val mpm = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                as MediaProjectionManager
        activity.startActivityForResult(mpm.createScreenCaptureIntent(), requestCode)
    }

    fun onProjectionResult(resultCode: Int, data: Intent?) {
        val res = pendingStartResult
        pendingStartResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            res?.success(false)
            return
        }
        try {
            val mpm = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                    as MediaProjectionManager
            projection = mpm.getMediaProjection(resultCode, data)
            setupRecorder()
            recorder?.start()
            res?.success(true)
        } catch (e: Exception) {
            cleanup()
            res?.success(false)
        }
    }

    private fun setupRecorder() {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        activity.windowManager.defaultDisplay.getRealMetrics(metrics)
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        val dir = File(activity.cacheDir, "recordings").apply { mkdirs() }
        val out = File(dir, "live_${System.currentTimeMillis()}.mp4")
        outputFile = out

        val rec = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            MediaRecorder(activity) else @Suppress("DEPRECATION") MediaRecorder()

        if (includeMic) rec.setAudioSource(MediaRecorder.AudioSource.MIC)
        rec.setVideoSource(MediaRecorder.VideoSource.SURFACE)
        rec.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        rec.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
        if (includeMic) rec.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        rec.setVideoSize(width, height)
        rec.setVideoEncodingBitRate(8 * 1000 * 1000)
        rec.setVideoFrameRate(30)
        rec.setOutputFile(out.absolutePath)
        rec.prepare()

        virtualDisplay = projection?.createVirtualDisplay(
            "htoochoon-rec",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            rec.surface, null, null
        )
        recorder = rec
    }

    fun pause(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                recorder?.pause(); true
            } else false
        } catch (e: Exception) { false }
    }

    fun resume(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                recorder?.resume(); true
            } else false
        } catch (e: Exception) { false }
    }

    /** Stop + release; returns the finished file path (or null). */
    fun stop(): String? {
        val out = outputFile
        try {
            recorder?.stop()
        } catch (e: Exception) {
            // stop() can throw if no frames were captured — discard.
        }
        cleanup()
        lastFinishedFile = out
        return if (out != null && out.exists()) out.absolutePath else null
    }

    /** Crash recovery: the most-recent finished/temp file, if any. */
    fun recover(): String? {
        lastFinishedFile?.let { if (it.exists()) return it.absolutePath }
        outputFile?.let { if (it.exists()) return it.absolutePath }
        val dir = File(activity.cacheDir, "recordings")
        return dir.listFiles()?.maxByOrNull { it.lastModified() }?.absolutePath
    }

    private fun cleanup() {
        try { recorder?.reset() } catch (_: Exception) {}
        try { recorder?.release() } catch (_: Exception) {}
        try { virtualDisplay?.release() } catch (_: Exception) {}
        try { projection?.stop() } catch (_: Exception) {}
        recorder = null
        virtualDisplay = null
        projection = null
    }
}
