package com.example.songkey

import android.app.Activity
import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.os.Environment
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import kotlin.concurrent.thread

class MetronomePlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var soundPool: SoundPool? = null
    private val soundIds = mutableMapOf<Int, Int>()
    private var activity: Activity? = null

    // Loop de tiempo en hilo dedicado
    private var metroThread: Thread? = null
    @Volatile private var running = false
    @Volatile private var shouldStop = false
    private var currentBpm = 120
    private var currentBeatsPerBar = 4
    private var currentSubdivision = 1 // 1 = negra, 2 = corchea
    private var currentTimbre = 0 // 0=click, 1=bip, 2=caja, 3=campana
    private var currentAccent = true
    private var currentSoundOn = true

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.songkey/metronome")
        channel?.setMethodCallHandler(this)
        activity = binding.applicationContext as? Activity
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopMetronome()
        channel?.setMethodCallHandler(null)
        channel = null
        release()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "prepare" -> {
                val sounds = call.argument<Map<String, ByteArray>>("sounds") ?: emptyMap()
                prepareSoundPool(sounds, result)
            }
            "start" -> {
                currentBpm = call.argument<Int>("bpm") ?: 120
                currentBeatsPerBar = call.argument<Int>("beatsPerBar") ?: 4
                currentSubdivision = call.argument<Int>("subdivision") ?: 1
                currentTimbre = call.argument<Int>("timbre") ?: 0
                currentAccent = call.argument<Boolean>("accent") ?: true
                currentSoundOn = call.argument<Boolean>("soundOn") ?: true
                startMetronome(result)
            }
            "stop" -> {
                stopMetronome()
                result.success(true)
            }
            "updateSettings" -> {
                currentBpm = call.argument<Int>("bpm") ?: currentBpm
                currentBeatsPerBar = call.argument<Int>("beatsPerBar") ?: currentBeatsPerBar
                currentSubdivision = call.argument<Int>("subdivision") ?: currentSubdivision
                currentTimbre = call.argument<Int>("timbre") ?: currentTimbre
                currentAccent = call.argument<Boolean>("accent") ?: currentAccent
                currentSoundOn = call.argument<Boolean>("soundOn") ?: currentSoundOn
                result.success(true)
            }
            "dispose" -> {
                stopMetronome()
                release()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun prepareSoundPool(sounds: Map<String, ByteArray>, result: Result) {
        release()

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        soundPool = SoundPool.Builder()
            .setMaxStreams(8)
            .setAudioAttributes(attrs)
            .build()

        val cacheDir = activity?.cacheDir ?: Environment.getDataDirectory()

        sounds.forEach { (slotStr, bytes) ->
            val slot = slotStr.toIntOrNull() ?: return@forEach
            val file = File(cacheDir, "metro_$slot.wav")
            try {
                FileOutputStream(file).use { it.write(bytes) }
                val soundId = soundPool!!.load(file.absolutePath, 1)
                soundIds[slot] = soundId
            } catch (e: Exception) {
                result.error("SOUND_ERROR", "Failed to load sound $slot", e.message)
                return
            }
        }
        result.success(true)
    }

    private fun startMetronome(result: Result) {
        if (running) {
            result.success(true)
            return
        }
        if (soundPool == null || soundIds.isEmpty()) {
            result.error("NOT_READY", "SoundPool not prepared", null)
            return
        }

        running = true
        shouldStop = false

        metroThread = thread(start = true, name = "MetronomeThread", isDaemon = true) {
            runMetronomeLoop()
        }
        result.success(true)
    }

    private fun stopMetronome() {
        shouldStop = true
        metroThread?.interrupt()
        metroThread = null
        running = false
    }

    private fun runMetronomeLoop() {
        // Calcular intervalo en nanosegundos
        val clicksPerBeat = currentSubdivision
        val intervalNanos = (60_000_000_000.0 / currentBpm / clicksPerBeat).toLong()

        var nextTime = System.nanoTime()
        var clickCount = 0L

        while (!shouldStop) {
            val now = System.nanoTime()

            // Si llegamos tarde, no acumulamos el retraso: saltamos al siguiente tiempo absoluto
            if (now > nextTime + intervalNanos) {
                // Ajustar al múltiplo más cercano hacia adelante
                val elapsed = now - nextTime
                val skipped = (elapsed / intervalNanos) + 1
                nextTime += skipped * intervalNanos
                clickCount += skipped
            }

            // Disparar click si hay sonido activado
            if (currentSoundOn) {
                val clicksPerBeatLocal = currentSubdivision.toLong()
                val beatsPerBarLocal = currentBeatsPerBar.toLong()
                val enPulso = clickCount % clicksPerBeatLocal == 0L
                val pulso = clickCount / clicksPerBeatLocal
                val beat = pulso % beatsPerBarLocal
                val acento = enPulso && currentAccent && beat == 0L

                val slot = if (acento) currentTimbre + 4 else currentTimbre
                val volume = if (acento) 1.0f else 0.75f

                val soundId = soundIds[slot]
                soundPool?.let { pool ->
                    if (soundId != null) {
                        pool.play(soundId, volume, volume, 1, 0, 1f)
                    }
                }

                // Notificar a Dart para el indicador visual (beat, acento)
                channel?.invokeMethod("onBeat", {
                    "beat" to beat.toInt()
                    "accent" to acento
                })
            }

            clickCount++
            nextTime += intervalNanos

            // Dormir hasta el siguiente tiempo absoluto
            val sleepTime = nextTime - System.nanoTime()
            if (sleepTime > 0) {
                try {
                    Thread.sleep(sleepTime / 1_000_000, (sleepTime % 1_000_000).toInt())
                } catch (e: InterruptedException) {
                    if (shouldStop) break
                }
            }
        }
    }

    private fun release() {
        soundPool?.release()
        soundPool = null
        soundIds.clear()
    }
}