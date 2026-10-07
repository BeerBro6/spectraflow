package com.spectraflow.spectraflow

import android.content.Intent
import android.media.audiofx.AudioEffect
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.Virtualizer
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import com.ryanheise.just_audio.ReverbBridge
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val TAG = "SpectraEQ"
    private val CHANNEL = "com.spectraflow/eq"

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var currentSessionId: Int = 0

    // Cached states to re-apply immediately on session re-init or track changes
    private var cachedBands: List<Map<String, Any>> = emptyList()
    private var cachedPreamp: Double = 0.0
    private var cachedBassBoost: Double = 0.0
    private var cachedVirtualizer: Double = 0.0
    private var cachedReverbPreset: Int = 0 // 0=None, 1=Studio, 2=Live, 3=Music, 4=Party, 5=SmallHall, 6=Plate
    private var cachedReverbAmount: Float = 0.0f
    private var cachedLoudnessMb: Int = 0
    private var isEffectEnabled: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    val sessionId = call.argument<Int>("sessionId") ?: 0
                    Log.d(TAG, "MethodChannel 'init' called with sessionId=$sessionId")
                    try {
                        initEffects(sessionId)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to init effects: ${e.message}", e)
                        result.error("EQ_INIT_ERROR", e.message, null)
                    }
                }
                "applyBands" -> {
                    val bands = call.argument<List<Map<String, Any>>>("bands") ?: emptyList()
                    val preamp = (call.argument<Any>("preamp") as? Number)?.toDouble() ?: 0.0
                    val bassBoostArg = (call.argument<Any>("bassBoost") as? Number)?.toDouble()
                    val virtualizerArg = (call.argument<Any>("virtualizer") as? Number)?.toDouble()
                    val reverbPresetArg = (call.argument<Any>("reverbPreset") as? Number)?.toInt()
                    val reverbAmountArg = (call.argument<Any>("reverbAmount") as? Number)?.toFloat()
                    val loudnessMbArg = (call.argument<Any>("loudnessMb") as? Number)?.toInt()

                    Log.d(TAG, "MethodChannel 'applyBands' bands=${bands.size}, preamp=$preamp, bassBoost=$bassBoostArg, virt=$virtualizerArg, rev=$reverbPresetArg, revAmt=$reverbAmountArg, loud=$loudnessMbArg")
                    try {
                        cachedBands = bands
                        cachedPreamp = preamp
                        if (bassBoostArg != null) cachedBassBoost = bassBoostArg
                        if (virtualizerArg != null) cachedVirtualizer = virtualizerArg
                        if (reverbPresetArg != null) cachedReverbPreset = reverbPresetArg
                        if (reverbAmountArg != null) cachedReverbAmount = reverbAmountArg
                        if (loudnessMbArg != null) cachedLoudnessMb = loudnessMbArg

                        // If user applies any non-empty bands, bass boost, virtualizer, reverb, or loudness, auto-enable
                        val hasActiveParameters = bands.isNotEmpty() || preamp != 0.0 || (bassBoostArg ?: cachedBassBoost) > 0.0 ||
                            (virtualizerArg ?: cachedVirtualizer) > 0.0 || (reverbPresetArg ?: cachedReverbPreset) > 0 ||
                            (loudnessMbArg ?: cachedLoudnessMb) > 0
                        if (hasActiveParameters) {
                            isEffectEnabled = true
                        }

                        applyEffectsToNative(
                            bands = bands,
                            preamp = preamp,
                            bassBoostDb = bassBoostArg ?: cachedBassBoost,
                            virtualizerStrength = virtualizerArg ?: cachedVirtualizer,
                            reverbPreset = reverbPresetArg ?: cachedReverbPreset,
                            loudnessMb = loudnessMbArg ?: cachedLoudnessMb,
                            reverbAmount = reverbAmountArg ?: cachedReverbAmount
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to apply bands/effects: ${e.message}", e)
                        result.error("EQ_APPLY_ERROR", e.message, null)
                    }
                }
                "setReverbAmount" -> {
                    val amount = (call.argument<Any>("amount") as? Number)?.toFloat() ?: 0.0f
                    Log.d(TAG, "MethodChannel 'setReverbAmount' called with amount=$amount")
                    try {
                        cachedReverbAmount = amount
                        val effectiveAmount = if (isEffectEnabled && cachedReverbPreset > 0) amount else 0.0f
                        ReverbBridge.setAmount(effectiveAmount)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to set reverb amount: ${e.message}", e)
                        result.error("REVERB_AMOUNT_ERROR", e.message, null)
                    }
                }
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    Log.d(TAG, "MethodChannel 'setEnabled' called with enabled=$enabled")
                    try {
                        isEffectEnabled = enabled
                        equalizer?.enabled = enabled && (cachedBands.isNotEmpty() || cachedPreamp != 0.0)
                        bassBoost?.enabled = enabled && cachedBassBoost > 0
                        virtualizer?.enabled = enabled && cachedVirtualizer > 0
                        loudnessEnhancer?.enabled = enabled && cachedLoudnessMb > 0
                        // In-Engine Software DSP Reverb
                        val effectiveReverb = if (enabled) cachedReverbPreset else 0
                        val effectiveAmount = if (enabled && effectiveReverb > 0) cachedReverbAmount else 0.0f
                        ReverbBridge.setPreset(effectiveReverb)
                        ReverbBridge.setAmount(effectiveAmount)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to set enabled: ${e.message}", e)
                        result.error("EQ_ENABLE_ERROR", e.message, null)
                    }
                }
                "reset" -> {
                    Log.d(TAG, "MethodChannel 'reset' called")
                    try {
                        resetNative()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to reset native effects: ${e.message}", e)
                        result.error("EQ_RESET_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initEffects(sessionId: Int) {
        if (currentSessionId == sessionId && equalizer != null) {
            Log.d(TAG, "Session $sessionId already initialized, re-applying cached parameters.")
            applyEffectsToNative(cachedBands, cachedPreamp, cachedBassBoost, cachedVirtualizer, cachedReverbPreset, cachedLoudnessMb, cachedReverbAmount)
            return
        }

        releaseEffects()
        currentSessionId = sessionId
        Log.i(TAG, "Initializing hardware DSP chain (EQ, BassBoost, Virtualizer, Loudness) for Session: $sessionId")

        try {
            equalizer = Equalizer(1000, sessionId).apply {
                enabled = isEffectEnabled && (cachedBands.isNotEmpty() || cachedPreamp != 0.0)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Equalizer(1000) failed, fallback to 0: ${e.message}")
            try {
                equalizer = Equalizer(0, sessionId).apply {
                    enabled = isEffectEnabled && (cachedBands.isNotEmpty() || cachedPreamp != 0.0)
                }
            } catch (_: Exception) {}
        }

        try {
            bassBoost = BassBoost(1000, sessionId).apply {
                enabled = isEffectEnabled && cachedBassBoost > 0
            }
        } catch (e: Exception) {
            Log.w(TAG, "BassBoost(1000) failed, fallback to 0: ${e.message}")
            try {
                bassBoost = BassBoost(0, sessionId).apply {
                    enabled = isEffectEnabled && cachedBassBoost > 0
                }
            } catch (_: Exception) {}
        }

        try {
            virtualizer = Virtualizer(1000, sessionId).apply {
                enabled = isEffectEnabled && cachedVirtualizer > 0
            }
        } catch (e: Exception) {
            Log.w(TAG, "Virtualizer(1000) failed, fallback to 0: ${e.message}")
            try {
                virtualizer = Virtualizer(0, sessionId).apply {
                    enabled = isEffectEnabled && cachedVirtualizer > 0
                }
            } catch (_: Exception) {}
        }

        try {
            loudnessEnhancer = LoudnessEnhancer(sessionId).apply {
                enabled = isEffectEnabled && cachedLoudnessMb > 0
            }
        } catch (e: Exception) {
            Log.w(TAG, "LoudnessEnhancer failed: ${e.message}")
        }

        Log.i(TAG, "Hardware DSP chain ready. EQ=${equalizer != null}, Bass=${bassBoost != null}, Virt=${virtualizer != null}, Loudness=${loudnessEnhancer != null}")

        applyEffectsToNative(cachedBands, cachedPreamp, cachedBassBoost, cachedVirtualizer, cachedReverbPreset, cachedLoudnessMb, cachedReverbAmount)
    }

    private fun applyEffectsToNative(
        bands: List<Map<String, Any>>,
        preamp: Double,
        bassBoostDb: Double = 0.0,
        virtualizerStrength: Double = 0.0,
        reverbPreset: Int = 0,
        loudnessMb: Int = 0,
        reverbAmount: Float = cachedReverbAmount
    ) {
        // 1. Equalizer Bands — logarithmic Gaussian interpolation across hardware bands
        val eq = equalizer
        if (eq != null) {
            val numBands = eq.numberOfBands.toInt()
            val bandRange = eq.bandLevelRange
            val minLevel = bandRange[0].toInt()
            val maxLevel = bandRange[1].toInt()

            if (bands.isEmpty() && preamp == 0.0) {
                for (i in 0 until numBands) eq.setBandLevel(i.toShort(), 0)
                eq.enabled = false
            } else if (bands.isEmpty()) {
                val millibels = (preamp * 100).toInt().coerceIn(minLevel, maxLevel)
                for (i in 0 until numBands) eq.setBandLevel(i.toShort(), millibels.toShort())
                eq.enabled = isEffectEnabled
            } else {
                for (i in 0 until numBands) {
                    val centerFreqHz = (eq.getCenterFreq(i.toShort()) / 1000).toDouble().coerceAtLeast(20.0)
                    var weightedGainSum = 0.0
                    var totalWeight = 0.0

                    for (bandMap in bands) {
                        val freq = (bandMap["frequency"] as? Number)?.toDouble()
                            ?: (bandMap["freqHz"] as? Number)?.toDouble()
                            ?: continue
                        val gain = (bandMap["gain"] as? Number)?.toDouble()
                            ?: (bandMap["gainDb"] as? Number)?.toDouble()
                            ?: 0.0
                        if (freq <= 0.0) continue

                        val octDiff = kotlin.math.ln(freq / centerFreqHz) / kotlin.math.ln(2.0)
                        val weight = kotlin.math.exp(-0.5 * (octDiff * octDiff) / (0.75 * 0.75))
                        weightedGainSum += gain * weight
                        totalWeight += weight
                    }

                    val interpolatedGain = if (totalWeight > 0.001) weightedGainSum / totalWeight else 0.0
                    val totalDb = interpolatedGain + preamp
                    val millibels = (totalDb * 100).toInt().coerceIn(minLevel, maxLevel)
                    eq.setBandLevel(i.toShort(), millibels.toShort())
                    Log.d(TAG, "Band $i (${centerFreqHz.toInt()} Hz) = $millibels mB")
                }
                eq.enabled = isEffectEnabled
            }
        }

        // 2. Hardware BassBoost
        bassBoost?.let {
            val strength = ((bassBoostDb.coerceIn(0.0, 15.0) / 12.0) * 1000).toInt().coerceIn(0, 1000)
            if (strength > 0 && isEffectEnabled) {
                it.enabled = true
                it.setStrength(strength.toShort())
                Log.d(TAG, "BassBoost strength=$strength")
            } else {
                it.setStrength(0)
                it.enabled = false
            }
        }

        // 3. Stereo Virtualizer / Spatializer
        virtualizer?.let {
            val strength = (virtualizerStrength.coerceIn(0.0, 1.0) * 1000).toInt().coerceIn(0, 1000)
            if (strength > 0 && isEffectEnabled) {
                it.enabled = true
                it.setStrength(strength.toShort())
                Log.d(TAG, "Virtualizer strength=$strength")
            } else {
                it.setStrength(0)
                it.enabled = false
            }
        }

        // 4. Acoustic Reverb — Pure In-Engine Software DSP (Schroeder-Freeverb)
        // Directly processes 16-bit PCM inside ExoPlayer AudioSink with zero OEM dependency.
        val effectiveReverb = if (isEffectEnabled) reverbPreset else 0
        val effectiveAmount = if (isEffectEnabled && effectiveReverb > 0) reverbAmount else 0.0f
        ReverbBridge.setPreset(effectiveReverb)
        ReverbBridge.setAmount(effectiveAmount)
        Log.d(TAG, "In-Engine ReverbBridge preset set to $effectiveReverb, amount=$effectiveAmount (isEffectEnabled=$isEffectEnabled)")

        // 5. Loudness Enhancer
        loudnessEnhancer?.let {
            if (loudnessMb > 0 && isEffectEnabled) {
                it.enabled = true
                it.setTargetGain(loudnessMb.coerceIn(0, 1200))
                Log.d(TAG, "LoudnessEnhancer=$loudnessMb mB")
            } else {
                it.setTargetGain(0)
                it.enabled = false
            }
        }

        Log.d(TAG, "DSP chain applied. Session=$currentSessionId")
    }

    private fun resetNative() {
        cachedBands = emptyList()
        cachedPreamp = 0.0
        cachedBassBoost = 0.0
        cachedVirtualizer = 0.0
        cachedReverbPreset = 0
        cachedReverbAmount = 0.0f
        cachedLoudnessMb = 0
        isEffectEnabled = false

        equalizer?.let {
            val numBands = it.numberOfBands.toInt()
            for (i in 0 until numBands) it.setBandLevel(i.toShort(), 0)
            it.enabled = false
        }
        bassBoost?.let { it.setStrength(0); it.enabled = false }
        virtualizer?.let { it.setStrength(0); it.enabled = false }
        loudnessEnhancer?.let { it.setTargetGain(0); it.enabled = false }
        ReverbBridge.setPreset(0)
        ReverbBridge.setAmount(0.0f)

        Log.d(TAG, "DSP chain reset to flat/off.")
    }

    private fun releaseEffects() {
        try { equalizer?.release() } catch (_: Exception) {}
        try { bassBoost?.release() } catch (_: Exception) {}
        try { virtualizer?.release() } catch (_: Exception) {}
        try { loudnessEnhancer?.release() } catch (_: Exception) {}
        ReverbBridge.setPreset(0)
        ReverbBridge.setAmount(0.0f)

        equalizer = null
        bassBoost = null
        virtualizer = null
        loudnessEnhancer = null
    }

    override fun onDestroy() {
        releaseEffects()
        super.onDestroy()
    }
}
