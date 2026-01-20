import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// TVK Broadcast model for messages sent to volunteers
class TVKBroadcast {
  final String id;
  final String eventId;
  final TVKBroadcastType type;
  final String title;
  final String message;
  final TVKBroadcastAudience audience;
  final TVKBroadcastSender sentBy;
  final int deliveredTo;
  final List<String> readBy;
  final DateTime createdAt;

  TVKBroadcast({
    required this.id,
    required this.eventId,
    required this.type,
    required this.title,
    required this.message,
    required this.audience,
    required this.sentBy,
    required this.deliveredTo,
    required this.readBy,
    required this.createdAt,
  });

  factory TVKBroadcast.fromFirestore(DocumentSnapshot doc, String eventId) {
    final data = doc.data() as Map<String, dynamic>;
    return TVKBroadcast(
      id: doc.id,
      eventId: eventId,
      type: TVKBroadcastType.fromString(data['type'] ?? 'announcement'),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      audience: TVKBroadcastAudience.fromMap(data['audience'] ?? {}),
      sentBy: TVKBroadcastSender.fromMap(data['sentBy'] ?? {}),
      deliveredTo: data['deliveredTo'] ?? 0,
      readBy: List<String>.from(data['readBy'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'message': message,
      'audience': audience.toMap(),
      'sentBy': sentBy.toMap(),
      'deliveredTo': deliveredTo,
      'readBy': readBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Get time since sent
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Broadcast audience targeting
class TVKBroadcastAudience {
  final TVKAudienceType type;
  final List<String>? roles;
  final List<String>? zones;
  final List<String>? volunteerIds;

  TVKBroadcastAudience({
    required this.type,
    this.roles,
    this.zones,
    this.volunteerIds,
  });

  factory TVKBroadcastAudience.fromMap(Map<String, dynamic> map) {
    return TVKBroadcastAudience(
      type: TVKAudienceType.fromString(map['type'] ?? 'all'),
      roles: map['roles'] != null ? List<String>.from(map['roles']) : null,
      zones: map['zones'] != null ? List<String>.from(map['zones']) : null,
      volunteerIds: map['volunteerIds'] != null ? List<String>.from(map['volunteerIds']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'roles': roles,
      'zones': zones,
      'volunteerIds': volunteerIds,
    };
  }

  String get displayText {
    switch (type) {
      case TVKAudienceType.all:
        return 'All Volunteers';
      case TVKAudienceType.role:
        return roles?.join(', ') ?? 'Selected Roles';
      case TVKAudienceType.zone:
        return zones?.join(', ') ?? 'Selected Zones';
      case TVKAudienceType.specific:
        return '${volunteerIds?.length ?? 0} volunteers';
    }
  }
}

/// Broadcast sender info
class TVKBroadcastSender {
  final String odcId;
  final String name;

  TVKBroadcastSender({
    required this.odcId,
    required this.name,
  });

  factory TVKBroadcastSender.fromMap(Map<String, dynamic> map) {
    return TVKBroadcastSender(
      odcId: map['userId'] ?? '',
      name: map['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': odcId,
      'name': name,
    };
  }
}

/// Broadcast type enum
enum TVKBroadcastType {
  emergency('emergency'),
  announcement('announcement'),
  reassign('reassign'),
  allClear('all_clear');

  final String value;
  const TVKBroadcastType(this.value);

  static TVKBroadcastType fromString(String value) {
    return TVKBroadcastType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TVKBroadcastType.announcement,
    );
  }

  String get displayName {
    switch (this) {
      case TVKBroadcastType.emergency:
        return 'Emergency';
      case TVKBroadcastType.announcement:
        return 'Announcement';
      case TVKBroadcastType.reassign:
        return 'Reassign';
      case TVKBroadcastType.allClear:
        return 'All Clear';
    }
  }

  IconData get icon {
    switch (this) {
      case TVKBroadcastType.emergency:
        return Icons.emergency;
      case TVKBroadcastType.announcement:
        return Icons.campaign;
      case TVKBroadcastType.reassign:
        return Icons.swap_horiz;
      case TVKBroadcastType.allClear:
        return Icons.check_circle;
    }
  }
}

/// Audience type enum
enum TVKAudienceType {
  all('all'),
  role('role'),
  zone('zone'),
  specific('specific');

  final String value;
  const TVKAudienceType(this.value);

  static TVKAudienceType fromString(String value) {
    return TVKAudienceType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TVKAudienceType.all,
    );
  }
}
