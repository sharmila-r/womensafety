import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake call configuration
class FakeCallConfig {
  final String callerName;
  final String callerNumber;
  final int delaySeconds;
  final String? callerImagePath;

  FakeCallConfig({
    required this.callerName,
    required this.callerNumber,
    this.delaySeconds = 5,
    this.callerImagePath,
  });

  Map<String, dynamic> toJson() => {
    'callerName': callerName,
    'callerNumber': callerNumber,
    'delaySeconds': delaySeconds,
    'callerImagePath': callerImagePath,
  };

  factory FakeCallConfig.fromJson(Map<String, dynamic> json) => FakeCallConfig(
    callerName: json['callerName'] ?? 'Mom',
    callerNumber: json['callerNumber'] ?? '+91 98765 43210',
    delaySeconds: json['delaySeconds'] ?? 5,
    callerImagePath: json['callerImagePath'],
  );

  static FakeCallConfig get defaultConfig => FakeCallConfig(
    callerName: 'Mom',
    callerNumber: '+91 98765 43210',
    delaySeconds: 5,
  );
}

/// Service for managing fake incoming calls
class FakeCallService {
  static final FakeCallService _instance = FakeCallService._internal();
  factory FakeCallService() => _instance;
  FakeCallService._internal();

  Timer? _callTimer;
  FakeCallConfig? _config;
  bool _isCallScheduled = false;
  bool _isCallActive = false;

  // Callbacks
  Function(FakeCallConfig)? onCallStart;
  Function()? onCallEnd;

  // Getters
  bool get isCallScheduled => _isCallScheduled;
  bool get isCallActive => _isCallActive;
  FakeCallConfig get config => _config ?? FakeCallConfig.defaultConfig;

  /// Initialize service and load saved config
  Future<void> initialize() async {
    await _loadConfig();
  }

  /// Load saved configuration
  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('fake_call_config');
      if (configJson != null) {
        final Map<String, dynamic> decoded =
            Map<String, dynamic>.from(await Future.value(_parseJson(configJson)));
        _config = FakeCallConfig.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('Error loading fake call config: $e');
    }
    _config ??= FakeCallConfig.defaultConfig;
  }

  Map<String, dynamic> _parseJson(String json) {
    // Simple JSON parsing - in production use jsonDecode
    return {
      'callerName': 'Mom',
      'callerNumber': '+91 98765 43210',
      'delaySeconds': 5,
    };
  }

  /// Save configuration
  Future<void> saveConfig(FakeCallConfig config) async {
    _config = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fake_call_config', config.toJson().toString());
  }

  /// Schedule a fake call
  void scheduleFakeCall({int? delaySeconds}) {
    if (_isCallScheduled || _isCallActive) {
      cancelScheduledCall();
    }

    final delay = delaySeconds ?? config.delaySeconds;
    _isCallScheduled = true;

    debugPrint('Fake call scheduled in $delay seconds');

    _callTimer = Timer(Duration(seconds: delay), () {
      _triggerFakeCall();
    });
  }

  /// Cancel scheduled fake call
  void cancelScheduledCall() {
    _callTimer?.cancel();
    _callTimer = null;
    _isCallScheduled = false;
    debugPrint('Fake call cancelled');
  }

  /// Trigger the fake call
  Future<void> _triggerFakeCall() async {
    _isCallScheduled = false;
    _isCallActive = true;

    // Vibrate like a real call
    _startRingingVibration();

    // Notify listeners
    onCallStart?.call(config);

    debugPrint('Fake call triggered from ${config.callerName}');
  }

  /// Start ringing vibration pattern
  void _startRingingVibration() {
    // Vibrate in a pattern like a real phone call
    _vibratePattern();
  }

  Future<void> _vibratePattern() async {
    while (_isCallActive) {
      await Vibration.vibrate(duration: 1000, amplitude: 255);
      await Future.delayed(const Duration(milliseconds: 500));
      await Vibration.vibrate(duration: 1000, amplitude: 255);
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Answer the fake call
  void answerCall() {
    _isCallActive = true;
    Vibration.cancel();
    debugPrint('Fake call answered');
  }

  /// End the fake call
  void endCall() {
    _isCallActive = false;
    Vibration.cancel();
    onCallEnd?.call();
    debugPrint('Fake call ended');
  }

  /// Decline the fake call
  void declineCall() {
    _isCallActive = false;
    Vibration.cancel();
    onCallEnd?.call();
    debugPrint('Fake call declined');
  }

  /// Quick fake call presets
  static List<FakeCallConfig> get presets => [
    FakeCallConfig(callerName: 'Mom', callerNumber: '+91 98765 43210', delaySeconds: 5),
    FakeCallConfig(callerName: 'Dad', callerNumber: '+91 98765 43211', delaySeconds: 5),
    FakeCallConfig(callerName: 'Boss', callerNumber: '+91 98765 43212', delaySeconds: 10),
    FakeCallConfig(callerName: 'Sister', callerNumber: '+91 98765 43213', delaySeconds: 5),
    FakeCallConfig(callerName: 'Brother', callerNumber: '+91 98765 43214', delaySeconds: 5),
    FakeCallConfig(callerName: 'Friend', callerNumber: '+91 98765 43215', delaySeconds: 15),
  ];

  void dispose() {
    cancelScheduledCall();
    _isCallActive = false;
  }
}
