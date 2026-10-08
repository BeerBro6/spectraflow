import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/local_vault_service.dart';
import '../services/playlist_service.dart';
import '../theme/theme.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/track_artwork.dart';
import 'now_playing_screen.dart';
import 'eq_screen.dart' show EqScreen;

enum LibraryViewMode {
  classic, // Classic Minimal: Clean, distraction-free, 1-tap presets (Car, Bass, Vocal, Flat), zero technical clutter
  audiophileHybrid, // Audiophile Studio: 10-band parametric EQ, Live Poweramp spec pill, DAC routing, 24-bit studio metrics
}

enum SortOption {
  recent,
  titleAsc,
  artistAsc,
  albumAsc,
  durationDesc,
}

class LibraryScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final LibraryViewMode viewMode;
  final VoidCallback? onOpenNowPlaying;

  const LibraryScreen({
    super.key,
    required this.playerService,
    this.viewMode = LibraryViewMode.audiophileHybrid,
    this.onOpenNowPlaying,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ScrollController _quickPicksScrollController = ScrollController();
  String _selectedCategory = 'All Songs';
  SortOption _currentSort = SortOption.recent;

  final List<String> _categories = ['All Songs', 'Playlists', 'Artists', 'Albums'];
  bool _isPlaylistSelectionMode = false;
  final Set<String> _selectedPlaylistIds = {};
  bool _hasCheckedFirstLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
    });
  }

  void _checkFirstLaunch() {
    if (_hasCheckedFirstLaunch || !mounted) return;
    _hasCheckedFirstLaunch = true;

    final vault = LocalVaultService.instance;
    // Prompt the user on startup if vault has not been populated or is newly launched
    if (vault.tracks.isEmpty && !vault.isScanning) {
      _showFirstLaunchSetupModal();
    }
  }

  void _showFirstLaunchSetupModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: const Color(0xFF141720),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: Colors.white12, width: 1),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SpectraTheme.cyanWave.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.album_rounded, color: SpectraTheme.cyanWave, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Setup Music Vault',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Choose how to sync your music collection',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Option 1: Auto-scan default phone Music vault
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await LocalVaultService.instance.requestPermissions();
                    await LocalVaultService.instance.scanVault();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SpectraTheme.cyanWave.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SpectraTheme.cyanWave.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: SpectraTheme.cyanWave,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.flash_on_rounded, color: Colors.black, size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-Scan Phone Music',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Scans default /sdcard/Music folder for MP3, FLAC & WAV',
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: SpectraTheme.cyanWave),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Option 2: Choose custom folder
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await LocalVaultService.instance.requestPermissions();
                    await LocalVaultService.instance.pickFolderAndScan();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.folder_open_rounded, color: Colors.white70, size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose Custom Music Folder',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Select an SD card or any specific music directory',
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog([Track? initialTrack]) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161A22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Row(
            children: [
              Icon(Icons.playlist_add_rounded, color: SpectraTheme.cyanWave),
              SizedBox(width: 8),
              Text('New Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Playlist title (e.g. Chill Lossless)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (initialTrack != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Will add: "${initialTrack.title}"',
                  style: const TextStyle(color: SpectraTheme.cyanWave, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SpectraTheme.cyanWave,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  PlaylistService.instance.createPlaylist(
                    title,
                    description: descController.text.trim(),
                    trackIds: initialTrack != null ? [initialTrack.id] : [],
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Created playlist "$title"'),
                      backgroundColor: const Color(0xFF1E2430),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1520),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          title: Row(
            children: [
              const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm();
              },
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAddToPlaylistModal(Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ListenableBuilder(
          listenable: PlaylistService.instance,
          builder: (context, _) {
            final playlists = PlaylistService.instance.playlists;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add to Playlist',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showCreatePlaylistDialog(track);
                          },
                          icon: const Icon(Icons.add, color: SpectraTheme.cyanWave, size: 18),
                          label: const Text('New', style: TextStyle(color: SpectraTheme.cyanWave, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (playlists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Column(
                            children: [
                              const Text('No custom playlists yet.', style: TextStyle(color: Colors.white54)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SpectraTheme.cyanWave,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showCreatePlaylistDialog(track);
                                },
                                child: const Text('Create One Now'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...playlists.map((pl) {
                        final containsTrack = pl.trackIds.contains(track.id);
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: SpectraTheme.cyanWave.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.playlist_play_rounded, color: SpectraTheme.cyanWave),
                          ),
                          title: Text(pl.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('${pl.trackIds.length} tracks', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          trailing: containsTrack
                              ? const Icon(Icons.check_circle_rounded, color: SpectraTheme.cyanWave)
                              : const Icon(Icons.add_circle_outline_rounded, color: Colors.white54),
                          onTap: () {
                            if (containsTrack) {
                              PlaylistService.instance.removeTrackFromPlaylist(pl.id, track.id);
                            } else {
                              PlaylistService.instance.addTrackToPlaylist(pl.id, track.id);
                            }
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(containsTrack
                                    ? 'Removed from "${pl.title}"'
                                    : 'Added to "${pl.title}"'),
                                backgroundColor: const Color(0xFF1E2430),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Case-insensitive string comparator used for stable secondary sort keys.
  int _cmpStr(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  int _cmpTitle(Track a, Track b) => _cmpStr(a.title, b.title);
  int _cmpArtist(Track a, Track b) => _cmpStr(a.artist, b.artist);
  int _cmpAlbum(Track a, Track b) => _cmpStr(a.album, b.album);

  List<Track> _getSortedTracks(List<Track> rawTracks) {
    final list = List<Track>.from(rawTracks);
    switch (_currentSort) {
      case SortOption.recent:
        list.sort((a, b) {
          final da = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          final c = db.compareTo(da);
          // Stable secondary: tracks added at the same instant fall back to title A-Z.
          return c != 0 ? c : _cmpTitle(a, b);
        });
        return list;
      case SortOption.titleAsc:
        list.sort((a, b) {
          final c = _cmpTitle(a, b);
          // Stable secondary: same title from different artists orders by artist.
          return c != 0 ? c : _cmpArtist(a, b);
        });
        return list;
      case SortOption.artistAsc:
        list.sort((a, b) {
          final c = _cmpArtist(a, b);
          // Stable secondary: same artist → album, then title.
          final byAlbum = c != 0 ? 0 : _cmpAlbum(a, b);
          return c != 0 ? c : (byAlbum != 0 ? byAlbum : _cmpTitle(a, b));
        });
        return list;
      case SortOption.albumAsc:
        list.sort((a, b) {
          // Album A-Z → artist A-Z → title A-Z. Gives a clean shelf-by-shelf order.
          final c = _cmpAlbum(a, b);
          if (c != 0) return c;
          final byArtist = _cmpArtist(a, b);
          return byArtist != 0 ? byArtist : _cmpTitle(a, b);
        });
        return list;
      case SortOption.durationDesc:
        list.sort((a, b) {
          final c = b.duration.compareTo(a.duration);
          // Stable secondary: equal-length tracks fall back to title A-Z.
          return c != 0 ? c : _cmpTitle(a, b);
        });
        return list;
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1.0) {
      return '${gb.toStringAsFixed(1)} GB';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  void _openNowPlaying(Track track, List<Track> playlist) {
    widget.playerService.setPlaylist(playlist, startIndex: playlist.indexWhere((t) => t.id == track.id));
    if (widget.onOpenNowPlaying != null) {
      widget.onOpenNowPlaying!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NowPlayingScreen(
            playerService: widget.playerService,
            tracks: playlist,
            viewMode: widget.viewMode,
          ),
        ),
      );
    }
  }

  void _scrollQuickPicksRight() {
    if (_quickPicksScrollController.hasClients) {
      final current = _quickPicksScrollController.offset;
      final max = _quickPicksScrollController.position.maxScrollExtent;
      final next = (current + 160).clamp(0.0, max);
      _quickPicksScrollController.animateTo(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showSortModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    'Sort Tracks By',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSortTile('Recently Added', SortOption.recent),
                _buildSortTile('Track Name (A - Z)', SortOption.titleAsc),
                _buildSortTile('Artist Name (A - Z)', SortOption.artistAsc),
                _buildSortTile('Album Name (A - Z)', SortOption.albumAsc),
                _buildSortTile('Longest Duration', SortOption.durationDesc),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortTile(String title, SortOption option) {
    final isSelected = _currentSort == option;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? SpectraTheme.cyanWave : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: SpectraTheme.cyanWave, size: 20)
          : null,
      onTap: () {
        setState(() => _currentSort = option);
        Navigator.pop(context);
      },
    );
  }

  String get _sortLabel {
    switch (_currentSort) {
      case SortOption.recent:
        return 'Recent';
      case SortOption.titleAsc:
        return 'Title A-Z';
      case SortOption.artistAsc:
        return 'Artist A-Z';
      case SortOption.albumAsc:
        return 'Album A-Z';
      case SortOption.durationDesc:
        return 'Longest';
    }
  }

  @override
  void dispose() {
    _quickPicksScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHybrid = widget.viewMode == LibraryViewMode.audiophileHybrid;

    return ListenableBuilder(
      listenable: LocalVaultService.instance,
      builder: (context, _) {
        final vault = LocalVaultService.instance;
        final allTracks = vault.tracks;
        final displayTracks = _getSortedTracks(allTracks);

        int totalBytes = 0;
        for (final t in allTracks) {
          totalBytes += t.fileSize ?? 0;
        }

        return Scaffold(
          backgroundColor: SpectraTheme.obsidian,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo_prism.jpg',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isHybrid ? 'SpectraFlow Library' : 'Your Library',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            actions: [
              if (vault.isScanning)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: SpectraTheme.cyanWave),
                    ),
                  ),
                ),
              if (_selectedCategory == 'Playlists') ...[
                if (_isPlaylistSelectionMode) ...[
                  IconButton(
                    icon: const Icon(Icons.select_all_rounded, color: SpectraTheme.cyanWave),
                    tooltip: 'Select All',
                    onPressed: () {
                      final allIds = PlaylistService.instance.playlists.map((p) => p.id).toSet();
                      setState(() {
                        if (_selectedPlaylistIds.length == allIds.length) {
                          _selectedPlaylistIds.clear();
                        } else {
                          _selectedPlaylistIds.addAll(allIds);
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                    tooltip: 'Delete Selected',
                    onPressed: _selectedPlaylistIds.isEmpty
                        ? null
                        : () {
                            final count = _selectedPlaylistIds.length;
                            _showDeleteConfirmation(
                              title: 'Delete $count Playlist${count > 1 ? "s" : ""}',
                              message: 'Are you sure you want to delete $count selected playlist${count > 1 ? "s" : ""}? This action cannot be undone.',
                              onConfirm: () {
                                PlaylistService.instance.deleteMultiplePlaylists(_selectedPlaylistIds);
                                setState(() {
                                  _selectedPlaylistIds.clear();
                                  _isPlaylistSelectionMode = false;
                                });
                              },
                            );
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    tooltip: 'Cancel Selection',
                    onPressed: () {
                      setState(() {
                        _isPlaylistSelectionMode = false;
                        _selectedPlaylistIds.clear();
                      });
                    },
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.playlist_add_rounded, color: SpectraTheme.cyanWave),
                    tooltip: 'Create Playlist',
                    onPressed: () => _showCreatePlaylistDialog(),
                  ),
                  if (PlaylistService.instance.playlists.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.checklist_rounded, color: Colors.white70),
                      tooltip: 'Select & Manage Playlists',
                      onPressed: () {
                        setState(() {
                          _isPlaylistSelectionMode = true;
                          _selectedPlaylistIds.clear();
                        });
                      },
                    ),
                ],
              ],
              IconButton(
                icon: const Icon(Icons.folder_special_rounded, color: SpectraTheme.cyanWave),
                tooltip: 'Setup / Change Music Vault',
                onPressed: _showFirstLaunchSetupModal,
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: SpectraTheme.cyanWave),
                tooltip: 'DSP Equalizer & Presets',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EqScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sort_rounded, color: Colors.white70),
                tooltip: 'Sort Options',
                onPressed: _showSortModal,
              ),
            ],
          ),
          body: allTracks.isEmpty && !vault.isScanning
              ? _buildEmptyVaultView(vault)
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  children: [
                    if (vault.isScanning)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SpectraTheme.cyanWave.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: SpectraTheme.cyanWave.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: SpectraTheme.cyanWave),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                vault.scanStatus,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // AUDIOPHILE HYBRID HEADER BADGE & STORAGE METER
                    if (isHybrid) ...[
                      () {
                        final flacCount = allTracks.where((t) => t.format == AudioFormat.flac).length;
                        final mp3Count = allTracks.where((t) => t.format == AudioFormat.mp3).length;
                        final m4aCount = allTracks.where((t) => t.format == AudioFormat.m4a).length;
                        final opusCount = allTracks.where((t) => t.format == AudioFormat.opus).length;
                        final otherCount = allTracks.length - (flacCount + mp3Count + m4aCount + opusCount);
                        final hasLossless = flacCount > 0;

                        // Build dynamic format summary string
                        String formatSummary;
                        if (allTracks.isEmpty) {
                          formatSummary = '0 Tracks • 0 MB';
                        } else {
                          final parts = <String>[];
                          if (flacCount > 0) parts.add('$flacCount FLAC');
                          if (mp3Count > 0) parts.add('$mp3Count MP3');
                          if (m4aCount > 0) parts.add('$m4aCount M4A');
                          if (opusCount > 0) parts.add('$opusCount OPUS');
                          if (otherCount > 0) parts.add('$otherCount Other');

                          if (parts.length == 1) {
                            formatSummary = '${parts.first} Tracks • ${_formatBytes(totalBytes)}';
                          } else {
                            formatSummary = '${parts.join(" • ")} • ${_formatBytes(totalBytes)}';
                          }
                        }

                        // Build dynamic engine description string
                        final String engineDescription;
                        if (allTracks.isEmpty) {
                          engineDescription = 'Awaiting tracks in local library';
                        } else if (hasLossless && mp3Count == 0 && m4aCount == 0 && opusCount == 0) {
                          engineDescription = 'Studio Bit-Perfect Engine (24-bit / 96kHz Lossless)';
                        } else if (hasLossless) {
                          engineDescription = 'Hybrid Studio Engine (Bit-Perfect & Standard Playback)';
                        } else {
                          engineDescription = 'High-Definition Universal Audio Engine (320kbps)';
                        }

                        return LiquidGlassContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          borderRadius: 20,
                          blur: 16,
                          tintColor: SpectraTheme.cyanWave,
                          tintAlpha: 0.10,
                          glowShadows: [
                            BoxShadow(
                              color: SpectraTheme.cyanWave.withValues(alpha: 0.14),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hasLossless ? const Color(0xFFFFB300) : SpectraTheme.cyanWave,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hasLossless ? 'Hi-Res' : 'Standard',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatSummary,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      engineDescription,
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }(),
                      const SizedBox(height: 14),
                    ],

                    // HORIZONTAL FUNCTIONAL CATEGORY CHIPS IN LIQUID GLASS
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (context, idx) {
                          final cat = _categories[idx];
                          final isSelected = _selectedCategory == cat;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: LiquidGlassPill(
                              isSelected: isSelected,
                              accentColor: isHybrid ? SpectraTheme.cyanWave : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              onTap: () => setState(() => _selectedCategory = cat),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected
                                      ? (isHybrid ? SpectraTheme.cyanWave : Colors.white)
                                      : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // QUICK PICKS SWIPEABLE CAROUSEL IN LIQUID GLASS
                    if (displayTracks.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quick Picks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isHybrid ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded, color: SpectraTheme.cyanWave, size: 16),
                            tooltip: 'Scroll Next',
                            onPressed: _scrollQuickPicksRight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 165,
                        child: ListView.builder(
                          controller: _quickPicksScrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: displayTracks.take(15).length,
                          itemBuilder: (context, idx) {
                            final track = displayTracks[idx];
                            return Container(
                              width: 135,
                              margin: const EdgeInsets.only(right: 14),
                              child: LiquidGlassCard(
                                borderRadius: 18,
                                padding: const EdgeInsets.all(10),
                                tintColor: isHybrid ? SpectraTheme.cyanWave : Colors.white,
                                glowShadows: isHybrid
                                    ? [
                                        BoxShadow(
                                          color: SpectraTheme.cyanWave.withValues(alpha: 0.12),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : null,
                                onTap: () => _openNowPlaying(track, displayTracks),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TrackArtwork(
                                      artworkUrl: track.artworkUrl,
                                      width: 115,
                                      height: 85,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // DYNAMIC CATEGORY CONTENT
                    _buildCategorySection(displayTracks, isHybrid),

                    const SizedBox(height: 30),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyVaultView(LocalVaultService vault) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: SpectraTheme.cyanWave.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: SpectraTheme.cyanWave.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.library_music_rounded, color: SpectraTheme.cyanWave, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Music Vault is Empty',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan your high-resolution audio files from disk to populate your library with lossless music and artwork.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: SpectraTheme.cyanWave,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.flash_on_rounded),
              label: const Text('Auto-Scan Music Vault', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => vault.scanVault(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Choose Music Folder...'),
              onPressed: () => vault.pickFolderAndScan(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(List<Track> displayTracks, bool isHybrid) {
    if (_selectedCategory == 'All Songs') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isHybrid ? 'All Tracks (${displayTracks.length} Lossless)' : 'All Songs (${displayTracks.length} Tracks)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              GestureDetector(
                onTap: _showSortModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SpectraTheme.cyanWave.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sort_rounded, color: SpectraTheme.cyanWave, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _sortLabel,
                        style: const TextStyle(
                          color: SpectraTheme.cyanWave,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...displayTracks.map((track) => _buildTrackTile(track, displayTracks, isHybrid)),
        ],
      );
    } else if (_selectedCategory == 'Playlists') {
      return _buildDynamicPlaylists(displayTracks);
    } else if (_selectedCategory == 'Artists') {
      return _buildDynamicArtists(displayTracks);
    } else {
      return _buildDynamicAlbums(displayTracks);
    }
  }

  Widget _buildDynamicPlaylists(List<Track> allTracks) {
    return ListenableBuilder(
      listenable: PlaylistService.instance,
      builder: (context, _) {
        final userPlaylistsRaw = PlaylistService.instance.playlists;
        // Sort user playlists: Liked Songs pinned to the top, then alphabetical
        // by title (case-insensitive), with most recently created as tiebreaker.
        // This fixes the "all over the app" complaint — playlists no longer
        // appear in arbitrary insertion order.
        final userPlaylists = [...userPlaylistsRaw]..sort((a, b) {
          if (a.id == PlaylistService.likedSongsPlaylistId) return -1;
          if (b.id == PlaylistService.likedSongsPlaylistId) return 1;
          final c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
        });

        // Pre-curated smart playlists
        final smartPlaylists = [
          {
            'id': 'smart_lossless',
            'title': '⚡ All Lossless Studio Vault',
            'count': '${allTracks.length} Tracks',
            'icon': Icons.verified_rounded,
            'color': const Color(0xFF00E676),
            'tracks': allTracks,
          },
          {
            'id': 'smart_beats',
            'title': '🔥 High-Tempo & Heavy Beats',
            'count': '${(allTracks.length * 0.4).round()} Tracks',
            'icon': Icons.flash_on_rounded,
            'color': const Color(0xFFFF2E93),
            'tracks': allTracks.take((allTracks.length * 0.4).round()).toList(),
          },
          {
            'id': 'smart_acoustic',
            'title': '🌙 Late Night Acoustics & Soul',
            'count': '${(allTracks.length * 0.35).round()} Tracks',
            'icon': Icons.nights_stay_rounded,
            'color': const Color(0xFF00F2FE),
            'tracks': allTracks.skip((allTracks.length * 0.4).round()).toList(),
          },
          {
            'id': 'smart_favs',
            'title': '💎 Favorites & Recent Discoveries',
            'count': '${allTracks.take(25).length} Tracks',
            'icon': Icons.favorite_rounded,
            'color': const Color(0xFFFF9100),
            'tracks': allTracks.take(25).toList(),
          },
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Create Button & Selection Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isPlaylistSelectionMode
                      ? 'Select Playlists (${_selectedPlaylistIds.length}/${userPlaylists.length})'
                      : 'Your Playlists (${userPlaylists.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                if (!_isPlaylistSelectionMode)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpectraTheme.cyanWave,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Playlist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _showCreatePlaylistDialog(),
                  )
                else
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          final allIds = userPlaylists.map((p) => p.id).toSet();
                          setState(() {
                            if (_selectedPlaylistIds.length == allIds.length) {
                              _selectedPlaylistIds.clear();
                            } else {
                              _selectedPlaylistIds.addAll(allIds);
                            }
                          });
                        },
                        child: Text(
                          _selectedPlaylistIds.length == userPlaylists.length ? 'Deselect All' : 'Select All',
                          style: const TextStyle(color: SpectraTheme.cyanWave, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
                        tooltip: 'Delete Selected',
                        onPressed: _selectedPlaylistIds.isEmpty
                            ? null
                            : () {
                                final count = _selectedPlaylistIds.length;
                                _showDeleteConfirmation(
                                  title: 'Delete $count Playlist${count > 1 ? "s" : ""}',
                                  message: 'Are you sure you want to delete the $count selected playlist${count > 1 ? "s" : ""}? All their tracks will remain intact in your library.',
                                  onConfirm: () {
                                    PlaylistService.instance.deleteMultiplePlaylists(_selectedPlaylistIds);
                                    setState(() {
                                      _selectedPlaylistIds.clear();
                                      _isPlaylistSelectionMode = false;
                                    });
                                  },
                                );
                              },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // User Custom Playlists
            if (userPlaylists.isEmpty && !_isPlaylistSelectionMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.queue_music_rounded, color: Colors.white.withValues(alpha: 0.25), size: 40),
                    const SizedBox(height: 8),
                    const Text('No custom playlists created yet', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('Tap "New Playlist" above or tap ⋮ on any song to create your first playlist.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              )
            else
              ...userPlaylists.map((pl) {
                final isSelected = _selectedPlaylistIds.contains(pl.id);
                // Resolve tracks for this playlist
                final plTracks = allTracks.where((t) => pl.trackIds.contains(t.id)).toList();
                final firstArtwork = plTracks.firstWhere((t) => t.artworkUrl != null, orElse: () => allTracks.first).artworkUrl;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? SpectraTheme.cyanWave.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? SpectraTheme.cyanWave.withValues(alpha: 0.5)
                          : Colors.white10,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: _isPlaylistSelectionMode
                        ? Checkbox(
                            value: isSelected,
                            activeColor: SpectraTheme.cyanWave,
                            checkColor: Colors.black,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPlaylistIds.add(pl.id);
                                } else {
                                  _selectedPlaylistIds.remove(pl.id);
                                }
                              });
                            },
                          )
                        : (pl.id == PlaylistService.likedSongsPlaylistId)
                            ? Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF2E93), Color(0xFFFF8E53)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
                              )
                            : (plTracks.isNotEmpty && firstArtwork != null)
                            ? TrackArtwork(
                                artworkUrl: firstArtwork,
                                width: 48,
                                height: 48,
                                borderRadius: BorderRadius.circular(12),
                              )
                            : Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [SpectraTheme.cyanWave, SpectraTheme.neonMagenta],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.playlist_play_rounded, color: Colors.black, size: 28),
                              ),
                    title: Text(
                      pl.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${pl.trackIds.length} Track${pl.trackIds.length == 1 ? "" : "s"}${pl.description.isNotEmpty ? " • ${pl.description}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: _isPlaylistSelectionMode
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded, color: SpectraTheme.cyanWave, size: 28),
                                onPressed: () {
                                  if (plTracks.isNotEmpty) {
                                    _openNowPlaying(plTracks.first, plTracks);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Playlist "${pl.title}" has no tracks yet. Add tracks via ⋮ menu!'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                                color: const Color(0xFF161A22),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                onSelected: (action) {
                                  if (action == 'delete') {
                                    _showDeleteConfirmation(
                                      title: 'Delete "${pl.title}"?',
                                      message: 'Are you sure you want to delete this playlist? Its tracks will stay in your music library.',
                                      onConfirm: () => PlaylistService.instance.deletePlaylist(pl.id),
                                    );
                                  } else if (action == 'play') {
                                    if (plTracks.isNotEmpty) {
                                      _openNowPlaying(plTracks.first, plTracks);
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'play',
                                    child: Row(
                                      children: [
                                        Icon(Icons.play_arrow_rounded, color: SpectraTheme.cyanWave, size: 18),
                                        SizedBox(width: 8),
                                        Text('Play Playlist', style: TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                  if (pl.id != PlaylistService.likedSongsPlaylistId)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                          SizedBox(width: 8),
                                          Text('Delete Playlist', style: TextStyle(color: Colors.redAccent)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                    onTap: () {
                      if (_isPlaylistSelectionMode) {
                        setState(() {
                          if (isSelected) {
                            _selectedPlaylistIds.remove(pl.id);
                          } else {
                            _selectedPlaylistIds.add(pl.id);
                          }
                        });
                      } else {
                        if (plTracks.isNotEmpty) {
                          _openNowPlaying(plTracks.first, plTracks);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Playlist "${pl.title}" is currently empty. Tap ⋮ on any song to add tracks!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    onLongPress: () {
                      setState(() {
                        _isPlaylistSelectionMode = true;
                        _selectedPlaylistIds.add(pl.id);
                      });
                    },
                  ),
                );
              }),

            const SizedBox(height: 16),

            // Smart Mixes / Dynamic Playlists Section
            const Text(
              'Curated Auto-Mixes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ...smartPlaylists.map((pl) {
              final pTracks = pl['tracks'] as List<Track>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (pl['color'] as Color).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(pl['icon'] as IconData, color: pl['color'] as Color, size: 24),
                  ),
                  title: Text(
                    pl['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    pl['count'] as String,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.play_circle_fill_rounded, color: SpectraTheme.cyanWave, size: 28),
                  onTap: () {
                    if (pTracks.isNotEmpty) {
                      _openNowPlaying(pTracks.first, pTracks);
                    }
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildDynamicArtists(List<Track> tracks) {
    // Group real tracks by artist
    final Map<String, List<Track>> artistMap = {};
    for (final t in tracks) {
      artistMap.putIfAbsent(t.artist, () => []).add(t);
    }
    final sortedArtists = artistMap.keys.toList()
      ..sort((a, b) => artistMap[b]!.length.compareTo(artistMap[a]!.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Artists in Vault (${sortedArtists.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        ...sortedArtists.map((artistName) {
          final artistTracks = artistMap[artistName]!;
          final firstArt = artistTracks.firstWhere((t) => t.artworkUrl != null, orElse: () => artistTracks.first).artworkUrl;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: ListTile(
              leading: TrackArtwork(
                artworkUrl: firstArt,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                artistName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
              ),
              subtitle: Text(
                '${artistTracks.length} Track${artistTracks.length > 1 ? "s" : ""}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
              onTap: () {
                _openNowPlaying(artistTracks.first, artistTracks);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDynamicAlbums(List<Track> tracks) {
    // YouTube Music album sorting methodology:
    // Only genuine multi-track albums or albums where songs are explicitly part of that album collection.
    // Loose single tracks, generic "Single", "Lossless Vault", "Unknown Album", or where album name matches song title
    // with only 1 song are filtered out so the view exclusively shows true albums.
    final Map<String, List<Track>> albumMap = {};
    for (final t in tracks) {
      final rawAlbum = t.album.trim();
      final lower = rawAlbum.toLowerCase();
      
      // Filter out generic placeholders
      if (rawAlbum.isEmpty ||
          lower == 'single' ||
          lower == 'lossless vault' ||
          lower == 'unknown album' ||
          lower == 'unknown' ||
          lower == 'untitled') {
        continue;
      }

      albumMap.putIfAbsent(rawAlbum, () => []).add(t);
    }

    // YouTube Music standard:
    // Keep albums that have > 1 track from that album, OR have recognized distinct album naming
    final genuineAlbums = albumMap.entries.where((entry) {
      final albName = entry.key.toLowerCase();
      final albTracks = entry.value;

      // If it has multiple songs from the same album, it is unequivocally an album
      if (albTracks.length > 1) return true;

      // If single track, ensure the album name isn't just the track title repeated (which is standard single tagging)
      final track = albTracks.first;
      if (albName == track.title.trim().toLowerCase()) return false;

      // If album name is distinct and meaningful, treat as EP/Album
      return true;
    }).toList();

    // Sort albums by number of tracks descending, then title alphabetically
    genuineAlbums.sort((a, b) {
      final countCompare = b.value.length.compareTo(a.value.length);
      if (countCompare != 0) return countCompare;
      return a.key.toLowerCase().compareTo(b.key.toLowerCase());
    });

    if (genuineAlbums.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.album_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            const Text(
              'No Multi-Song Albums Found',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Only songs that share the same album are cataloged in Albums, identical to YouTube Music.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Albums & Collections (${genuineAlbums.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...genuineAlbums.map((entry) {
          final albumName = entry.key;
          final albumTracks = entry.value;
          final sample = albumTracks.first;

          // Find predominant artist for album
          final artistCounts = <String, int>{};
          for (final tr in albumTracks) {
            artistCounts[tr.artist] = (artistCounts[tr.artist] ?? 0) + 1;
          }
          final mainArtist = artistCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: ExpansionTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: TrackArtwork(
                artworkUrl: sample.artworkUrl,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(10),
              ),
              title: Text(
                albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
              ),
              subtitle: Text(
                '$mainArtist • ${albumTracks.length} Track${albumTracks.length > 1 ? "s" : ""}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, color: SpectraTheme.cyanWave, size: 28),
                    tooltip: 'Play Album',
                    onPressed: () => _openNowPlaying(albumTracks.first, albumTracks),
                  ),
                  const Icon(Icons.expand_more_rounded, color: Colors.white38),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Column(
                    children: albumTracks.map((tr) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.music_note_rounded, color: SpectraTheme.cyanWave, size: 18),
                        title: Text(tr.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text(tr.artist, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        trailing: Text(_formatDuration(tr.duration), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        onTap: () => _openNowPlaying(tr, albumTracks),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrackTile(Track track, List<Track> playlist, bool isHybrid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: TrackArtwork(
          artworkUrl: track.artworkUrl,
          width: 48,
          height: 48,
          borderRadius: BorderRadius.circular(10),
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
        ),
        subtitle: Text(
          '${track.artist} • ${_formatDuration(track.duration)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isHybrid)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SpectraTheme.cyanWave.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SpectraTheme.cyanWave.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'FLAC • 24-bit / 96kHz',
                  style: TextStyle(
                    color: SpectraTheme.cyanWave,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'FLAC',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.playlist_add_rounded, color: Colors.white54, size: 20),
              tooltip: 'Add to Playlist',
              onPressed: () => _showAddToPlaylistModal(track),
            ),
          ],
        ),
        onTap: () => _openNowPlaying(track, playlist),
        onLongPress: () => _showTrackOptionsSheet(track),
      ),
    );
  }

  void _showTrackOptionsSheet(Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    TrackArtwork(
                      artworkUrl: track.artworkUrl,
                      width: 48,
                      height: 48,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 16),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: SpectraTheme.cyanWave),
                title: const Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistModal(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_rounded, color: Colors.white70),
                title: const Text('Remove from Library',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Hides this track. The audio file is kept on disk and can be re-scanned later.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRemoveFromLibrary(track);
                },
              ),
              if (track.localPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: const Text('Delete from Device',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    'Permanently deletes the audio file. This cannot be undone.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteFromDevice(track);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _confirmRemoveFromLibrary(Track track) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Row(
            children: [
              Icon(Icons.visibility_off_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Remove from Library?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Text(
            '"${track.title}" will no longer appear in your library. The audio file stays on disk and can be re-scanned later.',
            style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await LocalVaultService.instance.removeTrack(track.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed "${track.title}"'),
                    backgroundColor: const Color(0xFF1E2430),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteFromDevice(Track track) {
    _showDeleteConfirmation(
      title: 'Delete from Device?',
      message:
          '"${track.title}" will be permanently deleted from your device. This action cannot be undone.',
      onConfirm: () async {
        final ok = await LocalVaultService.instance.deleteTrackFile(track);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Deleted "${track.title}"' : 'Could not delete "${track.title}"'),
            backgroundColor: const Color(0xFF1E2430),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
