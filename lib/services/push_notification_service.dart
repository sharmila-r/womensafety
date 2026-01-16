import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'firebase_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  // Handle SOS alerts in background
  if (message.data['type'] == 'sos_alert') {
    // Store for later display when app opens
    // The notification will be shown automatically by FCM
  }
}

/// Push Notification Service for SOS Alerts
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  bool _isInitialized = false;

  // Notification channels
  static const String _sosChannelId = 'sos_alerts';
  static const String _sosChannelName = 'SOS Alerts';
  static const String _sosChannelDescription = 'Emergency SOS alerts from your contacts';

  static const String _escortChannelId = 'escort_requests';
  static const String _escortChannelName = 'Escort Requests';
  static const String _escortChannelDescription = 'Notifications for escort requests';

  static const String _generalChannelId = 'general';
  static const String _generalChannelName = 'General';
  static const String _generalChannelDescription = 'General app notifications';

  /// Initialize push notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permission
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Set up message handlers
    _setupMessageHandlers();

    // Get and save FCM token
    await _getAndSaveToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    _isInitialized = true;
  }

  /// Request notification permission
  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: true, // For emergency SOS
      provisional: false,
      sound: true,
    );

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    print('Notification permission: ${settings.authorizationStatus}');
    return granted;
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    // Create notification channels (Android)
    await _createNotificationChannels();
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // SOS Alert channel - high priority with custom sound
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _sosChannelId,
          _sosChannelName,
          description: _sosChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFFE91E63),
        ),
      );

      // Escort Request channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _escortChannelId,
          _escortChannelName,
          description: _escortChannelDescription,
          importance: Importance.high,
          playSound: true,
        ),
      );

      // General channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _generalChannelId,
          _generalChannelName,
          description: _generalChannelDescription,
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// Set up FCM message handlers
  void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when user taps notification (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from notification (app was terminated)
    _checkInitialMessage();
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message received: ${message.messageId}');

    final data = message.data;
    final notification = message.notification;

    // Determine channel based on message type
    String channelId = _generalChannelId;
    if (data['type'] == 'sos_alert') {
      channelId = _sosChannelId;
    } else if (data['type'] == 'escort_request') {
      channelId = _escortChannelId;
    }

    // Show local notification
    await _showLocalNotification(
      id: message.hashCode,
      title: notification?.title ?? data['title'] ?? 'SafeHer Alert',
      body: notification?.body ?? data['body'] ?? '',
      channelId: channelId,
      payload: jsonEncode(data),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    _navigateBasedOnNotification(message.data);
  }

  /// Check if app was opened from notification
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from notification: ${initialMessage.data}');
      _navigateBasedOnNotification(initialMessage.data);
    }
  }

  /// Navigate based on notification data
  void _navigateBasedOnNotification(Map<String, dynamic> data) {
    final type = data['type'];
    switch (type) {
      case 'sos_alert':
        // Navigate to SOS response screen
        // TODO: Implement navigation
        break;
      case 'escort_request':
        // Navigate to escort request screen
        break;
      case 'report_update':
        // Navigate to report details
        break;
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _sosChannelId ? _sosChannelName :
      channelId == _escortChannelId ? _escortChannelName : _generalChannelName,
      channelDescription: channelId == _sosChannelId ? _sosChannelDescription :
      channelId == _escortChannelId ? _escortChannelDescription : _generalChannelDescription,
      importance: channelId == _sosChannelId ? Importance.max : Importance.high,
      priority: channelId == _sosChannelId ? Priority.max : Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFFE91E63),
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: channelId == _sosChannelId, // Full screen for SOS
      category: channelId == _sosChannelId ? AndroidNotificationCategory.alarm : null,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Notification tap callback
  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    if (response.payload != null) {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      PushNotificationService()._navigateBasedOnNotification(data);
    }
  }

  /// Background notification tap callback
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    print('Background notification tapped: ${response.payload}');
  }

  /// Get and save FCM token
  Future<String?> _getAndSaveToken() async {
    _fcmToken = await _messaging.getToken();
    print('FCM Token: $_fcmToken');

    if (_fcmToken != null) {
      await _saveTokenToFirestore(_fcmToken!);
    }

    return _fcmToken;
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final userId = FirebaseService.instance.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'platform': Platform.isIOS ? 'ios' : 'android',
    }, SetOptions(merge: true));

    // Also save to userTokens collection for easy querying
    await _firestore.collection('userTokens').doc(userId).set({
      'token': token,
      'userId': userId,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  // ==================== SOS ALERT METHODS ====================

  /// Send SOS alert to trusted contacts
  Future<void> sendSOSAlert({
    required String senderName,
    required String senderPhone,
    required double latitude,
    required double longitude,
    required String address,
    required List<String> contactUserIds,
    String? message,
  }) async {
    final userId = FirebaseService.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');

    // Create SOS alert document
    final alertRef = await _firestore.collection('sosAlerts').add({
      'senderId': userId,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'message': message,
      'contactIds': contactUserIds,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Get FCM tokens for contacts
    final tokens = await _getTokensForUsers(contactUserIds);

    if (tokens.isEmpty) {
      print('No FCM tokens found for contacts');
      return;
    }

    // Send notifications via Cloud Function or direct FCM
    await _sendNotificationToTokens(
      tokens: tokens,
      title: 'SOS ALERT from $senderName',
      body: message ?? '$senderName needs help! Location: $address',
      data: {
        'type': 'sos_alert',
        'alertId': alertRef.id,
        'senderId': userId,
        'senderName': senderName,
        'senderPhone': senderPhone,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'address': address,
        'mapsUrl': 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      },
    );

    // Log notification sent
    await _firestore.collection('sosAlerts').doc(alertRef.id).update({
      'notificationsSent': tokens.length,
      'notificationsSentAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send SOS alert to all trusted contacts (by phone numbers)
  Future<void> sendSOSAlertToContacts({
    required String senderName,
    required String senderPhone,
    required double latitude,
    required double longitude,
    required String address,
    required List<String> contactPhones,
    String? message,
  }) async {
    // Find user IDs for these phone numbers
    final userIds = await _getUserIdsForPhones(contactPhones);

    if (userIds.isEmpty) {
      print('No registered users found for contact phones');
      // Could fall back to SMS here
      return;
    }

    await sendSOSAlert(
      senderName: senderName,
      senderPhone: senderPhone,
      latitude: latitude,
      longitude: longitude,
      address: address,
      contactUserIds: userIds,
      message: message,
    );
  }

  /// Get FCM tokens for list of user IDs
  Future<List<String>> _getTokensForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final tokens = <String>[];

    // Firestore 'whereIn' has limit of 10
    for (var i = 0; i < userIds.length; i += 10) {
      final batch = userIds.skip(i).take(10).toList();
      final snapshot = await _firestore
          .collection('userTokens')
          .where('userId', whereIn: batch)
          .get();

      for (final doc in snapshot.docs) {
        final token = doc.data()['token'] as String?;
        if (token != null && token.isNotEmpty) {
          tokens.add(token);
        }
      }
    }

    return tokens;
  }

  /// Get user IDs for phone numbers
  Future<List<String>> _getUserIdsForPhones(List<String> phones) async {
    if (phones.isEmpty) return [];

    final userIds = <String>[];

    // Normalize phone numbers
    final normalizedPhones = phones.map((p) => p.replaceAll(RegExp(r'[^\d+]'), '')).toList();

    for (var i = 0; i < normalizedPhones.length; i += 10) {
      final batch = normalizedPhones.skip(i).take(10).toList();
      final snapshot = await _firestore
          .collection('users')
          .where('phone', whereIn: batch)
          .get();

      for (final doc in snapshot.docs) {
        userIds.add(doc.id);
      }
    }

    return userIds;
  }

  /// Send notification to multiple tokens
  Future<void> _sendNotificationToTokens({
    required List<String> tokens,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    // Store notification request in Firestore for Cloud Function to process
    // This is more reliable than sending directly from client
    await _firestore.collection('notificationQueue').add({
      'tokens': tokens,
      'notification': {
        'title': title,
        'body': body,
      },
      'data': data,
      'priority': 'high',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also show local notification to sender as confirmation
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'SOS Alert Sent',
      body: 'Emergency alert sent to ${tokens.length} contact(s)',
      channelId: _sosChannelId,
    );
  }

  // ==================== ESCORT REQUEST NOTIFICATIONS ====================

  /// Send escort request notification to volunteers
  Future<void> sendEscortRequestNotification({
    required String requestId,
    required String userName,
    required String eventName,
    required String address,
    required List<String> volunteerIds,
  }) async {
    final tokens = await _getTokensForUsers(volunteerIds);

    if (tokens.isEmpty) return;

    await _firestore.collection('notificationQueue').add({
      'tokens': tokens,
      'notification': {
        'title': 'New Escort Request',
        'body': '$userName needs an escort to $eventName',
      },
      'data': {
        'type': 'escort_request',
        'requestId': requestId,
        'userName': userName,
        'eventName': eventName,
        'address': address,
      },
      'priority': 'high',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== UTILITY METHODS ====================

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    final userId = FirebaseService.instance.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection('userTokens').doc(userId).delete();
    }
    await _messaging.deleteToken();
    _fcmToken = null;
  }
}
