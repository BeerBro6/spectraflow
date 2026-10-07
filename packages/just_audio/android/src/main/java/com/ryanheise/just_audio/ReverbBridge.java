package com.ryanheise.just_audio;

/**
 * Lightweight bridge for communicating preset changes to ReverbAudioProcessor
 * without requiring the calling module (MainActivity) to import or link against Media3 classes.
 */
public final class ReverbBridge {
    private ReverbBridge() {}

    public static void setPreset(int preset) {
        ReverbAudioProcessor.setPreset(preset);
    }

    public static void setAmount(float amount) {
        ReverbAudioProcessor.setAmount(amount);
    }
}
