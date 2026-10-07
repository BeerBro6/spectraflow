import 'package:flutter_test/flutter_test.dart';
import 'package:spectraflow/screens/eq_screen.dart';
import 'package:spectraflow/services/autoeq_presets.dart';
import 'package:spectraflow/services/audio_dsp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoEq Database & JamesDSP Parser Tests', () {
    test('Built-in AutoEq profiles are valid and have safe headroom preamps', () {
      expect(AutoEqDatabase.builtinProfiles.isNotEmpty, isTrue);

      final hd600 = AutoEqDatabase.find('hd600');
      expect(hd600, isNotNull);
      expect(hd600!.brand, equals('Sennheiser'));
      expect(hd600.model, equals('HD 600'));
      expect(hd600.recommendedPreamp, lessThanOrEqualTo(0.0));
      expect(hd600.bands.isNotEmpty, isTrue);

      final xm5 = AutoEqDatabase.find('wh1000xm5');
      expect(xm5, isNotNull);
      expect(xm5!.brand, equals('Sony'));
      expect(xm5.recommendedPreamp, lessThan(0.0));

      final airpods = AutoEqDatabase.find('airpods');
      expect(airpods, isNotNull);
      expect(airpods!.brand, equals('Apple'));

      final blessing3 = AutoEqDatabase.find('blessing');
      expect(blessing3, isNotNull);
      expect(blessing3!.brand, equals('Moondrop'));
    });

    test('GraphicEQ parser parses standard AutoEq string format', () {
      const sample = 'GraphicEQ: 20 0.5; 50 2.5; 100 -1.8; 1000 3.0; 8000 -2.0; 16000 1.5;';
      final profile = AutoEqDatabase.parseGraphicEq(sample, name: 'Test Headphone');

      expect(profile, isNotNull);
      expect(profile!.model, equals('Test Headphone'));
      expect(profile.bands.length, equals(6));
      expect(profile.bands[0].frequency, equals(20.0));
      expect(profile.bands[0].gain, equals(0.5));
      expect(profile.bands[1].frequency, equals(50.0));
      expect(profile.bands[1].gain, equals(2.5));
      expect(profile.bands[3].frequency, equals(1000.0));
      expect(profile.bands[3].gain, equals(3.0));
      expect(profile.recommendedPreamp, lessThan(0.0)); // Auto-headroom safeguard
    });

    test('JamesDSP .conf parser parses configuration file format', () {
      const conf = '''
# JamesDSP Configuration File
preamp=-4.5
graphiceq=GraphicEQ: 31 1.2; 62 2.0; 125 -0.5; 250 -1.0; 500 0.5; 1000 1.8; 2000 -1.2; 4000 2.2; 8000 -3.0; 16000 0.5;
bass_boost=4.0
''';
      final profile = AutoEqDatabase.parseJamesDspConf(conf, name: 'My JamesDSP Preset');
      expect(profile, isNotNull);
      expect(profile!.model, equals('My JamesDSP Preset'));
      expect(profile.bands.length, equals(10));
      expect(profile.bands[0].frequency, equals(31.0));
      expect(profile.bands[0].gain, equals(1.2));
    });
  });

  group('AudioDspService Real-Time Processing Tests', () {
    final dsp = AudioDspService.instance;

    setUp(() {
      dsp.resetFlat();
    });

    test('AudioDspService manages effect parameters and auto-headroom', () {
      expect(dsp.isEnabled, isTrue);
      expect(dsp.activePresetName, equals('Passthrough'));
      expect(dsp.currentBands.isEmpty, isTrue);

      // Apply AutoEq profile
      final hd600 = AutoEqDatabase.find('hd600')!;
      dsp.applyAutoEq(hd600);
      expect(dsp.activeAutoEq, equals(hd600));
      expect(dsp.activePresetName, equals(hd600.displayName));
      expect(dsp.currentBands.length, equals(hd600.bands.length));

      // Test real-time hardware sound effects
      dsp.setBassBoost(6.5);
      expect(dsp.bassBoostDb, equals(6.5));

      dsp.setVirtualizer(0.45);
      expect(dsp.virtualizer, equals(0.45));

      dsp.setReverbPreset(2); // Live Hall
      expect(dsp.reverbPreset, equals(2));

      dsp.setLoudnessMb(300);
      expect(dsp.loudnessMb, equals(300));

      // Test auto-headroom attenuation
      expect(dsp.autoHeadroom, isTrue);
      expect(dsp.effectivePreamp, lessThanOrEqualTo(dsp.preampDb));

      // Test session rebind
      dsp.rebindSession(42);
      expect(dsp.activeSessionId, equals(42));

      // Test reset
      dsp.resetFlat();
      expect(dsp.activePresetName, equals('Passthrough'));
      expect(dsp.bassBoostDb, equals(0.0));
      expect(dsp.virtualizer, equals(0.0));
      expect(dsp.reverbPreset, equals(0));
    });

    test('EqController seamlessly controls AudioDspService and updates response curve', () {
      final controller = EqController();
      final xm5 = AutoEqDatabase.find('wh1000xm5')!;

      controller.selectAutoEqProfile(xm5);
      expect(controller.preset.id, equals(xm5.id));
      expect(controller.preset.name, equals(xm5.displayName));
      expect(controller.effectiveBands.length, equals(xm5.bands.length));
      expect(controller.preampDb, equals(xm5.recommendedPreamp));

      // Adjust live hardware effects from controller
      controller.setBassBoost(5.0);
      expect(controller.bassBoostDb, equals(5.0));

      controller.setVirtualizer(0.3);
      expect(controller.virtualizer, equals(0.3));

      // Controller reset
      controller.reset();
      expect(controller.preset.id, equals('flat'));
      expect(controller.bassBoostDb, equals(0.0));
      expect(controller.virtualizer, equals(0.0));
    });
  });
}
