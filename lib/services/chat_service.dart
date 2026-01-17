import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat.dart';
import 'firebase_service.dart';
import 'push_notification_service.dart';

/// Service for managing chat conversations and messages
class ChatService {
  final FirebaseService _firebase = FirebaseService.instance;
  final PushNotificationService _pushService = PushNotificationService();

  CollectionReference get _chatsRef => _firebase.firestore.collection('chats');

  String? get _userId => _firebase.auth.currentUser?.uid;

  /// Create or get existing chat between two users
  Future<Chat> getOrCreateChat({
    required String otherUserId,
    required String otherUserName,
    required String currentUserName,
    String? escortRequestId,
    String? trackingSessionId,
  }) async {
    if (_userId == null) throw Exception('User not logged in');

    // Check if chat already exists
    final existingChat = await _findExistingChat(otherUserId);
    if (existingChat != null) {
      return existingChat;
    }

    // Create new chat
    final chat = Chat(
      id: '',
      participants: [_userId!, otherUserId],
      participantNames: {
        _userId!: currentUserName,
        otherUserId: otherUserName,
      },
      escortRequestId: escortRequestId,
      trackingSessionId: trackingSessionId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      unreadCount: {
        _userId!: 0,
        otherUserId: 0,
      },
    );

    final docRef = await _chatsRef.add(chat.toFirestore());
    return Chat(
      id: docRef.id,
      participants: chat.participants,
      participantNames: chat.participantNames,
      escortRequestId: escortRequestId,
      trackingSessionId: trackingSessionId,
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
      unreadCount: chat.unreadCount,
    );
  }

  /// Find existing chat with another user
  Future<Chat?> _findExistingChat(String otherUserId) async {
    if (_userId == null) return null;

    final query = await _chatsRef
        .where('participants', arrayContains: _userId)
        .get();

    for (final doc in query.docs) {
      final chat = Chat.fromFirestore(doc);
      if (chat.participants.contains(otherUserId)) {
        return chat;
      }
    }
    return null;
  }

  /// Get all chats for current user
  Stream<List<Chat>> getChats() {
    if (_userId == null) return Stream.value([]);

    return _chatsRef
        .where('participants', arrayContains: _userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList());
  }

  /// Get a specific chat by ID
  Future<Chat?> getChatById(String chatId) async {
    final doc = await _chatsRef.doc(chatId).get();
    if (!doc.exists) return null;
    return Chat.fromFirestore(doc);
  }

  /// Get messages for a chat (real-time stream)
  Stream<List<Message>> getMessages(String chatId, {int limit = 50}) {
    return _chatsRef
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }

  /// Send a text message
  Future<Message> sendMessage({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    if (_userId == null) throw Exception('User not logged in');

    // Get user name
    final userDoc = await _firebase.firestore
        .collection('users')
        .doc(_userId)
        .get();
    final userName = userDoc.data()?['name'] ?? 'Unknown';

    final message = Message(
      id: '',
      chatId: chatId,
      senderId: _userId!,
      senderName: userName,
      content: content,
      type: type,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    // Add message to subcollection
    final msgRef = await _chatsRef
        .doc(chatId)
        .collection('messages')
        .add(message.toFirestore());

    // Update chat with last message and increment unread count
    final chat = await getChatById(chatId);
    if (chat != null) {
      final otherUserId = chat.getOtherParticipantId(_userId!);
      await _chatsRef.doc(chatId).update({
        'lastMessage': message.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount.$otherUserId': FieldValue.increment(1),
      });

      // Send push notification to other user
      await _sendMessageNotification(
        chatId: chatId,
        recipientId: otherUserId,
        senderName: userName,
        messageContent: content,
      );
    }

    return Message(
      id: msgRef.id,
      chatId: chatId,
      senderId: _userId!,
      senderName: userName,
      content: content,
      type: type,
      timestamp: message.timestamp,
      metadata: metadata,
    );
  }

  /// Send location message
  Future<Message> sendLocationMessage({
    required String chatId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    return sendMessage(
      chatId: chatId,
      content: address ?? 'Shared location',
      type: MessageType.location,
      metadata: {
        'latitude': latitude,
        'longitude': longitude,
        'mapsUrl': mapsUrl,
        'address': address,
      },
    );
  }

  /// Send SOS alert message
  Future<Message> sendSOSMessage({
    required String chatId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    return sendMessage(
      chatId: chatId,
      content: 'SOS ALERT! I need help!',
      type: MessageType.sos,
      metadata: {
        'latitude': latitude,
        'longitude': longitude,
        'mapsUrl': mapsUrl,
        'address': address,
      },
    );
  }

  /// Send system message (e.g., "User started tracking")
  Future<Message> sendSystemMessage({
    required String chatId,
    required String content,
  }) async {
    if (_userId == null) throw Exception('User not logged in');

    final message = Message(
      id: '',
      chatId: chatId,
      senderId: 'system',
      senderName: 'System',
      content: content,
      type: MessageType.system,
      timestamp: DateTime.now(),
    );

    final msgRef = await _chatsRef
        .doc(chatId)
        .collection('messages')
        .add(message.toFirestore());

    // Update chat with last message
    await _chatsRef.doc(chatId).update({
      'lastMessage': message.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return Message(
      id: msgRef.id,
      chatId: chatId,
      senderId: 'system',
      senderName: 'System',
      content: content,
      type: MessageType.system,
      timestamp: message.timestamp,
    );
  }

  /// Mark messages as read
  Future<void> markAsRead(String chatId) async {
    if (_userId == null) return;

    // Reset unread count for current user
    await _chatsRef.doc(chatId).update({
      'unreadCount.$_userId': 0,
    });

    // Mark individual messages as read (optional, for read receipts)
    final unreadMessages = await _chatsRef
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: _userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firebase.firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Get total unread message count for current user
  Stream<int> getTotalUnreadCount() {
    if (_userId == null) return Stream.value(0);

    return _chatsRef
        .where('participants', arrayContains: _userId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final chat = Chat.fromFirestore(doc);
        total += chat.getUnreadCount(_userId!);
      }
      return total;
    });
  }

  /// Delete a chat (soft delete or archive)
  Future<void> deleteChat(String chatId) async {
    // For now, just remove the chat document
    // In production, you might want to archive instead
    await _chatsRef.doc(chatId).delete();
  }

  /// Send push notification for new message
  Future<void> _sendMessageNotification({
    required String chatId,
    required String recipientId,
    required String senderName,
    required String messageContent,
  }) async {
    try {
      // Get recipient's FCM token
      final tokenDoc = await _firebase.firestore
          .collection('userTokens')
          .where('userId', isEqualTo: recipientId)
          .limit(1)
          .get();

      if (tokenDoc.docs.isEmpty) return;

      final token = tokenDoc.docs.first.data()['token'];

      // Create notification queue entry
      await _firebase.firestore.collection('notificationQueue').add({
        'tokens': [token],
        'notification': {
          'title': senderName,
          'body': messageContent.length > 100
              ? '${messageContent.substring(0, 100)}...'
              : messageContent,
        },
        'data': {
          'type': 'chat_message',
          'chatId': chatId,
          'senderId': _userId,
          'senderName': senderName,
        },
        'priority': 'high',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail - notification is not critical
      print('Failed to send message notification: $e');
    }
  }
}
