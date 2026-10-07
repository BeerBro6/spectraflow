import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/downloader_service.dart';
import '../services/search_stream_service.dart';
import '../theme/theme.dart';

class DownloadsScreen extends StatefulWidget {
  final DownloaderService downloaderService;

  const DownloadsScreen({super.key, required this.downloaderService});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchStreamService _searchService = SearchStreamService();
  AudioFormat _selectedFormat = AudioFormat.flac;

  List<Track> _searchResults = [];
  bool _isSearching = false;

  void _onSearchOrDownload() {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;

    // If it's a URL, download directly
    if (text.startsWith('http://') || text.startsWith('https://') || text.contains('youtube.com') || text.contains('youtu.be')) {
      widget.downloaderService.enqueueSearchQuery(text, _selectedFormat);
      _searchController.clear();
      setState(() => _searchResults = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enqueued URL in ${_selectedFormat.name.toUpperCase()}'),
          backgroundColor: SpectraTheme.darkSurface,
        ),
      );
      return;
    }

    // Otherwise, perform live song name search to show instant selectable results!
    _searchSongName(text);
  }

  void _searchSongName(String query) async {
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    final results = await _searchService.searchTracks(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _downloadSpecificTrack(Track track) {
    widget.downloaderService.enqueueSearchQuery(track.title, _selectedFormat);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${track.title}" in ${_selectedFormat.name.toUpperCase()}...'),
        backgroundColor: SpectraTheme.darkSurface,
      ),
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
    return ListenableBuilder(
      listenable: widget.downloaderService,
      builder: (context, _) {
        final tasks = widget.downloaderService.tasks;
        final progress = widget.downloaderService.overallProgress;
        final completed = widget.downloaderService.completedCount;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Download Queue'),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                // Input Bar for Song Name or URL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: SpectraTheme.cyanWave, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search song name (e.g. Masoom Sharma) or paste URL...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _onSearchOrDownload(),
                        ),
                      ),
                      DropdownButton<AudioFormat>(
                        value: _selectedFormat,
                        dropdownColor: SpectraTheme.darkSurface,
                        underline: const SizedBox(),
                        items: AudioFormat.values.map((f) {
                          return DropdownMenuItem(
                            value: f,
                            child: Text(
                              f.name.toUpperCase(),
                              style: const TextStyle(
                                color: SpectraTheme.cyanWave,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedFormat = val);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: SpectraTheme.neonMagenta),
                        onPressed: _onSearchOrDownload,
                      ),
                    ],
                  ),
                ),

                // Live search dropdown results if user searched by song name
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: CircularProgressIndicator(color: SpectraTheme.cyanWave, strokeWidth: 3),
                    ),
                  ),

                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A24),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SpectraTheme.cyanWave.withValues(alpha: 0.3)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, idx) {
                        final track = _searchResults[idx];
                        return ListTile(
                          dense: true,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: track.artworkUrl != null
                                ? Image.network(
                                    track.artworkUrl!,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Image.asset(
                                      'assets/images/logo_prism.jpg',
                                      width: 38,
                                      height: 38,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/logo_prism.jpg',
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          subtitle: Text(
                            '${track.artist} • ${_formatDuration(track.duration)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.download_rounded, color: SpectraTheme.cyanWave, size: 20),
                            onPressed: () {
                              _downloadSpecificTrack(track);
                              setState(() => _searchResults = []);
                              _searchController.clear();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Overall progress card
                if (tasks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SpectraTheme.cyanWave.withValues(alpha: 0.15),
                          SpectraTheme.electricViolet.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SpectraTheme.cyanWave.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$completed / ${tasks.length} Tracks Completed',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Overall Progress: ${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                          ],
                        ),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 5,
                              color: SpectraTheme.cyanWave,
                              backgroundColor: Colors.white12,
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Task List
                Expanded(
                  child: tasks.isEmpty
                      ? const Center(
                          child: Text(
                            'Queue is empty.\nType any song name or paste a link above!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, idx) {
                            final task = tasks[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: SpectraTheme.cyanWave.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          task.format.name.toUpperCase(),
                                          style: const TextStyle(
                                            color: SpectraTheme.cyanWave,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    task.artist,
                                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: task.progress,
                                    color: task.status == DownloadStatus.completed
                                        ? Colors.greenAccent
                                        : (task.status == DownloadStatus.failed
                                            ? Colors.redAccent
                                            : SpectraTheme.neonMagenta),
                                    backgroundColor: Colors.white12,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        task.status.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: task.status == DownloadStatus.completed
                                              ? Colors.greenAccent
                                              : Colors.white54,
                                        ),
                                      ),
                                      Text(
                                        task.speed,
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
