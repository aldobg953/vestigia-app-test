package com.example.radio_coordenadas

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.VibrationEffect.Composition
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Patrones de vibración de los puzzles. Los nombres coinciden con
 * `HapticCue` en lib/core/haptics.dart.
 *
 * Todo se construye con clics cortos y secos: primero con primitivas
 * (Android 11+, si el motor las soporta), después con efectos predefinidos
 * y, como último recurso, con pulsos muy breves a intensidad alta.
 *
 * En motores lineales (eje X) un clic a baja intensidad se siente blando,
 * así que incluso las muescas de la perilla van casi a intensidad completa.
 */
class VestigiaHaptics(context: Context) {
    private val vibrator: Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    init {
        val v = vibrator
        val primitives = v != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            v.areAllPrimitivesSupported(Composition.PRIMITIVE_CLICK)
        Log.i(
            "VestigiaHaptics",
            "vibrador=${v?.hasVibrator()} amplitud=${v?.hasAmplitudeControl()} " +
                "primitivaClick=$primitives sdk=${Build.VERSION.SDK_INT}",
        )
    }

    /** Un clic: intensidad (0..1) y espera previa en milisegundos. */
    private class Click(val scale: Float, val delayMs: Int = 0)

    fun play(cue: String) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        when (cue) {
            // Muesca de la perilla: clic corto y firme, como un trinquete.
            "tick" -> clicks(v, listOf(Click(TICK_SCALE))) ||
                predefined(v, VibrationEffect.EFFECT_CLICK) ||
                pulses(v, listOf(Click(1f)), pulseMs = 5)
            // Tope: “clac” doble a intensidad completa.
            "limit" -> clicks(v, listOf(Click(1f), Click(1f, 28))) ||
                predefined(v, VibrationEffect.EFFECT_DOUBLE_CLICK) ||
                pulses(v, listOf(Click(1f), Click(1f, 28)), pulseMs = 8)
            // Señal encontrada: doble clic rápido.
            "signalFound" -> playClicks(v, listOf(Click(1f), Click(1f, 70)))
            // Dígito captado: tres clics ascendentes.
            "capture" -> playClicks(v, listOf(Click(0.8f), Click(0.9f, 60), Click(1f, 60)))
            // Coordenada completa: ráfaga que acelera y remata.
            "complete" -> playClicks(
                v,
                listOf(
                    Click(0.75f), Click(0.8f, 90), Click(0.85f, 70),
                    Click(0.9f, 50), Click(1f, 40), Click(1f, 160),
                ),
            )
            // Fotografía completa: doble clic breve.
            "photoSolved" -> clicks(v, listOf(Click(1f), Click(1f, 80))) ||
                predefined(v, VibrationEffect.EFFECT_DOUBLE_CLICK) ||
                pulses(v, listOf(Click(1f), Click(1f, 80)), pulseMs = 10)
        }
    }

    private companion object {
        /** Intensidad de las muescas de la perilla (0..1). */
        const val TICK_SCALE = 0.9f
    }

    fun cancel() {
        vibrator?.cancel()
    }

    private fun playClicks(v: Vibrator, pattern: List<Click>) {
        clicks(v, pattern) || pulses(v, pattern, pulseMs = 10)
    }

    /** Primitivas de Android 11+: los clics más nítidos que ofrece el motor. */
    private fun clicks(
        v: Vibrator,
        pattern: List<Click>,
    ): Boolean {
        val primitive = Composition.PRIMITIVE_CLICK
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        if (!v.areAllPrimitivesSupported(primitive)) return false
        val composition = VibrationEffect.startComposition()
        for (click in pattern) composition.addPrimitive(primitive, click.scale, click.delayMs)
        v.vibrate(composition.compose())
        return true
    }

    private fun predefined(v: Vibrator, effect: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        v.vibrate(VibrationEffect.createPredefined(effect))
        return true
    }

    /** Pulsos muy cortos a intensidad alta: más secos que uno largo y suave. */
    private fun pulses(v: Vibrator, pattern: List<Click>, pulseMs: Long): Boolean {
        val timings = mutableListOf<Long>()
        val amplitudes = mutableListOf<Int>()
        for (click in pattern) {
            timings += click.delayMs.toLong()
            amplitudes += 0
            timings += pulseMs
            amplitudes += (155 + 100 * click.scale).toInt().coerceIn(1, 255)
        }
        if (v.hasAmplitudeControl()) {
            v.vibrate(VibrationEffect.createWaveform(timings.toLongArray(), amplitudes.toIntArray(), -1))
        } else {
            v.vibrate(VibrationEffect.createWaveform(timings.toLongArray(), -1))
        }
        return true
    }
}
