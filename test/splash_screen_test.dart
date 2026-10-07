import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectraflow/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpectraAnchors Verification', () {
    test('SpectraAnchors constants match exact measured prism geometry', () {
      expect(SpectraAnchors.beamTop, 0.439);
      expect(SpectraAnchors.beamHeight, 0.010);
      expect(SpectraAnchors.beamWidth, 0.196);
      expect(SpectraAnchors.flareX, 0.339);
      expect(SpectraAnchors.flareY, 0.478);
      expect(SpectraAnchors.waveLeft, 0.806);
      expect(SpectraAnchors.waveTop, 0.483);
      expect(SpectraAnchors.waveWidth, 0.194);
      expect(SpectraAnchors.waveHeight, 0.034);
    });
  });

  group('SplashScreen Widget Tests', () {
    testWidgets('SplashScreen renders first launch beam reveal and triggers onFinished',
        (WidgetTester tester) async {
      var finished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            iconAsset: 'assets/images/logo_prism_music.png',
            firstLaunch: true,
            onFinished: () {
              finished = true;
            },
          ),
        ),
      );

      // Verify wordmark elements are present
      expect(find.text('SpectraFlow'), findsOneWidget);
      expect(find.text('HEAR EVERY BIT'), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pump(const Duration(milliseconds: 50)); // triggers completed status listener
      await tester.pump(const Duration(milliseconds: 550)); // triggers Future.delayed(500ms)
      expect(finished, isTrue);
    });

    testWidgets('SplashScreen renders personalized tagline when provided',
        (WidgetTester tester) async {
      var finished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            iconAsset: 'assets/images/logo_prism_music.png',
            tagline: 'WITH LOVE FOR SARAH',
            onFinished: () {
              finished = true;
            },
          ),
        ),
      );

      // Verify custom tagline is present
      expect(find.text('SpectraFlow'), findsOneWidget);
      expect(find.text('WITH LOVE FOR SARAH'), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 550));
      expect(finished, isTrue);
    });

    testWidgets('SplashScreen renders both motto and personalized user name below',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            iconAsset: 'assets/images/logo_prism_music.png',
            userName: 'Sarah ✨',
            onFinished: () {},
          ),
        ),
      );

      expect(find.text('SpectraFlow'), findsOneWidget);
      expect(find.text('HEAR EVERY BIT'), findsOneWidget);
      expect(find.text('Sarah ✨'), findsOneWidget);
    });
  });
}
