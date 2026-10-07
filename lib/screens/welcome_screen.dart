import 'package:flutter/material.dart';
import '../services/first_launch_service.dart';
import '../theme/theme.dart';
import 'library_screen.dart' show LibraryViewMode;

/// Full-screen first-launch screen that asks the user to pick their
/// listening experience. The selection is persisted via
/// [FirstLaunchService] and passed back to the caller so the rest of the
/// app can boot with the chosen mode.
class WelcomeScreen extends StatefulWidget {
  final ValueChanged<LibraryViewMode> onModeChosen;
  const WelcomeScreen({super.key, required this.onModeChosen});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  LibraryViewMode? _selected;
  final TextEditingController _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_selected == null || _saving) return;
    setState(() => _saving = true);
    if (_nameController.text.trim().isNotEmpty) {
      await FirstLaunchService.setUserName(_nameController.text.trim());
    }
    await FirstLaunchService.markModeSelected(_selected!);
    if (!mounted) return;
    widget.onModeChosen(_selected!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpectraTheme.obsidian,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo_prism.jpg',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Welcome to SpectraFlow',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pick a listening experience to get started',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name input for personalized launch experience
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.person_outline_rounded, color: SpectraTheme.cyanWave, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Your Name (Optional)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Appears on your splash screen below "Hear Every Bit"',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'e.g. Sarah ✨',
                                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.04),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: SpectraTheme.cyanWave, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Choose an Experience',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildModeCard(
                        mode: LibraryViewMode.classic,
                        title: 'Classic Minimal',
                        subtitle:
                            'Spotify-style clean simplicity. 1-tap quick presets, auto-volume leveling, zero technical clutter.',
                        icon: Icons.headphones_rounded,
                        accent: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 14),
                      _buildModeCard(
                        mode: LibraryViewMode.audiophileHybrid,
                        title: 'Audiophile Studio',
                        subtitle:
                            'Poweramp-style studio mastery. Live kHz / bit-depth spec pill, 10-band parametric EQ, bit-perfect DAC routing.',
                        icon: Icons.equalizer_rounded,
                        accent: SpectraTheme.cyanWave,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'You can switch modes or change your name anytime from Settings.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _selected == null ? Colors.white12 : SpectraTheme.cyanWave,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _selected == null || _saving ? null : _continue,
                  child: Text(
                    _saving
                        ? 'Setting up…'
                        : (_selected == null
                            ? 'Pick a mode to continue'
                            : 'Continue'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _selected == null ? Colors.white38 : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required LibraryViewMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    final selected = _selected == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selected = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : Colors.transparent,
                border: Border.all(
                  color: selected ? accent : Colors.white38,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}