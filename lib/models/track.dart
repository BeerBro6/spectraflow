import 'dart:convert';

enum AudioFormat {
  flac,
  opus,
  mp3,
  m4a,
}

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String? localPath;
  final String? artworkUrl;
  final AudioFormat format;
  final int? fileSize;
  final DateTime? dateAdded;

  final String? sourceVideoId;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.localPath,
    this.artworkUrl,
    this.format = AudioFormat.flac,
    this.fileSize,
    this.dateAdded,
    this.sourceVideoId,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? localPath,
    String? artworkUrl,
    AudioFormat? format,
    int? fileSize,
    DateTime? dateAdded,
    String? sourceVideoId,
  }) =>
      Track(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        duration: duration ?? this.duration,
        localPath: localPath ?? this.localPath,
        artworkUrl: artworkUrl ?? this.artworkUrl,
        format: format ?? this.format,
        fileSize: fileSize ?? this.fileSize,
        dateAdded: dateAdded ?? this.dateAdded,
        sourceVideoId: sourceVideoId ?? this.sourceVideoId,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration.inMilliseconds,
        'localPath': localPath,
        'artworkUrl': artworkUrl,
        'format': format.name,
        'fileSize': fileSize,
        'dateAdded': dateAdded?.toIso8601String(),
        'sourceVideoId': sourceVideoId,
      };

  factory Track.fromMap(Map<String, dynamic> map) => Track(
        id: map['id'] ?? '',
        title: map['title'] ?? 'Unknown Title',
        artist: map['artist'] ?? 'Unknown Artist',
        album: map['album'] ?? 'Unknown Album',
        duration: Duration(milliseconds: map['durationMs'] ?? 0),
        localPath: map['localPath'],
        artworkUrl: map['artworkUrl'],
        format: AudioFormat.values.firstWhere(
          (e) => e.name == map['format'],
          orElse: () => AudioFormat.flac,
        ),
        fileSize: map['fileSize'],
        dateAdded: map['dateAdded'] != null
            ? DateTime.tryParse(map['dateAdded'])
            : null,
        sourceVideoId: map['sourceVideoId'],
      );

  String toJson() => json.encode(toMap());
  factory Track.fromJson(String source) => Track.fromMap(json.decode(source));
}

enum DownloadStatus {
  queued,
  downloading,
  tagging,
  completed,
  failed,
}

class DownloadTask {
  final String id;
  final String title;
  final String artist;
  final AudioFormat format;
  double progress;
  String speed;
  DownloadStatus status;
  String? errorMessage;
  String? outputPath;

  DownloadTask({
    required this.id,
    required this.title,
    required this.artist,
    required this.format,
    this.progress = 0.0,
    this.speed = '0 KB/s',
    this.status = DownloadStatus.queued,
    this.errorMessage,
    this.outputPath,
  });
}

class LyricsLine {
  final Duration timestamp;
  final String text;
  final bool isSynced;

  const LyricsLine({
    required this.timestamp,
    required this.text,
    this.isSynced = true,
  });
}

