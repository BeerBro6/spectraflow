import 'package:flutter_test/flutter_test.dart';
import 'package:spectraflow/models/track.dart';
import 'package:spectraflow/services/local_vault_service.dart';

void main() {
  group('LocalVaultService Search & Fuzzy Matching Tests', () {
    test('findLocalMatch matches exact ID and normalized title', () {
      final vault = LocalVaultService.instance;
      // Inject tracks for testing
      final track1 = const Track(
        id: '101',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        duration: Duration(minutes: 3, seconds: 50),
      );
      final track2 = const Track(
        id: '102',
        title: 'Rockstar',
        artist: 'Post Malone',
        album: 'Beerbongs & Bentleys',
        duration: Duration(minutes: 3, seconds: 38),
      );

      vault.tracks.clear();
      vault.tracks.addAll([track1, track2]);

      // 1. Exact ID match
      final matchById = vault.findLocalMatch(const Track(
        id: '101',
        title: 'Different Title',
        artist: 'Different Artist',
        album: 'Unknown',
        duration: Duration.zero,
      ));
      expect(matchById?.id, equals('101'));

      // 2. Normalized Title match with noise (e.g. YouTube search result)
      final matchFuzzy = vault.findLocalMatch(const Track(
        id: 'yt_999',
        title: 'Post Malone - Rockstar [Official Video] ft. 21 Savage',
        artist: 'Post Malone',
        album: 'Online Stream',
        duration: Duration(minutes: 3, seconds: 38),
      ));
      expect(matchFuzzy?.id, equals('102'));
    });
  });
}
