package com.example.radio_coordenadas

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sin

/**
 * Sintetiza en tiempo real el sonido de la radio antigua.
 *
 * Con intensidad 0 solo hay estática con chasquidos; al acercarse a la
 * señal el ruido baja y aparece un tono pulsante cuya altura se estabiliza
 * al llegar a la franja (intensidad 1). La intensidad la calcula Dart con la
 * misma lógica que dibuja la ventana.
 */
class RadioNoiseSynth {
    private val sampleRate = 22050
    private val lock = Object()

    @Volatile private var targetStrength = 0f
    @Volatile private var running = false
    @Volatile private var paused = false

    private var track: AudioTrack? = null
    private var thread: Thread? = null

    // Estado del generador; solo lo usa el hilo de audio.
    private var strength = 0f
    private var seed = 0x2545F491
    private var lowPass = 0f
    private var crackle = 0f
    private var tonePhase = 0.0
    private var toneFreq = 900.0
    private var time = 0.0

    fun start(initialStrength: Float) {
        stop()
        targetStrength = initialStrength.coerceIn(0f, 1f)
        strength = targetStrength

        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(max(minBuffer, sampleRate / 10 * 2))
            .build()

        track = audioTrack
        running = true
        paused = false
        audioTrack.play()
        thread = Thread({ renderLoop(audioTrack) }, "vestigia-radio-audio").also { it.start() }
    }

    fun setStrength(value: Float) {
        targetStrength = value.coerceIn(0f, 1f)
    }

    fun pause() {
        val audioTrack = track ?: return
        synchronized(lock) { paused = true }
        audioTrack.pause()
        audioTrack.flush()
    }

    fun resume() {
        val audioTrack = track ?: return
        audioTrack.play()
        synchronized(lock) {
            paused = false
            lock.notifyAll()
        }
    }

    /** Detiene el sonido y libera el [AudioTrack]. Se puede llamar varias veces. */
    fun stop() {
        val audioTrack = track ?: return
        synchronized(lock) {
            running = false
            lock.notifyAll()
        }
        try {
            audioTrack.pause()
            audioTrack.flush()
            audioTrack.stop()
        } catch (e: IllegalStateException) {
            // La pista ya estaba detenida.
        }
        thread?.join(500)
        thread = null
        audioTrack.release()
        track = null
    }

    private fun renderLoop(audioTrack: AudioTrack) {
        val buffer = ShortArray(512)
        while (true) {
            synchronized(lock) {
                while (paused && running) lock.wait()
            }
            if (!running) break
            for (i in buffer.indices) {
                buffer[i] = (nextSample() * Short.MAX_VALUE).toInt().toShort()
            }
            if (audioTrack.write(buffer, 0, buffer.size) < 0) break
        }
    }

    private fun nextSample(): Float {
        // Suavizado (~30 ms) para que la perilla no produzca saltos audibles.
        strength += (targetStrength - strength) * 0.0015f
        val s = strength
        val dt = 1.0 / sampleRate
        time += dt

        // Estática: ruido blanco filtrado con un leve vaivén de volumen.
        val white = nextRandom()
        lowPass += 0.35f * (white - lowPass)
        val flutter = 0.8f + 0.2f * sin(2 * PI * 0.7 * time).toFloat()
        val hiss = (lowPass * 0.8f + white * 0.2f) * flutter

        // Chasquidos esporádicos, más frecuentes lejos de la señal.
        if (abs(nextRandom()) < 0.00025f * (1 - s) + 0.00002f) {
            crackle = nextRandom() * 0.9f
        }
        crackle *= 0.86f

        val noiseGain = 0.05f + 0.55f * (1 - s).pow(1.3f)
        val noise = (hiss + crackle) * noiseGain

        // Señal: tono que baja hasta 520 Hz conforme se afina y late a 2.5 Hz.
        val targetFreq = 520.0 + 700.0 * (1 - s)
        toneFreq += (targetFreq - toneFreq) * 0.002
        tonePhase += 2 * PI * toneFreq * dt
        if (tonePhase > 2 * PI) tonePhase -= 2 * PI
        val warble = 1 - (1 - s) * 0.5f * (0.5f + 0.5f * sin(2 * PI * 6 * time).toFloat())
        val beacon = 0.55f + 0.45f * (0.5f + 0.5f * sin(2 * PI * 2.5 * time).toFloat())
        val tone = (sin(tonePhase) * 0.75 + sin(2 * tonePhase) * 0.2).toFloat()
        val signalGain = 0.42f * s.pow(1.6f)
        val signal = tone * warble * beacon * signalGain

        return softClip((noise + signal) * 0.85f)
    }

    private fun softClip(x: Float): Float = when {
        x > 1f -> 1f
        x < -1f -> -1f
        else -> x * (1.5f - 0.5f * x * x)
    }

    /** Xorshift: rápido y sin sincronización, en -1..1. */
    private fun nextRandom(): Float {
        var x = seed
        x = x xor (x shl 13)
        x = x xor (x ushr 17)
        x = x xor (x shl 5)
        seed = x
        return (x.toFloat() / Int.MAX_VALUE.toFloat()).coerceIn(-1f, 1f)
    }
}
