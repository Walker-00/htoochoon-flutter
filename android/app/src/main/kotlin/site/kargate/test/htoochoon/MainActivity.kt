package site.kargate.test.htoochoon

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "exam_guard/vpn"
    private val eventChannelName = "exam_guard/vpn_state"
    private val vpnRequestCode = 0xC0DE

    private val recordingChannelName = "htoochoon/recording"
    private val recRequestCode = 0xAEC0

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPrepareResult: MethodChannel.Result? = null
    private var recorder: ScreenRecorderManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(true)
                "isActive" -> result.success(ExamGuardVpnService.isRunning)
                "prepare" -> {
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        pendingPrepareResult = result
                        startActivityForResult(intent, vpnRequestCode)
                    } else {
                        result.success(true)
                    }
                }
                "start" -> {
                    val i = Intent(this, ExamGuardVpnService::class.java)
                        .setAction(ExamGuardVpnService.ACTION_START)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(i)
                    } else {
                        startService(i)
                    }
                    result.success(true)
                }
                "stop" -> {
                    val i = Intent(this, ExamGuardVpnService::class.java)
                        .setAction(ExamGuardVpnService.ACTION_STOP)
                    startService(i)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 🎥 Pausable local screen recorder.
        recorder = ScreenRecorderManager(this)
        MethodChannel(messenger, recordingChannelName).setMethodCallHandler { call, result ->
            val rec = recorder ?: ScreenRecorderManager(this).also { recorder = it }
            when (call.method) {
                "isSupported" -> result.success(rec.supported())
                "start" -> {
                    val includeMic = call.argument<Boolean>("includeMic") ?: true
                    rec.start(includeMic, recRequestCode, result)
                }
                "pause" -> result.success(rec.pause())
                "resume" -> result.success(rec.resume())
                "stop" -> result.success(rec.stop())
                "recover" -> result.success(rec.recover())
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    ExamGuardVpnService.stateListener = { state ->
                        runOnUiThread { eventSink?.success(state) }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    ExamGuardVpnService.stateListener = null
                }
            },
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == vpnRequestCode) {
            pendingPrepareResult?.success(resultCode == Activity.RESULT_OK)
            pendingPrepareResult = null
        } else if (requestCode == recRequestCode) {
            recorder?.onProjectionResult(resultCode, data)
        }
    }
}
