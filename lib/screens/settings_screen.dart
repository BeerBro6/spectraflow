import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../services/local_vault_service.dart';
import '../theme/theme.dart';
import 'library_screen.dart';
import 'eq_test_screen.dart';
import 'eq_screen.dart' show EqScreen, EqController;
import '../services/permission_hub_service.dart';
import '../services/first_launch_service.dart';
import '../widgets/liquid_glass.dart';
import 'spectra_dac_screen.dart';

class SettingsScreen extends StatelessWidget {
  static final _prismEqController = EqController();
  final LibraryViewMode currentMode;
  final ValueChanged<LibraryViewMode> onModeChanged;
  final bool showAudioSpecPill;
  final ValueChanged<bool> onShowAudioSpecPillChanged;
  final bool showQueueDrawer;
  final ValueChanged<bool> onShowQueueDrawerChanged;
  final bool showMiniPlayer;
  final ValueChanged<bool> onShowMiniPlayerChanged;
  final AudioPlayerService? playerService;

  const SettingsScreen({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    required this.showAudioSpecPill,
    required this.onShowAudioSpecPillChanged,
    required this.showQueueDrawer,
    required this.onShowQueueDrawerChanged,
    this.showMiniPlayer = true,
    required this.onShowMiniPlayerChanged,
    this.playerService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpectraTheme.obsidian,
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const LiquidGlassBackdrop(),
          ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
            children: [
              // Section: Appearance & Persona Switch
              const Text(
                'App Experience & Audio Persona',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 12),

              const PersonalizedNameTile(),
              const SizedBox(height: 12),

          LiquidGlassContainer(
            borderRadius: 18,
            blur: 14,
            child: Column(
              children: [
                // Option 1: Classic Minimal
                _buildModeTile(
                  mode: LibraryViewMode.classic,
                  title: 'Classic Minimal',
                  subtitle: 'Streamlined clean simplicity. 1-tap quick presets (🚗 Car Audio, 🔊 Bass, 🎙️ Vocal, ⚪ Flat), auto-volume leveling, and zero technical clutter.',
                  hasBadge: false,
                  accentColor: const Color(0xFF10B981),
                ),
                const Divider(color: Colors.white10, height: 1),
                // Option 2: Audiophile Studio
                _buildModeTile(
                  mode: LibraryViewMode.audiophileHybrid,
                  title: 'Audiophile Studio Mode',
                  subtitle: 'Master audiophile studio control. Live kHz/bit-depth spec pill, 10-band parametric EQ, analog Car DSP acoustic matrix, and direct bit-perfect DAC routing.',
                  hasBadge: true,
                  accentColor: SpectraTheme.cyanWave,
                ),
              ],
            ),
          ),



          // ── Section: Audio EQ ─────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Audio EQ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SpectraTheme.cyanWave.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(color: SpectraTheme.cyanWave, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final preset = EqService.instance.currentPreset;
            final isEnabled = EqService.instance.isEnabled;
            return LiquidGlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 18,
              blur: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: SpectraTheme.cyanWave.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded, color: SpectraTheme.cyanWave, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Equalizer',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEnabled && preset != null
                                  ? 'Active: ${preset.name}'
                                  : 'Flat — EQ off',
                              style: TextStyle(
                                color: isEnabled ? SpectraTheme.cyanWave : Colors.white38,
                                fontSize: 11,
                                fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Bass Boost, Vocal Clarity, or Custom — tune your sound.',
                    style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SpectraTheme.cyanWave,
                            side: BorderSide(color: SpectraTheme.cyanWave.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('Classic EQ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => EqTestScreen(playerService: playerService)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SpectraTheme.neonMagenta,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: const Text('Prism Studio EQ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => EqScreen(controller: _prismEqController)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SpectraDacScreen(playerService: playerService)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF8F00).withValues(alpha: 0.15),
                            const Color(0xFF00E5FF).withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF8F00).withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8F00).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.waves_rounded, color: Color(0xFFFF8F00), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Row(
                                  children: [
                                    Text(
                                      'SpectraDAC™ & DSP Lab',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'EXPERIMENTAL',
                                      style: TextStyle(
                                        color: Color(0xFFFF8F00),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Pioneer 7600, Alpine F#1, Vacuum Tubes & R2R DAC',
                                  style: TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          // ── Section: Music Vault Storage ──────────────────────────────────
          const Text(
            'Music Vault Storage',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: LocalVaultService.instance,
            builder: (context, _) {
              final vault = LocalVaultService.instance;
              return LiquidGlassContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                blur: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: SpectraTheme.cyanWave.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.folder_special_rounded, color: SpectraTheme.cyanWave, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Active Music Vault',
                                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                vault.activeVaultPath,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${vault.tracks.length} Tracks Indexed',
                          style: const TextStyle(color: SpectraTheme.cyanWave, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (vault.isScanning)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: SpectraTheme.cyanWave),
                          )
                        else
                          Text(
                            vault.tracks.isNotEmpty ? 'Cached & Ready' : 'Empty Vault',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                      ],
                    ),
                    if (vault.isScanning) ...[
                      const SizedBox(height: 8),
                      Text(
                        vault.scanStatus,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.folder_open_rounded, size: 16),
                            label: const Text('Change Folder', style: TextStyle(fontSize: 12)),
                            onPressed: vault.isScanning ? null : () => vault.pickFolderAndScan(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SpectraTheme.cyanWave,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Rescan Vault', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: vault.isScanning ? null : () => vault.scanVault(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),



          // Section: Audio Engine Specs
          const Text(
            'Audio Engine',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          LiquidGlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            blur: 14,
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Output Decoder', style: TextStyle(color: Colors.white70)),
                    Text('Bit-Perfect FLAC / Opus', style: TextStyle(color: SpectraTheme.cyanWave, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Stream Priority', style: TextStyle(color: Colors.white70)),
                    Text('Opus 160kbps VBR (Studio SQ)', style: TextStyle(color: SpectraTheme.cyanWave, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lookahead Engine', style: TextStyle(color: Colors.white70)),
                    Text('Track N+1 Pre-cache (Active)', style: TextStyle(color: Color(0xFF69F0AE), fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Background Playback', style: TextStyle(color: Colors.white70)),
                    Text('WakeLock & Media3 Daemon', style: TextStyle(color: Colors.white70)),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Max Bit Depth', style: TextStyle(color: Colors.white70)),
                    Text('24-bit Studio Lossless', style: TextStyle(color: Colors.white)),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Synchronized Lyrics Engine', style: TextStyle(color: Colors.white70)),
                    Text('LRCLIB API (Active)', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          // ── Section: System Permissions & Lockscreen Health ──────────────
          if (!kIsWeb && Platform.isAndroid) ...[
            const SizedBox(height: 24),
            const Text(
              'System Health & Permissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: PermissionHubService.instance,
              builder: (context, _) {
                final status = PermissionHubService.instance.status;
                return LiquidGlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  blur: 14,
                  child: Column(
                    children: [
                      _buildDiagnosticRow(
                        title: 'Lockscreen & Media Controls',
                        subtitle: 'Displays album art, playback controls & seeker in notification shade',
                        isGranted: status.notificationGranted,
                        onFix: () => PermissionHubService.instance.requestNotificationPermission(),
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildDiagnosticRow(
                        title: 'Audio Vault & Offline Storage',
                        subtitle: 'Scans FLAC, MP3 and downloaded music files on device',
                        isGranted: status.storageAudioGranted,
                        onFix: () => PermissionHubService.instance.requestStoragePermission(),
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildDiagnosticRow(
                        title: 'Unrestricted Battery Playback',
                        subtitle: 'Prevents aggressive OEM task killers from stopping background music',
                        isGranted: status.batteryOptimizationIgnored,
                        onFix: () => PermissionHubService.instance.requestBatteryOptimization(),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                          label: const Text('Open Android System Settings', style: TextStyle(fontSize: 12)),
                          onPressed: () => PermissionHubService.instance.openSettings(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 32),

          // App Info
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/images/logo_prism.jpg', width: 44, height: 44),
                ),
                const SizedBox(height: 8),
                const Text('SpectraFlow v1.0.0', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const Text('Open-Source GPL-3.0 by Anmol Ratn (@BeerBro6)', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }

  Widget _buildModeTile({
    required LibraryViewMode mode,
    required String title,
    required String subtitle,
    required bool hasBadge,
    Color accentColor = SpectraTheme.cyanWave,
  }) {
    final isSelected = currentMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onModeChanged(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      if (hasBadge) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: SpectraTheme.cyanWave, size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticRow({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onFix,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isGranted
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : const Color(0xFFFF5252).withValues(alpha: 0.15),
          ),
          child: Icon(
            isGranted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: isGranted ? const Color(0xFF10B981) : const Color(0xFFFF5252),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (!isGranted)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: SpectraTheme.cyanWave,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onFix,
            child: const Text('Fix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          )
        else
          const Text(
            'Active',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }
}

class PersonalizedNameTile extends StatefulWidget {
  const PersonalizedNameTile({super.key});

  @override
  State<PersonalizedNameTile> createState() => _PersonalizedNameTileState();
}

class _PersonalizedNameTileState extends State<PersonalizedNameTile> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await FirstLaunchService.readUserName();
    if (mounted) setState(() => _userName = name);
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _userName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        title: const Text('Personalized Splash Name', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appears on your splash screen below "Hear Every Bit":',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Sarah ✨',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Clear', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SpectraTheme.cyanWave, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null) {
      await FirstLaunchService.setUserName(newName);
      _loadName();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      borderRadius: 18,
      blur: 14,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: SpectraTheme.cyanWave.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.person_rounded, color: SpectraTheme.cyanWave, size: 20),
        ),
        title: const Text('Splash Screen Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          _userName != null && _userName!.isNotEmpty ? 'Personalized for: $_userName' : 'Not set (Shows "Hear Every Bit" only)',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
        onTap: _editName,
      ),
    );
  }
}


