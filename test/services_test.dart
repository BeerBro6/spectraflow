import 'package:flutter_test/flutter_test.dart';
import 'package:spectraflow/models/track.dart';
import 'package:spectraflow/services/lyrics_service.dart';
import 'package:spectraflow/services/playlist_service.dart';

void main() {
  group('LyricsService Unit Tests', () {
    test('cleanTrackName cleans featuring, brackets, and extra tags', () {
      expect(
        LyricsService.cleanTrackName('Jai Veeru (3D Audio)'),
        equals('Jai Veeru'),
      );
      expect(
        LyricsService.cleanTrackName('Artist - Song Name [Official Video]'),
        equals('Song Name'),
      );
      expect(
        LyricsService.cleanTrackName('Starboy feat. Daft Punk'),
        equals('Starboy'),
      );
      expect(
        LyricsService.cleanTrackName('Song Name.flac'),
        equals('Song Name'),
      );
    });

    test('cleanArtistName cleans extra tags', () {
      expect(
        LyricsService.cleanArtistName('The Weeknd feat. Daft Punk'),
        equals('The Weeknd'),
      );
      expect(
        LyricsService.cleanArtistName('Drake (prod. Metro Boomin)'),
        equals('Drake'),
      );
    });

    test('timestamp parser handles standard LRC format', () {
      const lrc = '[00:12.50]Hello world\n[01:05.100]Second line\n[02:00.00]Third line';
      final lines = LyricsService.parseLrc(lrc);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals('Hello world'));
      expect(lines[0].timestamp.inMilliseconds, equals(12500));
      expect(lines[1].text, equals('Second line'));
      expect(lines[1].timestamp.inMilliseconds, equals(65100));
      expect(lines[2].text, equals('Third line'));
      expect(lines[2].timestamp.inSeconds, equals(120));
    });
  });

  group('PlaylistService Unit Tests', () {
    test('create, addTrack, removeTrack, and delete operations', () async {
      final service = PlaylistService.instance;
      await service.deleteAllPlaylists();
      expect(service.playlists.isEmpty, isTrue);

      await service.createPlaylist('Rock Hits', description: 'Classic rock');
      expect(service.playlists.length, equals(1));
      final plId = service.playlists.first.id;
      expect(service.playlists.first.title, equals('Rock Hits'));

      await service.addTrackToPlaylist(plId, 'track_1');
      await service.addTrackToPlaylist(plId, 'track_2');
      expect(service.playlists.first.trackIds, equals(['track_1', 'track_2']));

      // Adding duplicate track should not duplicate
      await service.addTrackToPlaylist(plId, 'track_1');
      expect(service.playlists.first.trackIds, equals(['track_1', 'track_2']));

      // Remove track
      await service.removeTrackFromPlaylist(plId, 'track_1');
      expect(service.playlists.first.trackIds, equals(['track_2']));

      // Delete playlist
      await service.deletePlaylist(plId);
      expect(service.playlists.isEmpty, isTrue);
    });
  });

  group('Track Model Serialization Tests', () {
    test('Track toMap and fromMap serialization integrity', () {
      final now = DateTime.now();
      final track = Track(
        id: 'test_123',
        title: 'Test Track',
        artist: 'Test Artist',
        album: 'Test Album',
        duration: const Duration(seconds: 185),
        localPath: '/path/to/song.flac',
        artworkUrl: 'https://example.com/art.jpg',
        format: AudioFormat.flac,
        fileSize: 25000000,
        dateAdded: now,
      );

      final map = track.toMap();
      final reconstructed = Track.fromMap(map);

      expect(reconstructed.id, equals(track.id));
      expect(reconstructed.title, equals(track.title));
      expect(reconstructed.artist, equals(track.artist));
      expect(reconstructed.album, equals(track.album));
      expect(reconstructed.duration, equals(track.duration));
      expect(reconstructed.localPath, equals(track.localPath));
      expect(reconstructed.artworkUrl, equals(track.artworkUrl));
      expect(reconstructed.format, equals(AudioFormat.flac));
      expect(reconstructed.fileSize, equals(25000000));
    });
  });
}
