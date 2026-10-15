package com.example.radio_coordenadas

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.hypot

class GameOrientationSensor(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor = manager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
    private val matrix = FloatArray(9)
    private var sink: EventChannel.EventSink? = null
    private var registered = false
    private var lastHeading = 0.0

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        resume()
    }

    override fun onCancel(arguments: Any?) {
        pause()
        sink = null
    }

    fun resume() {
        if (sink == null || registered) return
        if (sensor == null || !manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)) {
            sink?.error("sensor_unavailable", "Game rotation vector is unavailable", null)
            return
        }
        registered = true
    }

    fun pause() {
        manager.unregisterListener(this)
        registered = false
    }

    fun dispose() {
        pause()
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        SensorManager.getRotationMatrixFromVector(matrix, event.values)
        // The rear camera (-Z of the device) is the instrument's pointing axis.
        val east = -matrix[2].toDouble()
        val north = -matrix[5].toDouble()
        val up = -matrix[8].toDouble()
        if (hypot(east, north) > 0.001) {
            lastHeading = (Math.toDegrees(atan2(east, north)) + 360.0) % 360.0
        }
        sink?.success(mapOf(
            "azimuth" to lastHeading,
            "altitude" to Math.toDegrees(asin(up.coerceIn(-1.0, 1.0)))
        ))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
