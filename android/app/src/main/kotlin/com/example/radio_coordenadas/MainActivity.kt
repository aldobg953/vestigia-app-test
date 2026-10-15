package com.example.radio_coordenadas

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val radioSynth = RadioNoiseSynth()
    private var haptics: VestigiaHaptics? = null
    private var orientation: GameOrientationSensor? = null
    private var orientationChannel: EventChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val vibration = VestigiaHaptics(applicationContext).also { haptics = it }
        orientation?.dispose()
        val pointing = GameOrientationSensor(applicationContext).also { orientation = it }
        orientationChannel = EventChannel(messenger, "vestigia/game_orientation").also {
            it.setStreamHandler(pointing)
        }

        // Canal de lib/puzzles/radio/radio_audio.dart.
        MethodChannel(messenger, "vestigia/radio_audio").setMethodCallHandler { call, result ->
            val strength = (call.argument<Double>("strength") ?: 0.0).toFloat()
            when (call.method) {
                "start" -> radioSynth.start(strength)
                "setStrength" -> radioSynth.setStrength(strength)
                "pause" -> radioSynth.pause()
                "resume" -> radioSynth.resume()
                "stop" -> radioSynth.stop()
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }
            result.success(null)
        }

        // Canal de lib/core/haptics.dart.
        MethodChannel(messenger, "vestigia/haptics").setMethodCallHandler { call, result ->
            if (call.method == "play") {
                vibration.play(call.argument<String>("cue") ?: "")
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        orientation?.dispose()
        orientationChannel?.setStreamHandler(null)
        radioSynth.stop()
        haptics?.cancel()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        orientation?.dispose()
        radioSynth.stop()
        super.onDestroy()
    }

    override fun onPause() {
        orientation?.pause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        orientation?.resume()
    }
}
