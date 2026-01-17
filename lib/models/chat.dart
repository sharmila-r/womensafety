import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat conversation between two users (user and volunteer)
class Chat {
  final String id;
  final List<String> participants; // User IDs
  final Map<String, String> participantNames;
  final String? escortRequestId;
  final String? trackingSessionId;
  final Message? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int> unreadCount; // Per participant

  Chat({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.escortRequestId,
    this.trackingSessionId,
    this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = const {},
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      escortRequestId: data['escortRequestId'],
      trackingSessionId: data['trackingSessionId'],
      lastMessage: data['lastMessage'] != null
          ? Message.fromMap(data['lastMessage'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'participants': participants,
        'participantNames': participantNames,
        'escortRequestId': escortRequestId,
        'trackingSessionId': trackingSessionId,
        'lastMessage': lastMessage?.toMap(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'unreadCount': unreadCount,
      };

  /// Get the other participant's ID (not the current user)
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => participants.first,
    );
  }

  /// Get the other participant's name
  String getOtherParticipantName(String currentUserId) {
    final otherId = getOtherParticipantId(currentUserId);
    return participantNames[otherId] ?? 'Unknown';
  }

  /// Get unread count for a specific user
  int getUnreadCount(String userId) {
    return unreadCount[userId] ?? 0;
  }
}

/// Individual message in a chat
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata; // For location, images, etc.

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      metadata: data['metadata'],
    );
  }

  factory Message.fromMap(Map<String, dynamic> data) {
    return Message(
      id: data['id'] ?? '',
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'type': type.name,
        'timestamp': Timestamp.fromDate(timestamp),
        'isRead': isRead,
        'metadata': metadata,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'metadata': metadata,
      };
}

enum MessageType {
  text,
  location,
  image,
  system, // For system messages like "User started tracking"
  sos,    // SOS alert message
}
