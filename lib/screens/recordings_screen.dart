import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import '../services/evidence_recording_service.dart';

/// Screen to view and play saved audio/video recordings
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  List<RecordingItem> _recordings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    setState(() => _isLoading = true);

    try {
      final files = await EvidenceRecordingService().getLocalRecordings();
      final items = <RecordingItem>[];

      for (final file in files) {
        final stat = await file.stat();
        final name = file.path.split('/').last;
        final isAudio = name.contains('audio') || name.endsWith('.m4a') || name.endsWith('.mp3');
        final isVideo = name.contains('video') || name.endsWith('.mp4');

        if (isAudio || isVideo) {
          items.add(RecordingItem(
            file: file,
            name: name,
            type: isAudio ? RecordingType.audio : RecordingType.video,
            size: stat.size,
            createdAt: stat.modified,
          ));
        }
      }

      // Sort by date, newest first
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _recordings = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading recordings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRecording(RecordingItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('Are you sure you want to delete this recording? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await EvidenceRecordingService().deleteLocalRecording(item.file.path);
      if (success) {
        setState(() {
          _recordings.remove(item);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording deleted'), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  void _shareRecording(RecordingItem item) {
    Share.shareXFiles([XFile(item.file.path)], text: 'Evidence recording');
  }

  void _playRecording(RecordingItem item) {
    if (item.type == RecordingType.audio) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AudioPlayerScreen(file: item.file, name: item.name),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(file: item.file, name: item.name),
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recordings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecordings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recordings.isEmpty
              ? _buildEmptyState()
              : _buildRecordingsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No recordings yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Audio and video recordings will appear here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recordings.length,
      itemBuilder: (context, index) {
        final item = _recordings[index];
        return _buildRecordingCard(item);
      },
    );
  }

  Widget _buildRecordingCard(RecordingItem item) {
    final isAudio = item.type == RecordingType.audio;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _playRecording(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isAudio
                      ? Colors.purple.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAudio ? Icons.audiotrack : Icons.videocam,
                  color: isAudio ? Colors.purple : Colors.blue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAudio ? 'Audio Recording' : 'Video Recording',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(item.createdAt),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.storage, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          _formatFileSize(item.size),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill),
                    color: const Color(0xFFE91E63),
                    iconSize: 32,
                    onPressed: () => _playRecording(item),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const ListTile(
                          leading: Icon(Icons.share, color: Colors.blue),
                          title: Text('Share'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onTap: () {
                          Future.delayed(Duration.zero, () => _shareRecording(item));
                        },
                      ),
                      PopupMenuItem(
                        child: const ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onTap: () {
                          Future.delayed(Duration.zero, () => _deleteRecording(item));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Audio player screen
class AudioPlayerScreen extends StatefulWidget {
  final File file;
  final String name;

  const AudioPlayerScreen({super.key, required this.file, required this.name});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setFilePath(widget.file.path);
      _duration = _player.duration ?? Duration.zero;

      _player.positionStream.listen((position) {
        if (mounted) setState(() => _position = position);
      });

      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });

      setState(() {});
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Recording')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.audiotrack, size: 60, color: Colors.purple),
              ),
              const SizedBox(height: 32),

              // Progress bar
              Slider(
                value: _position.inMilliseconds.toDouble(),
                max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                onChanged: (value) {
                  _player.seek(Duration(milliseconds: value.toInt()));
                },
                activeColor: const Color(0xFFE91E63),
              ),

              // Time display
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position)),
                    Text(_formatDuration(_duration)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    iconSize: 40,
                    onPressed: () {
                      _player.seek(_position - const Duration(seconds: 10));
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    iconSize: 72,
                    color: const Color(0xFFE91E63),
                    onPressed: () {
                      if (_isPlaying) {
                        _player.pause();
                      } else {
                        _player.play();
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    iconSize: 40,
                    onPressed: () {
                      _player.seek(_position + const Duration(seconds: 10));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Video player screen
class VideoPlayerScreen extends StatefulWidget {
  final File file;
  final String name;

  const VideoPlayerScreen({super.key, required this.file, required this.name});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.file(widget.file);
      await _controller.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        aspectRatio: _controller.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text('Error: $errorMessage', style: const TextStyle(color: Colors.white)),
          );
        },
      );

      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing video player: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Video Recording'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: _isInitialized && _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// Recording item model
class RecordingItem {
  final File file;
  final String name;
  final RecordingType type;
  final int size;
  final DateTime createdAt;

  RecordingItem({
    required this.file,
    required this.name,
    required this.type,
    required this.size,
    required this.createdAt,
  });
}
