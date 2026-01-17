import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

/// Background location tracking service
class BackgroundLocationService {
  static final BackgroundLocationService _instance =
      BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  FlutterBackgroundService? _service;
  bool _isInitialized = false;

  static const String _channelId = 'kaavala_location';
  static const String _channelName = 'Location Tracking';
  static const String _channelDescription = 'Tracks your location for safety features';

  /// Create notification channel (must be called before starting service)
  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.low, // Low to avoid sound/vibration
          showBadge: false,
        ),
      );
      debugPrint('Location notification channel created');
    }
  }

  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Create notification channel FIRST (required for Android 8+)
    await _createNotificationChannel();

    _service = FlutterBackgroundService();

    await _service!.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Kaavala',
        initialNotificationContent: 'Location tracking active',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
    );

    _isInitialized = true;
  }

  /// Start background location tracking
  Future<bool> startTracking() async {
    if (!_isInitialized) await initialize();
    if (_service == null) return false;

    // Check permissions first
    final hasPermission = await LocationService.checkPermission();
    if (!hasPermission) {
      return false;
    }

    // Save tracking state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_tracking_enabled', true);

    return await _service!.startService();
  }

  /// Stop background location tracking
  Future<void> stopTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_tracking_enabled', false);

    _service?.invoke('stop');
  }

  /// Check if tracking is running
  Future<bool> isTracking() async {
    if (_service == null) return false;
    return await _service!.isRunning();
  }

  /// Get latest location from service
  Stream<Map<String, dynamic>?> get locationStream {
    if (_service == null) return const Stream.empty();
    return _service!.on('location_update');
  }

  /// Send SOS from background
  void triggerBackgroundSOS() {
    _service?.invoke('trigger_sos');
  }

  /// Update tracking interval
  Future<void> setTrackingInterval(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tracking_interval', seconds);
    _service?.invoke('update_interval', {'seconds': seconds});
  }
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Main background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  int intervalSeconds = prefs.getInt('tracking_interval') ?? 30;

  // Location tracking variables
  Position? lastPosition;
  Timer? locationTimer;

  // Define helper functions first (before they're referenced)
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      print('Background location error: $e');
      return null;
    }
  }

  Future<void> trackLocation() async {
    final position = await getCurrentPosition();
    if (position == null) return;

    // Calculate distance from last position
    double? distance;
    if (lastPosition != null) {
      distance = Geolocator.distanceBetween(
        lastPosition!.latitude,
        lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
    }

    // Update notification (Android)
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Kaavala - Location Active',
        content: 'Last update: ${DateTime.now().toString().substring(11, 19)}',
      );
    }

    // Send location update
    service.invoke('location_update', {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'heading': position.heading,
      'altitude': position.altitude,
      'distance_from_last': distance,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Check for stationary alert
    final autoAlertEnabled = prefs.getBool('autoAlertEnabled') ?? false;
    if (autoAlertEnabled && distance != null && distance < 10) {
      // User hasn't moved more than 10 meters
      final stationaryCount = prefs.getInt('stationary_count') ?? 0;
      await prefs.setInt('stationary_count', stationaryCount + 1);

      final alertThreshold = prefs.getInt('stationaryAlertMinutes') ?? 30;
      final checksNeeded = (alertThreshold * 60) ~/ intervalSeconds;

      if (stationaryCount >= checksNeeded) {
        // Trigger SOS alert
        service.invoke('stationary_alert', {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'stationary_minutes': alertThreshold,
        });
        await prefs.setInt('stationary_count', 0);
      }
    } else {
      // Reset stationary counter if user moved
      await prefs.setInt('stationary_count', 0);
    }

    lastPosition = position;

    // Save to location history (every 5 minutes)
    final lastSaveTime = prefs.getInt('last_location_save') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastSaveTime > 300000) {
      // 5 minutes
      await prefs.setInt('last_location_save', now);
      service.invoke('save_location_history', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void restartTimer() {
    locationTimer?.cancel();
    locationTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (timer) async {
        await trackLocation();
      },
    );
  }

  // Handle stop command
  service.on('stop').listen((event) {
    locationTimer?.cancel();
    service.stopSelf();
  });

  // Handle interval update
  service.on('update_interval').listen((event) {
    if (event != null && event['seconds'] != null) {
      intervalSeconds = event['seconds'];
      restartTimer();
    }
  });

  // Handle SOS trigger
  service.on('trigger_sos').listen((event) async {
    final position = await getCurrentPosition();
    if (position != null) {
      service.invoke('sos_triggered', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  });

  // Start tracking immediately
  await trackLocation();

  // Start periodic timer
  restartTimer();
}

/// Location tracking state
class LocationTrackingState {
  final bool isTracking;
  final Position? lastPosition;
  final DateTime? lastUpdate;
  final double? distanceTraveled;
  final int stationaryMinutes;

  LocationTrackingState({
    this.isTracking = false,
    this.lastPosition,
    this.lastUpdate,
    this.distanceTraveled,
    this.stationaryMinutes = 0,
  });

  LocationTrackingState copyWith({
    bool? isTracking,
    Position? lastPosition,
    DateTime? lastUpdate,
    double? distanceTraveled,
    int? stationaryMinutes,
  }) {
    return LocationTrackingState(
      isTracking: isTracking ?? this.isTracking,
      lastPosition: lastPosition ?? this.lastPosition,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      distanceTraveled: distanceTraveled ?? this.distanceTraveled,
      stationaryMinutes: stationaryMinutes ?? this.stationaryMinutes,
    );
  }
}
