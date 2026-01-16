import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sms_service.dart';
import 'push_notification_service.dart';

/// Connectivity status enum
enum NetworkStatus { online, offline }

/// Queued notification model for retry when back online
class QueuedNotification {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;

  QueuedNotification({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedNotification.fromJson(Map<String, dynamic> json) => QueuedNotification(
    id: json['id'],
    type: json['type'],
    data: Map<String, dynamic>.from(json['data']),
    createdAt: DateTime.parse(json['createdAt']),
    retryCount: json['retryCount'] ?? 0,
  );
}

/// Service for handling connectivity and offline SMS fallback
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  NetworkStatus _currentStatus = NetworkStatus.online;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Queued notifications for retry
  final List<QueuedNotification> _notificationQueue = [];
  static const String _queueKey = 'notification_queue';
  static const int maxRetries = 3;

  // Stream controller for status updates
  final StreamController<NetworkStatus> _statusController = StreamController.broadcast();

  // Getters
  NetworkStatus get currentStatus => _currentStatus;
  Stream<NetworkStatus> get statusStream => _statusController.stream;
  bool get isOnline => _currentStatus == NetworkStatus.online;
  bool get isOffline => _currentStatus == NetworkStatus.offline;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial status
    await _checkConnectivity();

    // Load queued notifications
    await _loadQueue();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    debugPrint('ConnectivityService initialized. Status: $_currentStatus');
  }

  /// Check current connectivity
  Future<NetworkStatus> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
    return _currentStatus;
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final previousStatus = _currentStatus;
    _updateStatus(results);

    if (previousStatus == NetworkStatus.offline && _currentStatus == NetworkStatus.online) {
      debugPrint('Back online! Processing queued notifications...');
      _processQueue();
    }
  }

  /// Update network status
  void _updateStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) =>
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.ethernet
    );

    _currentStatus = hasConnection ? NetworkStatus.online : NetworkStatus.offline;
    _statusController.add(_currentStatus);
    debugPrint('Network status: $_currentStatus');
  }

  // ==================== SOS WITH FALLBACK ====================

  /// Send SOS alert with automatic fallback to SMS if offline
  Future<SOSResult> sendSOSWithFallback({
    required String senderName,
    required String senderPhone,
    required double latitude,
    required double longitude,
    required String address,
    required List<String> contactPhones,
    String? message,
  }) async {
    final result = SOSResult();

    // Always send SMS as primary (works offline)
    try {
      await SmsService.sendEmergencySMS(
        phoneNumbers: contactPhones,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      result.smsSent = true;
      result.smsRecipients = contactPhones.length;
      debugPrint('SMS sent to ${contactPhones.length} contacts');
    } catch (e) {
      debugPrint('SMS failed: $e');
      result.smsSent = false;
    }

    // Try push notification if online
    if (isOnline) {
      try {
        await PushNotificationService().sendSOSAlertToContacts(
          senderName: senderName,
          senderPhone: senderPhone,
          latitude: latitude,
          longitude: longitude,
          address: address,
          contactPhones: contactPhones,
          message: message,
        );
        result.pushSent = true;
        debugPrint('Push notification sent');
      } catch (e) {
        debugPrint('Push notification failed: $e');
        result.pushSent = false;

        // Queue for retry when back online
        _queueNotification(
          type: 'sos_alert',
          data: {
            'senderName': senderName,
            'senderPhone': senderPhone,
            'latitude': latitude,
            'longitude': longitude,
            'address': address,
            'contactPhones': contactPhones,
            'message': message,
          },
        );
      }
    } else {
      debugPrint('Offline - queuing push notification for later');
      result.pushSent = false;
      result.queued = true;

      // Queue for when back online
      _queueNotification(
        type: 'sos_alert',
        data: {
          'senderName': senderName,
          'senderPhone': senderPhone,
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'contactPhones': contactPhones,
          'message': message,
        },
      );
    }

    return result;
  }

  /// Send location share with fallback
  Future<bool> shareLocationWithFallback({
    required List<String> phoneNumbers,
    required double latitude,
    required double longitude,
    required String address,
    bool isCheckIn = false,
  }) async {
    // Always try SMS first (reliable, works offline)
    try {
      await SmsService.shareLocation(
        phoneNumbers: phoneNumbers,
        latitude: latitude,
        longitude: longitude,
        address: address,
        isCheckIn: isCheckIn,
      );
      return true;
    } catch (e) {
      debugPrint('Location share via SMS failed: $e');
      return false;
    }
  }

  // ==================== NOTIFICATION QUEUE ====================

  /// Queue a notification for later retry
  void _queueNotification({
    required String type,
    required Map<String, dynamic> data,
  }) {
    final notification = QueuedNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    _notificationQueue.add(notification);
    _saveQueue();
    debugPrint('Notification queued: ${notification.id}');
  }

  /// Process queued notifications when back online
  Future<void> _processQueue() async {
    if (_notificationQueue.isEmpty) return;

    debugPrint('Processing ${_notificationQueue.length} queued notifications');

    final toRemove = <QueuedNotification>[];

    for (final notification in _notificationQueue) {
      if (notification.retryCount >= maxRetries) {
        debugPrint('Max retries reached for ${notification.id}, removing');
        toRemove.add(notification);
        continue;
      }

      bool success = false;

      try {
        switch (notification.type) {
          case 'sos_alert':
            await PushNotificationService().sendSOSAlertToContacts(
              senderName: notification.data['senderName'],
              senderPhone: notification.data['senderPhone'],
              latitude: notification.data['latitude'],
              longitude: notification.data['longitude'],
              address: notification.data['address'],
              contactPhones: List<String>.from(notification.data['contactPhones']),
              message: notification.data['message'],
            );
            success = true;
            break;

          case 'escort_request':
            // Handle escort request notifications
            success = true;
            break;
        }
      } catch (e) {
        debugPrint('Failed to process queued notification: $e');
        notification.retryCount++;
      }

      if (success) {
        toRemove.add(notification);
        debugPrint('Queued notification ${notification.id} sent successfully');
      }
    }

    _notificationQueue.removeWhere((n) => toRemove.contains(n));
    _saveQueue();
  }

  /// Save queue to persistent storage
  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_notificationQueue.map((n) => n.toJson()).toList());
      await prefs.setString(_queueKey, json);
    } catch (e) {
      debugPrint('Error saving notification queue: $e');
    }
  }

  /// Load queue from persistent storage
  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_queueKey);
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        _notificationQueue.clear();
        _notificationQueue.addAll(
          decoded.map((e) => QueuedNotification.fromJson(e)),
        );
        debugPrint('Loaded ${_notificationQueue.length} queued notifications');
      }
    } catch (e) {
      debugPrint('Error loading notification queue: $e');
    }
  }

  /// Clear the notification queue
  Future<void> clearQueue() async {
    _notificationQueue.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  /// Get queue status
  int get queuedCount => _notificationQueue.length;

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}

/// Result of SOS send operation
class SOSResult {
  bool smsSent = false;
  bool pushSent = false;
  bool queued = false;
  int smsRecipients = 0;

  bool get anySent => smsSent || pushSent;

  String get statusMessage {
    final messages = <String>[];

    if (smsSent) {
      messages.add('SMS sent to $smsRecipients contact(s)');
    }

    if (pushSent) {
      messages.add('Push notification sent');
    } else if (queued) {
      messages.add('Push notification queued (offline)');
    }

    if (messages.isEmpty) {
      return 'Failed to send alerts';
    }

    return messages.join('. ');
  }
}
