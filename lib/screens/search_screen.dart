import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/downloader_service.dart';
import '../services/local_vault_service.dart';
import '../services/search_stream_service.dart';
import '../theme/theme.dart';
import '../widgets/liquid_glass.dart';
import 'now_playing_screen.dart';

class SearchScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final DownloaderService downloaderService;
  final VoidCallback? onOpenNowPlaying;

  const SearchScreen({
    super.key,
    required this.playerService,
    required this.downloaderService,
    this.onOpenNowPlaying,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchStreamService _searchService = SearchStreamService();
  List<Track> _searchResults = [];
  bool _isSearching = false;
  String? _currentlyStreamingId;
  bool _isQueueExpanded = true;
  AudioFormat _defaultFormat = AudioFormat.flac;

  void _executeSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    // Only trigger full playlist batch modal if it's purely a playlist link (no single video attached)
    // E.g. "youtube.com/playlist?list=..."
    if (cleanQuery.contains('playlist?list=') || (!cleanQuery.contains('watch?v=') && cleanQuery.contains('list='))) {
      _showPlaylistEnqueueDialog(cleanQuery);
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    final results = await _searchService.searchTracks(cleanQuery);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _showPlaylistEnqueueDialog(String playlistUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        AudioFormat selected = _defaultFormat;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: SpectraTheme.darkSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.playlist_play_rounded, color: SpectraTheme.cyanWave),
                  SizedBox(width: 8),
                  Text('Download Playlist', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Online playlist detected! Would you like to enqueue all tracks with artwork & synchronized lyrics (.lrc)?',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Format:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: AudioFormat.values.map((fmt) {
                      final isSel = selected == fmt;
                      return ChoiceChip(
                        label: Text(fmt.name.toUpperCase()),
                        selected: isSel,
                        selectedColor: SpectraTheme.cyanWave.withValues(alpha: 0.25),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        labelStyle: TextStyle(
                          color: isSel ? SpectraTheme.cyanWave : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSel ? SpectraTheme.cyanWave : Colors.white12,
                        ),
                        onSelected: (_) => setDialogState(() => selected = fmt),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpectraTheme.cyanWave,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download All', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    widget.downloaderService.enqueuePlaylist(playlistUrl, selected);
                    _searchController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Enqueuing playlist in ${selected.name.toUpperCase()}...'),
                        backgroundColor: SpectraTheme.darkSurface,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _importCsvTracklist() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final content = utf8.decode(bytes);
        _confirmCsvImport(content, file.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read file: $e')),
        );
      }
    }
  }

  void _confirmCsvImport(String content, String fileName) {
    final parentMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        AudioFormat selected = _defaultFormat;
        final previewLines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).take(5).toList();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: SpectraTheme.darkSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.file_upload_outlined, color: SpectraTheme.cyanWave),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Import $fileName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sample tracks found in file:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: previewLines.map((l) => Text(
                        '• $l',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Audio Format:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: AudioFormat.values.map((fmt) {
                      final isSel = selected == fmt;
                      return ChoiceChip(
                        label: Text(fmt.name.toUpperCase()),
                        selected: isSel,
                        selectedColor: SpectraTheme.cyanWave.withValues(alpha: 0.25),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        labelStyle: TextStyle(
                          color: isSel ? SpectraTheme.cyanWave : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSel ? SpectraTheme.cyanWave : Colors.white12,
                        ),
                        onSelected: (_) => setDialogState(() => selected = fmt),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpectraTheme.cyanWave,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.download_for_offline_rounded, size: 16),
                  label: const Text('Enqueue All', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final count = await widget.downloaderService.enqueueFromCsv(content, selected);
                    parentMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Enqueued $count tracks in ${selected.name.toUpperCase()}!'),
                        backgroundColor: SpectraTheme.darkSurface,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _streamTrack(Track track) async {
    // Populate the playlist queue with search results so next/prev and auto-play work!
    if (_searchResults.isNotEmpty) {
      widget.playerService.setPlaylistSilent(
        _searchResults,
        startIndex: _searchResults.contains(track) ? _searchResults.indexOf(track) : 0,
      );
    }

    setState(() => _currentlyStreamingId = track.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Streaming "${track.title}"...'),
        duration: const Duration(seconds: 2),
        backgroundColor: SpectraTheme.darkSurface,
      ),
    );

    final streamUrl = await _searchService.resolveAudioStreamUrl(track.id, track: track);

    if (mounted) {
      setState(() => _currentlyStreamingId = null);
      if (streamUrl != null) {
        // Bind the resolved streamUrl into the track so subsequent plays or downloads reuse it
        final boundTrack = track.copyWith(localPath: streamUrl);
        final idx = _searchResults.indexWhere((t) => t.id == track.id);
        if (idx != -1) {
          setState(() {
            _searchResults[idx] = boundTrack;
          });
        }

        widget.playerService.playTrack(boundTrack, streamUrl: streamUrl);
        if (widget.onOpenNowPlaying != null) {
          widget.onOpenNowPlaying!();
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NowPlayingScreen(
                playerService: widget.playerService,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No accurate audio found for "${track.title}". Try searching with the artist name or paste a direct stream link.'),
            duration: const Duration(seconds: 4),
            backgroundColor: SpectraTheme.darkSurface,
          ),
        );
      }
    }
  }

  void _playLocalTrack(Track localTrack) {
    if (_searchResults.isNotEmpty) {
      widget.playerService.setPlaylistSilent(
        _searchResults,
        startIndex: _searchResults.contains(localTrack) ? _searchResults.indexOf(localTrack) : 0,
      );
    }
    widget.playerService.playTrack(localTrack);
    if (widget.onOpenNowPlaying != null) {
      widget.onOpenNowPlaying!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NowPlayingScreen(
            playerService: widget.playerService,
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }
  }

  void _downloadTrack(Track track, AudioFormat format) {
    // If the track is currently playing in PlayerService, use its active stream URL
    String? streamUrl;
    final currentPlaying = widget.playerService.currentTrack;
    if (currentPlaying != null && currentPlaying.id == track.id) {
      if (currentPlaying.localPath != null && currentPlaying.localPath!.startsWith('http')) {
        streamUrl = currentPlaying.localPath;
      }
    } else if (track.localPath != null && track.localPath!.startsWith('http')) {
      streamUrl = track.localPath;
    }

    widget.downloaderService.enqueueTrack(
      track,
      format,
      streamUrl: streamUrl,
      videoId: track.sourceVideoId,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${track.title}" (${format.name.toUpperCase()})'),
        duration: const Duration(seconds: 2),
        backgroundColor: SpectraTheme.darkSurface,
      ),
    );
  }

  void _openFormatPickerForTrack(Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpectraTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: SpectraTheme.cyanWave, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Download: ${track.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Choose your preferred audiophile format:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 16),
                ...AudioFormat.values.map((fmt) {
                  final isFlac = fmt == AudioFormat.flac;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFlac
                            ? SpectraTheme.cyanWave.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isFlac ? SpectraTheme.cyanWave : Colors.white12,
                        ),
                      ),
                      child: Text(
                        fmt.name.toUpperCase(),
                        style: TextStyle(
                          color: isFlac ? SpectraTheme.cyanWave : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      isFlac ? 'FLAC (Lossless Studio Master • Default)' : '${fmt.name.toUpperCase()} (Compressed Audio)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isFlac ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isFlac ? 'Bit-perfect audio with embedded .lrc lyrics' : 'Smaller file size with lyrics',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    trailing: const Icon(Icons.download_rounded, color: SpectraTheme.cyanWave),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _downloadTrack(track, fmt);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpectraTheme.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Search & Download'),
        actions: [
          // Format Selector Badge (Changes global default)
          PopupMenuButton<AudioFormat>(
            tooltip: 'Default Download Format',
            initialValue: _defaultFormat,
            color: SpectraTheme.darkSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) => setState(() => _defaultFormat = val),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SpectraTheme.cyanWave.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SpectraTheme.cyanWave.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _defaultFormat.name.toUpperCase(),
                      style: const TextStyle(color: SpectraTheme.cyanWave, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.arrow_drop_down, color: SpectraTheme.cyanWave, size: 16),
                  ],
                ),
              ),
            ),
            itemBuilder: (context) => AudioFormat.values.map((fmt) {
              return PopupMenuItem(
                value: fmt,
                child: Row(
                  children: [
                    Text(
                      fmt.name.toUpperCase(),
                      style: TextStyle(
                        color: _defaultFormat == fmt ? SpectraTheme.cyanWave : Colors.white,
                        fontWeight: _defaultFormat == fmt ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (fmt == AudioFormat.flac)
                      const Text(' (Lossless)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),

          // Import CSV/Playlist Button
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: SpectraTheme.cyanWave),
            tooltip: 'Import CSV Tracklist',
            onPressed: _importCsvTracklist,
          ),
        ],
      ),
      body: Stack(
        children: [
          const LiquidGlassBackdrop(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search & Paste Bar in Liquid Glass ───────────────────────────
            LiquidGlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              borderRadius: 22,
              blur: 16,
              tintColor: Colors.white,
              tintAlpha: 0.08,
              glowShadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: SpectraTheme.cyanWave.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 0),
                ),
              ],
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: SpectraTheme.cyanWave, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search songs, or paste stream playlist link...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _executeSearch,
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: SpectraTheme.neonMagenta),
                    onPressed: () => _executeSearch(_searchController.text),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Section 2: Active Downloads Progress Card (Option 3) in Liquid Glass ──
            ListenableBuilder(
              listenable: widget.downloaderService,
              builder: (context, _) {
                final tasks = widget.downloaderService.tasks;
                if (tasks.isEmpty) return const SizedBox.shrink();

                final progress = widget.downloaderService.overallProgress;
                final completed = widget.downloaderService.completedCount;
                final inProgress = tasks.any((t) => t.status == DownloadStatus.downloading);

                return LiquidGlassContainer(
                  margin: const EdgeInsets.only(bottom: 12),
                  borderRadius: 18,
                  blur: 16,
                  tintColor: inProgress ? SpectraTheme.cyanWave : Colors.white,
                  tintAlpha: inProgress ? 0.10 : 0.05,
                  glowShadows: inProgress
                      ? [
                          BoxShadow(
                            color: SpectraTheme.cyanWave.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                  child: Column(
                    children: [
                      // Header Row
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _isQueueExpanded = !_isQueueExpanded),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: SpectraTheme.cyanWave.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  inProgress ? Icons.downloading_rounded : Icons.check_circle_outline_rounded,
                                  color: inProgress ? SpectraTheme.cyanWave : Colors.greenAccent,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Downloads: $completed / ${tasks.length} Completed',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                    ),
                                    Text(
                                      inProgress
                                          ? 'Overall: ${(progress * 100).toStringAsFixed(0)}% • Active download'
                                          : 'All queued items finished',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              if (completed == tasks.length && tasks.isNotEmpty)
                                TextButton(
                                  onPressed: widget.downloaderService.clearCompleted,
                                  child: const Text('Clear', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                ),
                              Icon(
                                _isQueueExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Overall Progress Line
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.white10,
                        color: inProgress ? SpectraTheme.cyanWave : Colors.greenAccent,
                      ),

                      // Expandable Detailed Task List
                      if (_isQueueExpanded)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shrinkWrap: true,
                            itemCount: tasks.length,
                            itemBuilder: (context, idx) {
                              final task = tasks[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${task.format.name.toUpperCase()} • ${task.status.name.toUpperCase()} ${task.status == DownloadStatus.downloading ? "(${task.speed})" : ""}',
                                            style: TextStyle(
                                              color: task.status == DownloadStatus.completed
                                                  ? Colors.greenAccent
                                                  : (task.status == DownloadStatus.failed ? Colors.redAccent : Colors.white38),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 48,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: task.progress,
                                          minHeight: 5,
                                          backgroundColor: Colors.white12,
                                          color: task.status == DownloadStatus.completed
                                              ? Colors.greenAccent
                                              : SpectraTheme.cyanWave,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            // ── Search State Prompt ──────────────────────────────────────────
            if (_searchResults.isEmpty && !_isSearching)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.travel_explore_rounded, size: 52, color: Colors.white24),
                      const SizedBox(height: 12),
                      const Text(
                        'Search any song to stream or download in FLAC',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Paste stream links or import a CSV file to batch download playlists',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),

            // Searching Loading Indicator
            if (_isSearching)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: SpectraTheme.cyanWave),
                      SizedBox(height: 14),
                      Text('Searching live high-resolution audio streams...', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),

            // ── Search Results List ─────────────────────────────────────────
            if (_searchResults.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_searchResults.length} Results',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _searchResults = []),
                    child: const Text('Clear', style: TextStyle(color: SpectraTheme.cyanWave, fontSize: 12)),
                  ),
                ],
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: LocalVaultService.instance,
                  builder: (context, _) {
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, idx) {
                        final track = _searchResults[idx];
                        final isThisLoading = _currentlyStreamingId == track.id;
                        final localMatch = LocalVaultService.instance.findLocalMatch(track);
                        final isAlreadyInLibrary = localMatch != null;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: track.artworkUrl != null
                                      ? Image.network(
                                          track.artworkUrl!,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Image.asset(
                                            'assets/images/logo_prism.jpg',
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Image.asset(
                                          'assets/images/logo_prism.jpg',
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                if (isThisLoading)
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: SpectraTheme.cyanWave,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                  ),
                                ),
                                if (isAlreadyInLibrary) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'IN LIBRARY',
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '${track.artist} • ${_formatDuration(track.duration)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            trailing: isAlreadyInLibrary
                                ? TextButton.icon(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.greenAccent.withValues(alpha: 0.15),
                                      foregroundColor: Colors.greenAccent,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.35)),
                                      ),
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                    label: const Text('Play Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    onPressed: () => _playLocalTrack(localMatch),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1. Play / Stream Button (Cyan)
                                      IconButton(
                                        icon: const Icon(Icons.play_circle_fill_rounded, color: SpectraTheme.cyanWave, size: 28),
                                        tooltip: 'Stream Online',
                                        onPressed: () => _streamTrack(track),
                                      ),

                                      // 2. 1-Tap Download Button (Default FLAC)
                                      IconButton(
                                        icon: const Icon(Icons.download_rounded, color: SpectraTheme.neonMagenta, size: 24),
                                        tooltip: 'Download ${_defaultFormat.name.toUpperCase()}',
                                        onPressed: () => _downloadTrack(track, _defaultFormat),
                                      ),

                                      // 3. Format Picker for Track (Change to MP3, OPUS, etc.)
                                      IconButton(
                                        icon: const Icon(Icons.tune_rounded, color: Colors.white38, size: 18),
                                        tooltip: 'Choose Format',
                                        onPressed: () => _openFormatPickerForTrack(track),
                                      ),
                                    ],
                                  ),
                            onTap: () {
                              if (isAlreadyInLibrary) {
                                _playLocalTrack(localMatch);
                              } else {
                                _streamTrack(track);
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  ),
);
  }
}

