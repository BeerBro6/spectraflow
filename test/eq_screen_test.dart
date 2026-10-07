import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectraflow/screens/eq_screen.dart';

void main() {
  group('EqScreen 1 / Prism Studio Equalizer Tests', () {
    test('EqController math, filter calculation, and persistence', () {
      final controller = EqController();
      expect(controller.enabled, isTrue);
      expect(controller.preset.id, equals('flat'));
      expect(controller.preampDb, equals(0.0));
      expect(controller.autoHeadroom, isTrue);

      // Verify all default presets
      for (final p in EqPresets.all) {
        controller.selectPreset(p);
        expect(controller.preset.id, equals(p.id));
        expect(controller.effectiveBands.length, equals(p.bands.length));
      }

      // Test fine-tune band adjustment
      controller.selectPreset(EqPresets.flat);
      controller.setFine(0, 4.5);
      expect(controller.fine[0], equals(4.5));
      expect(controller.isModified, isTrue);
      expect(controller.effectiveBands.length, equals(1));
      expect(controller.effectiveBands.first.gainDb, equals(4.5));

      // Test Preamp adjustment
      controller.setPreamp(3.0);
      expect(controller.preampDb, equals(3.0));

      // Test auto headroom adjustment
      controller.setAutoHeadroom(false);
      expect(controller.autoHeadroom, isFalse);
      expect(controller.headroomDb, equals(0.0));
      controller.setAutoHeadroom(true);
      expect(controller.autoHeadroom, isTrue);

      // Test persistence (toJson and loadJson)
      final json = controller.toJson();
      final restored = EqController()..loadJson(json);
      expect(restored.preset.id, equals('flat'));
      expect(restored.fine[0], equals(4.5));
      expect(restored.preampDb, equals(3.0));
      expect(restored.autoHeadroom, isTrue);

      // Test reset
      controller.reset();
      expect(controller.preset.id, equals('flat'));
      expect(controller.fine[0], equals(0.0));
      expect(controller.preampDb, equals(0.0));
      expect(controller.isModified, isFalse);
    });

    testWidgets('EqScreen renders complete studio UI and interacts smoothly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = EqController();

      await tester.pumpWidget(
        MaterialApp(
          home: EqScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Header and status pill
      expect(find.text('Equalizer'), findsOneWidget);
      expect(find.text('EQ on / Passthrough'), findsOneWidget);

      // 2. Verify Presets
      expect(find.text('Passthrough'), findsOneWidget);
      expect(find.text('Bass boost'), findsOneWidget);
      expect(find.text('Vocal smooth'), findsOneWidget);

      // Tap Bass boost
      await tester.ensureVisible(find.text('Bass boost'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bass boost'));
      await tester.pumpAndSettle();
      expect(controller.preset.id, equals('bass'));

      // 3. Verify Graphic EQ bands exist
      expect(find.text('31'), findsOneWidget);
      expect(find.text('1k'), findsOneWidget);
      expect(find.text('16k'), findsOneWidget);

      // 4. Verify Pre-amp section & Tactile Metal Knob
      expect(find.text('Pre-amp'), findsOneWidget);
      expect(find.text('Auto headroom'), findsOneWidget);
      expect(find.text('Gain'), findsOneWidget);

      // 5. Verify Reset button
      expect(find.text('Reset equalizer'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset equalizer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset equalizer'));
      await tester.pumpAndSettle();
      expect(controller.preset.id, equals('flat'));
    });
  });
}
