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

class MetronomePlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var soundPool: SoundPool? = null
    private val soundIds = mutableMapOf<Int, Int>()
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.songkey/metronome")
        channel?.setMethodCallHandler(this)
        activity = binding.applicationContext as? Activity
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
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
            "play" -> {
                val slot = call.argument<Int>("slot") ?: 0
                val volume = call.argument<Double>("volume")?.toFloat() ?: 1f
                playSound(slot, volume, result)
            }
            "dispose" -> {
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

    private fun playSound(slot: Int, volume: Float, result: Result) {
        val soundId = soundIds[slot]
        if (soundId == null || soundPool == null) {
            result.error("NOT_READY", "SoundPool not prepared or sound not loaded", null)
            return
        }
        // Stream type 0 = no loop, priority 1, rate 1f
        val streamId = soundPool!!.play(soundId, volume, volume, 1, 0, 1f)
        result.success(streamId > 0)
    }

    private fun release() {
        soundPool?.release()
        soundPool = null
        soundIds.clear()
    }
}