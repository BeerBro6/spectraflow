import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../services/spectra_dac_service.dart';
import '../services/eq_bridge.dart' as eq_bridge;
import '../theme/theme.dart';
import '../widgets/liquid_glass.dart';

class SpectraDacScreen extends StatefulWidget {
  final AudioPlayerService? playerService;

  const SpectraDacScreen({super.key, this.playerService});

  @override
  State<SpectraDacScreen> createState() => _SpectraDacScreenState();
}

class _SpectraDacScreenState extends State<SpectraDacScreen> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Ensure native audio session is active and DSP curve is applied immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionId = widget.playerService?.androidAudioSessionId;
      if (sessionId != null && sessionId > 0) {
        eq_bridge.eqInitWithSession(sessionId);
      }
      SpectraDacService.instance.resync();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dac = SpectraDacService.instance;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8F00), Color(0xFFFF3D00)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'TEST LAB',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SpectraDAC™ & DSP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: dac,
            builder: (context, _) => Switch(
              value: dac.isEnabled,
              activeThumbColor: const Color(0xFF00E5FF),
              activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              inactiveThumbColor: Colors.white24,
              inactiveTrackColor: Colors.white10,
              onChanged: (val) => dac.setEnabled(val),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: dac,
        builder: (context, _) {
          final isEnabled = dac.isEnabled;

          return Stack(
            children: [
              const LiquidGlassBackdrop(),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exclusive Master Audio Engine Mode Selector
                _buildModeSelector(dac, isEnabled),

                const SizedBox(height: 20),

                if (dac.engineMode == AudioEngineMode.dspPreset) ...[
                  // ────────── 1. CAR DSP PRESETS MODE ──────────
                  _buildSectionHeader(
                    title: 'LEGENDARY CAR DSP PRESETS',
                    subtitle: 'Pure acoustic emulation of Pioneer, Alpine, Clarion, Rockford & Burmester',
                    icon: Icons.speaker_group_rounded,
                    accentColor: const Color(0xFF00E5FF),
                  ),
                  const SizedBox(height: 12),
                  _buildPresetGrid(dac, isEnabled),

                  const SizedBox(height: 24),

                  // 10-Band Equalizer for car DSP
                  _buildSectionHeader(
                    title: '10-BAND ISO GRAPHIC EQUALIZER',
                    subtitle: 'Fine-tune the current preset across 31 Hz to 16 kHz',
                    icon: Icons.equalizer_rounded,
                    accentColor: const Color(0xFF00E676),
                  ),
                  const SizedBox(height: 12),
                  _build10BandEqualizerCard(dac, isEnabled),

                  const SizedBox(height: 24),

                  // Poweramp DEX Reverb Profiles
                  _buildSectionHeader(
                    title: 'ACOUSTIC REVERB PROFILES',
                    subtitle: 'Studio, Live, Music, Party, Small (Hall), Plate & Custom reflections',
                    icon: Icons.surround_sound_rounded,
                    accentColor: const Color(0xFFB388FF),
                  ),
                  const SizedBox(height: 12),
                  _buildReverbProfilesCard(dac, isEnabled),
                ] else ...[
                  // ────────── 2. AUDIOPHILE DAC & TUBE MODE ──────────
                  _buildSectionHeader(
                    title: 'AUDIOPHILE HARDWARE DAC & TUBES',
                    subtitle: 'Pure analog conversion, tube harmonic warmth & BS2B crossfeed',
                    icon: Icons.album_rounded,
                    accentColor: const Color(0xFFFFB300),
                  ),
                  const SizedBox(height: 12),

                  // Glowing Twin Vacuum Tubes Chassis
                  _buildVacuumChassis(dac, isEnabled),

                  const SizedBox(height: 16),

                  // Analog Tube & Reconstruction Filter Controls
                  _buildAnalogStageCard(dac, isEnabled),
                ],

                const SizedBox(height: 24),

                // Active Live Test Track Controller (If Playing)
                if (widget.playerService != null) ...[
                  _buildQuickTestBar(widget.playerService!),
                  const SizedBox(height: 24),
                ],

                // Sandbox Note
                Center(
                  child: LiquidGlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    borderRadius: 20,
                    blur: 12,
                    tintAlpha: 0.04,
                    child: Text(
                      dac.engineMode == AudioEngineMode.dspPreset
                          ? '🚗 DSP Mode Active: Pure Car Audio Acoustics (Zero DAC/Tube interference)'
                          : '🎧 DAC Mode Active: Pure Master Analog Signal (Zero Car DSP EQ interference)',
                      style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      );
        },
      ),
    );
  }

  // ── Master Exclusive Engine Mode Selector ─────────────────────────────────
  Widget _buildModeSelector(SpectraDacService dac, bool isEnabled) {
    final isDsp = dac.engineMode == AudioEngineMode.dspPreset;

    return LiquidGlassContainer(
      padding: const EdgeInsets.all(4),
      borderRadius: 16,
      blur: 14,
      child: Row(
        children: [
          // Mode 1: Car DSP
          Expanded(
            child: GestureDetector(
              onTap: isEnabled ? () => dac.setEngineMode(AudioEngineMode.dspPreset) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isDsp
                      ? const LinearGradient(
                          colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                        )
                      : null,
                  color: isDsp ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isDsp
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00B4D8).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.speaker_group_rounded,
                      size: 16,
                      color: isDsp ? Colors.white : Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CAR DSP PRESETS',
                      style: TextStyle(
                        color: isDsp ? Colors.white : Colors.white54,
                        fontWeight: isDsp ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Mode 2: Audiophile DAC & Tubes
          Expanded(
            child: GestureDetector(
              onTap: isEnabled ? () => dac.setEngineMode(AudioEngineMode.audiophileDac) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: !isDsp
                      ? const LinearGradient(
                          colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
                        )
                      : null,
                  color: !isDsp ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !isDsp
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF8F00).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.album_rounded,
                      size: 16,
                      color: !isDsp ? Colors.white : Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AUDIOPHILE DAC',
                      style: TextStyle(
                        color: !isDsp ? Colors.white : Colors.white54,
                        fontWeight: !isDsp ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accentColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 1. Audiophile Vacuum Tube Chassis ──────────────────────────────────────
  Widget _buildVacuumChassis(SpectraDacService dac, bool isEnabled) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        final glowFactor = isEnabled && dac.tubeMode != TubeAmpMode.off
            ? 0.4 + (_glowController.value * 0.3) + (dac.tubeWarmthDrive * 0.3)
            : 0.05;

        final amberColor = dac.tubeMode == TubeAmpMode.pentodeEL34
            ? const Color(0xFFFF5252)
            : const Color(0xFFFF8F00);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1B1F2A),
                const Color(0xFF10131A),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isEnabled
                  ? amberColor.withValues(alpha: glowFactor * 0.8)
                  : Colors.white10,
              width: 1.5,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: amberColor.withValues(alpha: glowFactor * 0.25),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              // Top Specs / Status Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isEnabled ? const Color(0xFF00E676) : Colors.red,
                          boxShadow: isEnabled
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E676).withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEnabled ? 'DISCRETE AUDIO STAGE ACTIVE' : 'DSP STAGE BYPASS',
                        style: TextStyle(
                          color: isEnabled ? Colors.white70 : Colors.white30,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      'PREAMP: ${dac.preampDb > 0 ? "+${dac.preampDb}" : dac.preampDb} dB',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Visual Twin Vacuum Tubes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSingleTube(
                    label: 'LEFT CH (12AX7)',
                    glowColor: amberColor,
                    glowFactor: glowFactor,
                    isEnabled: isEnabled && dac.tubeMode != TubeAmpMode.off,
                  ),
                  const SizedBox(width: 32),
                  _buildSingleTube(
                    label: 'RIGHT CH (12AX7)',
                    glowColor: amberColor,
                    glowFactor: glowFactor,
                    isEnabled: isEnabled && dac.tubeMode != TubeAmpMode.off,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Active Stage Summary Pills
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildStatusPill(
                    label: 'DAC: ${_formatDacMode(dac.dacFilter)}',
                    color: const Color(0xFF00E5FF),
                  ),
                  _buildStatusPill(
                    label: 'TUBE: ${_formatTubeMode(dac.tubeMode)}',
                    color: amberColor,
                  ),
                  _buildStatusPill(
                    label: 'CROSSFEED: ${dac.bs2bCrossfeed ? "BS2B ON" : "OFF"}',
                    color: dac.bs2bCrossfeed ? const Color(0xFF76FF03) : Colors.white30,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleTube({
    required String label,
    required Color glowColor,
    required double glowFactor,
    required bool isEnabled,
  }) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 94,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            border: Border.all(
              color: isEnabled
                  ? glowColor.withValues(alpha: 0.7)
                  : Colors.white12,
              width: 1.5,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: glowFactor * 0.4),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Internal filament wire
              Positioned(
                top: 24,
                child: Container(
                  width: 18,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isEnabled
                          ? glowColor.withValues(alpha: glowFactor)
                          : Colors.white24,
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Internal cathode glow core
              if (isEnabled)
                Positioned(
                  top: 32,
                  child: Container(
                    width: 10,
                    height: 22,
                    decoration: BoxDecoration(
                      color: glowColor.withValues(alpha: glowFactor),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 12,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              // Base ring
              Positioned(
                bottom: 4,
                child: Container(
                  width: 44,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── 2. Legendary Presets Grid ──────────────────────────────────────────────
  Widget _buildPresetGrid(SpectraDacService dac, bool isEnabled) {
    return Column(
      children: SpectraDacService.presets.map((preset) {
        final isSelected = dac.engineMode == AudioEngineMode.dspPreset && dac.activePresetId == preset.id;
        final color = preset.accentColor;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: LiquidGlassContainer(
            borderRadius: 16,
            blur: 14,
            tintColor: isSelected ? color : Colors.white,
            tintAlpha: isSelected ? 0.14 : 0.04,
            customBorder: isSelected
                ? Border.all(
                    color: color.withValues(alpha: 0.8),
                    width: 1.2,
                  )
                : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isEnabled ? () => dac.applyPreset(preset) : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      preset.icon,
                      color: isSelected ? color : Colors.white60,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              preset.name,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ENGAGED',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.subtitle,
                          style: TextStyle(
                            color: isSelected ? color : SpectraTheme.cyanWave,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preset.description,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Live Hardware DSP Acoustic Tags
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildAcousticTag(
                              icon: Icons.spatial_audio_rounded,
                              label: preset.virtualizer > 0
                                  ? 'Space: ${(preset.virtualizer * 100).toInt()}%'
                                  : 'Stereo: Direct SQ',
                              color: preset.virtualizer > 0 ? const Color(0xFF00E5FF) : Colors.white38,
                            ),
                            _buildAcousticTag(
                              icon: Icons.surround_sound_rounded,
                              label: preset.reverbPreset == 1
                                  ? 'Cabin Reflections'
                                  : preset.reverbPreset == 4
                                      ? 'Concert Hall'
                                      : preset.reverbPreset == 6
                                          ? 'Plate Snap'
                                          : preset.reverbPreset == 2
                                              ? 'Studio Room'
                                              : 'Reverb: Dry',
                              color: preset.reverbPreset > 0 ? const Color(0xFFB388FF) : Colors.white38,
                            ),
                            if (preset.loudnessMb > 0)
                              _buildAcousticTag(
                                icon: Icons.auto_fix_high_rounded,
                                label: preset.id == 'pioneer_7600'
                                    ? 'Sound Retriever'
                                    : preset.id == 'alpine_f1'
                                        ? 'BassEngine Pro'
                                        : 'Dynamic Punch',
                                color: const Color(0xFFFFD54F),
                              ),
                            _buildAcousticTag(
                              icon: Icons.graphic_eq_rounded,
                              label: 'BassBoost +${preset.bassBoost.toInt()}dB',
                              color: const Color(0xFF00E676),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      }).toList(),
    );
  }

  Widget _buildAcousticTag({required IconData icon, required String label, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Analog Tube & Filter Stage ──────────────────────────────────────────
  Widget _buildAnalogStageCard(SpectraDacService dac, bool isEnabled) {
    return LiquidGlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      blur: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DAC Filter Choice
          const Text(
            'RECONSTRUCTION DAC FILTER',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildDacChip(
                label: 'Min Phase',
                mode: DacFilterMode.minimumPhase,
                selected: dac.dacFilter == DacFilterMode.minimumPhase,
                onTap: isEnabled ? () => dac.setDacFilter(DacFilterMode.minimumPhase) : null,
              ),
              const SizedBox(width: 8),
              _buildDacChip(
                label: 'Linear Phase',
                mode: DacFilterMode.linearPhase,
                selected: dac.dacFilter == DacFilterMode.linearPhase,
                onTap: isEnabled ? () => dac.setDacFilter(DacFilterMode.linearPhase) : null,
              ),
              const SizedBox(width: 8),
              _buildDacChip(
                label: 'NOS R2R',
                mode: DacFilterMode.nosAnalog,
                selected: dac.dacFilter == DacFilterMode.nosAnalog,
                onTap: isEnabled ? () => dac.setDacFilter(DacFilterMode.nosAnalog) : null,
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // Tube Emulation Mode
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VACUUM TUBE EMULATION',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${(dac.tubeWarmthDrive * 100).round()}% DRIVE',
                style: const TextStyle(
                  color: Color(0xFFFFB300),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTubeChip(
                label: 'Bypass (Off)',
                mode: TubeAmpMode.off,
                selected: dac.tubeMode == TubeAmpMode.off,
                onTap: isEnabled ? () => dac.setTubeWarmth(TubeAmpMode.off, dac.tubeWarmthDrive) : null,
              ),
              const SizedBox(width: 8),
              _buildTubeChip(
                label: '12AX7 Triode',
                mode: TubeAmpMode.triode12AX7,
                selected: dac.tubeMode == TubeAmpMode.triode12AX7,
                onTap: isEnabled ? () => dac.setTubeWarmth(TubeAmpMode.triode12AX7, dac.tubeWarmthDrive) : null,
              ),
              const SizedBox(width: 8),
              _buildTubeChip(
                label: 'EL34 Pentode',
                mode: TubeAmpMode.pentodeEL34,
                selected: dac.tubeMode == TubeAmpMode.pentodeEL34,
                onTap: isEnabled ? () => dac.setTubeWarmth(TubeAmpMode.pentodeEL34, dac.tubeWarmthDrive) : null,
              ),
            ],
          ),

          if (dac.tubeMode != TubeAmpMode.off) ...[
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFFFB300),
                inactiveTrackColor: Colors.white12,
                thumbColor: const Color(0xFFFF8F00),
                overlayColor: const Color(0xFFFF8F00).withValues(alpha: 0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: dac.tubeWarmthDrive,
                min: 0.0,
                max: 1.0,
                onChanged: isEnabled
                    ? (val) => dac.setTubeWarmth(dac.tubeMode, val)
                    : null,
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // Bauer BS2B Crossfeed & Preamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Bauer BS2B Spatial Crossfeed',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Blends stereo bleed to reduce headphone fatigue',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
              Switch(
                value: dac.bs2bCrossfeed,
                activeThumbColor: const Color(0xFF76FF03),
                activeTrackColor: const Color(0xFF76FF03).withValues(alpha: 0.3),
                inactiveThumbColor: Colors.white24,
                inactiveTrackColor: Colors.white10,
                onChanged: isEnabled ? (val) => dac.setCrossfeed(val) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDacChip({
    required String label,
    required DacFilterMode mode,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF00E5FF) : Colors.white10,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF00E5FF) : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTubeChip({
    required String label,
    required TubeAmpMode mode,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFB300).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFFFFB300) : Colors.white10,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFFFFB300) : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ── 4. 10-Band Equalizer Card ──────────────────────────────────────────────
  Widget _build10BandEqualizerCard(SpectraDacService dac, bool isEnabled) {
    return LiquidGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      borderRadius: 18,
      blur: 14,
      child: Column(
        children: [
          // Sliders Row — scrollable so all 10 bands fit on any screen width
          SizedBox(
            height: 180,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: SpectraDacService.isoFrequencies.map((freq) {
                  final gain = dac.currentBands[freq] ?? 0.0;
                  return SizedBox(
                    width: 52,
                    child: _buildBandSlider(
                      freq: freq,
                      gain: gain,
                      isEnabled: isEnabled,
                      onChanged: (newGain) => dac.setBandGain(freq, newGain),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Reset Button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Flat Reset', style: TextStyle(fontSize: 11)),
              onPressed: isEnabled
                  ? () {
                      for (final f in SpectraDacService.isoFrequencies) {
                        dac.setBandGain(f, 0.0);
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandSlider({
    required int freq,
    required double gain,
    required bool isEnabled,
    required ValueChanged<double> onChanged,
  }) {
    final formattedFreq = freq >= 1000 ? '${(freq / 1000).round()}k' : '$freq';
    final sign = gain > 0 ? '+' : '';

    return Column(
      children: [
        Text(
          '$sign${gain.toStringAsFixed(1)}',
          style: TextStyle(
            color: gain != 0 ? const Color(0xFF00E676) : Colors.white30,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: const Color(0xFF00E676),
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                overlayColor: const Color(0xFF00E676).withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: gain.clamp(-12.0, 12.0),
                min: -12.0,
                max: 12.0,
                onChanged: isEnabled ? onChanged : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formattedFreq,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── 5. Quick Test Bar for Testing while playing ────────────────────────────
  Widget _buildQuickTestBar(AudioPlayerService player) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final currentTrack = player.currentTrack;
        final isPlaying = player.isPlaying;

        return LiquidGlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 16,
          blur: 14,
          tintColor: const Color(0xFF00E5FF),
          tintAlpha: 0.08,
          customBorder: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.music_note_rounded, color: Color(0xFF00E5FF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTrack?.title ?? 'No Track Playing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentTrack?.artist ?? 'Play any track from Library to test DSP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                  color: const Color(0xFF00E5FF),
                  size: 34,
                ),
                onPressed: () => player.togglePlayPause(),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDacMode(DacFilterMode mode) {
    switch (mode) {
      case DacFilterMode.minimumPhase:
        return 'Min Phase';
      case DacFilterMode.linearPhase:
        return 'Linear';
      case DacFilterMode.nosAnalog:
        return 'NOS R2R';
    }
  }

  String _formatTubeMode(TubeAmpMode mode) {
    switch (mode) {
      case TubeAmpMode.off:
        return 'Off';
      case TubeAmpMode.triode12AX7:
        return '12AX7 Triode';
      case TubeAmpMode.pentodeEL34:
        return 'EL34 Pentode';
    }
  }

  // ── Reverb Profiles Grid Card ───────────────────────────────────────────
  Widget _buildReverbProfilesCard(SpectraDacService dac, bool isEnabled) {
    return LiquidGlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      blur: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BUILT-IN ACOUSTIC REFLECTIONS',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFB388FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dac.presetReverb == 0 ? 'DRY' : 'ACTIVE',
                  style: const TextStyle(
                    color: Color(0xFFB388FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DexReverbProfile.builtInProfiles.map((profile) {
              final isSelected = dac.presetReverb == profile.code;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isEnabled ? () => dac.setReverbPreset(profile.code) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFB388FF).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFB388FF) : Colors.white12,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFB388FF).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        profile.icon,
                        size: 14,
                        color: isSelected ? const Color(0xFFB388FF) : Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        profile.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            DexReverbProfile.builtInProfiles
                .firstWhere(
                  (p) => p.code == dac.presetReverb,
                  orElse: () => DexReverbProfile.builtInProfiles.first,
                )
                .description,
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

