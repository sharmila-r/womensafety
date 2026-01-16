import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/evidence_recording_service.dart';

class RecordingScreen extends StatefulWidget {
  final RecordingType initialType;
  final String? sosAlertId;
  final bool autoStart;

  const RecordingScreen({
    super.key,
    this.initialType = RecordingType.audio,
    this.sosAlertId,
    this.autoStart = false,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final EvidenceRecordingService _recordingService = EvidenceRecordingService();

  RecordingType _currentType = RecordingType.audio;
  RecordingStatus _status = RecordingStatus.idle;
  Duration _duration = Duration.zero;
  bool _isInitialized = false;
  bool _isCameraReady = false;
  EvidenceRecording? _lastRecording;

  StreamSubscription<RecordingStatus>? _statusSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _recordingService.initialize();

    _statusSubscription = _recordingService.statusStream.listen((status) {
      setState(() => _status = status);
    });

    _durationSubscription = _recordingService.durationStream.listen((duration) {
      setState(() => _duration = duration);
    });

    if (_currentType == RecordingType.video) {
      await _initializeCamera();
    }

    setState(() => _isInitialized = true);

    if (widget.autoStart) {
      _startRecording();
    }
  }

  Future<void> _initializeCamera() async {
    final success = await _recordingService.initializeCamera();
    setState(() => _isCameraReady = success);
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _durationSubscription?.cancel();
    _recordingService.disposeCamera();
    super.dispose();
  }

  Future<void> _startRecording() async {
    bool success;
    if (_currentType == RecordingType.audio) {
      success = await _recordingService.startAudioRecording(sosAlertId: widget.sosAlertId);
    } else {
      success = await _recordingService.startVideoRecording(sosAlertId: widget.sosAlertId);
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start ${_currentType.name} recording'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    EvidenceRecording? recording;
    if (_currentType == RecordingType.audio) {
      recording = await _recordingService.stopAudioRecording(sosAlertId: widget.sosAlertId);
    } else {
      recording = await _recordingService.stopVideoRecording(sosAlertId: widget.sosAlertId);
    }

    if (recording != null) {
      setState(() => _lastRecording = recording);
      _showSaveDialog(recording);
    }
  }

  void _showSaveDialog(EvidenceRecording recording) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Recording Saved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duration: ${_formatDuration(recording.duration ?? Duration.zero)}'),
            const SizedBox(height: 8),
            Text('Type: ${recording.type.name.toUpperCase()}'),
            const SizedBox(height: 16),
            const Text('Would you like to upload this to the cloud for safekeeping?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, recording);
            },
            child: const Text('Keep Local Only'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _uploadRecording(recording);
            },
            child: const Text('Upload to Cloud'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadRecording(EvidenceRecording recording) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Uploading...'),
          ],
        ),
      ),
    );

    final url = await _recordingService.uploadRecording(recording);

    if (mounted) {
      Navigator.pop(context); // Close upload dialog

      if (url != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Recording saved locally.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      Navigator.pop(context, recording);
    }
  }

  void _switchType() async {
    if (_status == RecordingStatus.recording) return;

    final newType = _currentType == RecordingType.audio
        ? RecordingType.video
        : RecordingType.audio;

    setState(() {
      _currentType = newType;
      _isCameraReady = false;
    });

    if (newType == RecordingType.video) {
      await _initializeCamera();
    } else {
      await _recordingService.disposeCamera();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _currentType == RecordingType.audio ? 'Audio Recording' : 'Video Recording',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            if (_status == RecordingStatus.recording) {
              _showExitConfirmation();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_status != RecordingStatus.recording)
            IconButton(
              icon: Icon(
                _currentType == RecordingType.audio ? Icons.videocam : Icons.mic,
                color: Colors.white,
              ),
              onPressed: _switchType,
              tooltip: 'Switch to ${_currentType == RecordingType.audio ? 'video' : 'audio'}',
            ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview or audio visualizer
          Expanded(
            child: _currentType == RecordingType.video
                ? _buildVideoPreview()
                : _buildAudioVisualizer(),
          ),

          // Duration display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 14,
                    color: _status == RecordingStatus.recording
                        ? Colors.red
                        : Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Camera switch (video only)
                if (_currentType == RecordingType.video)
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32),
                    onPressed: _status != RecordingStatus.recording
                        ? () async {
                            await _recordingService.switchCamera();
                            setState(() {});
                          }
                        : null,
                  )
                else
                  const SizedBox(width: 48),

                // Record button
                GestureDetector(
                  onTap: _status == RecordingStatus.recording
                      ? _stopRecording
                      : _startRecording,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _status == RecordingStatus.recording ? 32 : 64,
                        height: _status == RecordingStatus.recording ? 32 : 64,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(
                            _status == RecordingStatus.recording ? 4 : 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Placeholder for symmetry
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (!_isCameraReady || _recordingService.cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: _recordingService.cameraController!.value.aspectRatio,
        child: CameraPreview(_recordingService.cameraController!),
      ),
    );
  }

  Widget _buildAudioVisualizer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated mic icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _status == RecordingStatus.recording ? 120 : 100,
            height: _status == RecordingStatus.recording ? 120 : 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _status == RecordingStatus.recording
                  ? Colors.red.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.mic,
              size: 60,
              color: _status == RecordingStatus.recording
                  ? Colors.red
                  : Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _status == RecordingStatus.recording
                ? 'Recording audio...'
                : 'Tap record to start',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    switch (_status) {
      case RecordingStatus.idle:
        return 'Ready to record';
      case RecordingStatus.recording:
        return 'REC';
      case RecordingStatus.paused:
        return 'Paused';
      case RecordingStatus.saving:
        return 'Saving...';
      case RecordingStatus.uploading:
        return 'Uploading...';
      case RecordingStatus.completed:
        return 'Completed';
      case RecordingStatus.error:
        return 'Error occurred';
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Recording?'),
        content: const Text('This will stop the current recording. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _stopRecording();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Stop & Save'),
          ),
        ],
      ),
    );
  }
}
