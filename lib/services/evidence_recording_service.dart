import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

/// Recording type enum
enum RecordingType { audio, video }

/// Recording status enum
enum RecordingStatus { idle, recording, paused, saving, uploading, completed, error }

/// Evidence recording model
class EvidenceRecording {
  final String id;
  final String localPath;
  final String? cloudUrl;
  final RecordingType type;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final bool isUploaded;
  final String? sosAlertId;

  EvidenceRecording({
    required this.id,
    required this.localPath,
    this.cloudUrl,
    required this.type,
    required this.startTime,
    this.endTime,
    this.duration,
    this.isUploaded = false,
    this.sosAlertId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'localPath': localPath,
    'cloudUrl': cloudUrl,
    'type': type.name,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'durationSeconds': duration?.inSeconds,
    'isUploaded': isUploaded,
    'sosAlertId': sosAlertId,
  };
}

/// Service for recording audio/video evidence during emergencies
class EvidenceRecordingService {
  static final EvidenceRecordingService _instance = EvidenceRecordingService._internal();
  factory EvidenceRecordingService() => _instance;
  EvidenceRecordingService._internal();

  // Audio recorder
  final AudioRecorder _audioRecorder = AudioRecorder();

  // Camera controller for video
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  // Recording state
  RecordingStatus _status = RecordingStatus.idle;
  RecordingType? _currentRecordingType;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Timer? _maxDurationTimer;

  // Callbacks
  final StreamController<RecordingStatus> _statusController = StreamController.broadcast();
  final StreamController<Duration> _durationController = StreamController.broadcast();
  Timer? _durationTimer;

  // Constants
  static const int maxAudioDurationMinutes = 30;
  static const int maxVideoDurationMinutes = 10;

  // Getters
  RecordingStatus get status => _status;
  Stream<RecordingStatus> get statusStream => _statusController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  bool get isRecording => _status == RecordingStatus.recording;
  CameraController? get cameraController => _cameraController;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      debugPrint('Available cameras: ${_cameras?.length}');
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
    }
  }

  /// Get evidence storage directory
  Future<Directory> _getEvidenceDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final evidenceDir = Directory('${appDir.path}/evidence');
    if (!await evidenceDir.exists()) {
      await evidenceDir.create(recursive: true);
    }
    return evidenceDir;
  }

  /// Generate unique filename
  String _generateFilename(RecordingType type) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = type == RecordingType.audio ? 'm4a' : 'mp4';
    return 'evidence_${type.name}_$timestamp.$extension';
  }

  // ==================== AUDIO RECORDING ====================

  /// Start audio recording
  Future<bool> startAudioRecording({String? sosAlertId}) async {
    if (_status == RecordingStatus.recording) {
      debugPrint('Already recording');
      return false;
    }

    try {
      // Check permission
      if (!await _audioRecorder.hasPermission()) {
        debugPrint('No audio permission');
        return false;
      }

      final evidenceDir = await _getEvidenceDirectory();
      final filename = _generateFilename(RecordingType.audio);
      _currentRecordingPath = '${evidenceDir.path}/$filename';

      // Configure recording
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      );

      await _audioRecorder.start(config, path: _currentRecordingPath!);

      _currentRecordingType = RecordingType.audio;
      _recordingStartTime = DateTime.now();
      _updateStatus(RecordingStatus.recording);
      _startDurationTimer();
      _startMaxDurationTimer(maxAudioDurationMinutes);

      debugPrint('Audio recording started: $_currentRecordingPath');
      return true;
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      _updateStatus(RecordingStatus.error);
      return false;
    }
  }

  /// Stop audio recording
  Future<EvidenceRecording?> stopAudioRecording({String? sosAlertId}) async {
    if (_currentRecordingType != RecordingType.audio) {
      return null;
    }

    try {
      _stopTimers();
      final path = await _audioRecorder.stop();

      if (path == null || _currentRecordingPath == null) {
        _updateStatus(RecordingStatus.error);
        return null;
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(_recordingStartTime!);

      final recording = EvidenceRecording(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        localPath: _currentRecordingPath!,
        type: RecordingType.audio,
        startTime: _recordingStartTime!,
        endTime: endTime,
        duration: duration,
        sosAlertId: sosAlertId,
      );

      _resetRecordingState();
      _updateStatus(RecordingStatus.completed);

      debugPrint('Audio recording stopped. Duration: ${duration.inSeconds}s');
      return recording;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      _updateStatus(RecordingStatus.error);
      return null;
    }
  }

  // ==================== VIDEO RECORDING ====================

  /// Initialize camera for video recording
  Future<bool> initializeCamera({bool useFrontCamera = false}) async {
    if (_cameras == null || _cameras!.isEmpty) {
      await initialize();
      if (_cameras == null || _cameras!.isEmpty) {
        debugPrint('No cameras available');
        return false;
      }
    }

    try {
      // Select camera
      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == (useFrontCamera
            ? CameraLensDirection.front
            : CameraLensDirection.back),
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _cameraController!.initialize();
      debugPrint('Camera initialized: ${camera.name}');
      return true;
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      return false;
    }
  }

  /// Start video recording
  Future<bool> startVideoRecording({String? sosAlertId}) async {
    if (_status == RecordingStatus.recording) {
      debugPrint('Already recording');
      return false;
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      final initialized = await initializeCamera();
      if (!initialized) return false;
    }

    try {
      final evidenceDir = await _getEvidenceDirectory();
      final filename = _generateFilename(RecordingType.video);
      _currentRecordingPath = '${evidenceDir.path}/$filename';

      await _cameraController!.startVideoRecording();

      _currentRecordingType = RecordingType.video;
      _recordingStartTime = DateTime.now();
      _updateStatus(RecordingStatus.recording);
      _startDurationTimer();
      _startMaxDurationTimer(maxVideoDurationMinutes);

      debugPrint('Video recording started');
      return true;
    } catch (e) {
      debugPrint('Error starting video recording: $e');
      _updateStatus(RecordingStatus.error);
      return false;
    }
  }

  /// Stop video recording
  Future<EvidenceRecording?> stopVideoRecording({String? sosAlertId}) async {
    if (_currentRecordingType != RecordingType.video || _cameraController == null) {
      return null;
    }

    try {
      _stopTimers();
      final videoFile = await _cameraController!.stopVideoRecording();

      // Move to evidence directory with proper name
      final evidenceDir = await _getEvidenceDirectory();
      final filename = _generateFilename(RecordingType.video);
      final newPath = '${evidenceDir.path}/$filename';
      await File(videoFile.path).rename(newPath);

      final endTime = DateTime.now();
      final duration = endTime.difference(_recordingStartTime!);

      final recording = EvidenceRecording(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        localPath: newPath,
        type: RecordingType.video,
        startTime: _recordingStartTime!,
        endTime: endTime,
        duration: duration,
        sosAlertId: sosAlertId,
      );

      _resetRecordingState();
      _updateStatus(RecordingStatus.completed);

      debugPrint('Video recording stopped. Duration: ${duration.inSeconds}s');
      return recording;
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      _updateStatus(RecordingStatus.error);
      return null;
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_cameraController == null || _cameras == null || _cameras!.length < 2) {
      return;
    }

    final currentDirection = _cameraController!.description.lensDirection;
    final newDirection = currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    await disposeCamera();
    await initializeCamera(useFrontCamera: newDirection == CameraLensDirection.front);
  }

  // ==================== CLOUD UPLOAD ====================

  /// Upload recording to Firebase Storage
  Future<String?> uploadRecording(EvidenceRecording recording) async {
    try {
      _updateStatus(RecordingStatus.uploading);

      final userId = FirebaseService.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('User not logged in');
        return null;
      }

      final file = File(recording.localPath);
      if (!await file.exists()) {
        debugPrint('Recording file not found');
        return null;
      }

      final fileName = recording.localPath.split('/').last;
      final storagePath = 'evidence/$userId/${recording.type.name}/$fileName';

      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final uploadTask = ref.putFile(file);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save metadata to Firestore
      await FirebaseFirestore.instance.collection('evidence').add({
        ...recording.toJson(),
        'cloudUrl': downloadUrl,
        'isUploaded': true,
        'userId': userId,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Recording uploaded: $downloadUrl');
      _updateStatus(RecordingStatus.completed);
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading recording: $e');
      _updateStatus(RecordingStatus.error);
      return null;
    }
  }

  // ==================== UTILITY METHODS ====================

  void _updateStatus(RecordingStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_recordingStartTime != null) {
        final duration = DateTime.now().difference(_recordingStartTime!);
        _durationController.add(duration);
      }
    });
  }

  void _startMaxDurationTimer(int minutes) {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(Duration(minutes: minutes), () {
      debugPrint('Max duration reached, stopping recording');
      if (_currentRecordingType == RecordingType.audio) {
        stopAudioRecording();
      } else if (_currentRecordingType == RecordingType.video) {
        stopVideoRecording();
      }
    });
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _maxDurationTimer?.cancel();
  }

  void _resetRecordingState() {
    _currentRecordingType = null;
    _currentRecordingPath = null;
    _recordingStartTime = null;
  }

  /// Get all local recordings
  Future<List<File>> getLocalRecordings() async {
    final evidenceDir = await _getEvidenceDirectory();
    if (!await evidenceDir.exists()) return [];

    final files = await evidenceDir.list().toList();
    return files.whereType<File>().toList();
  }

  /// Delete local recording
  Future<bool> deleteLocalRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting recording: $e');
      return false;
    }
  }

  /// Dispose camera resources
  Future<void> disposeCamera() async {
    await _cameraController?.dispose();
    _cameraController = null;
  }

  /// Dispose all resources
  Future<void> dispose() async {
    _stopTimers();
    await _audioRecorder.dispose();
    await disposeCamera();
    await _statusController.close();
    await _durationController.close();
  }
}
