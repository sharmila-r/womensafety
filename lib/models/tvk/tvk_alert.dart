import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// TVK Alert model for event incidents
class TVKAlert {
  final String id;
  final String eventId;
  final TVKAlertType type;
  final TVKAlertSeverity severity;
  final String title;
  final String description;
  final TVKAlertLocation location;
  final TVKAlertStatus status;
  final TVKAlertCreator createdBy;
  final List<String> assignedTo;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  TVKAlert({
    required this.id,
    required this.eventId,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.location,
    required this.status,
    required this.createdBy,
    required this.assignedTo,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TVKAlert.fromFirestore(DocumentSnapshot doc, String eventId) {
    final data = doc.data() as Map<String, dynamic>;
    return TVKAlert(
      id: doc.id,
      eventId: eventId,
      type: TVKAlertType.fromString(data['type'] ?? 'general'),
      severity: TVKAlertSeverity.fromString(data['severity'] ?? 'medium'),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: TVKAlertLocation.fromMap(data['location'] ?? {}),
      status: TVKAlertStatus.fromString(data['status'] ?? 'active'),
      createdBy: TVKAlertCreator.fromMap(data['createdBy'] ?? {}),
      assignedTo: List<String>.from(data['assignedTo'] ?? []),
      resolvedBy: data['resolvedBy'],
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'severity': severity.value,
      'title': title,
      'description': description,
      'location': location.toMap(),
      'status': status.value,
      'createdBy': createdBy.toMap(),
      'assignedTo': assignedTo,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool get isActive => status == TVKAlertStatus.active;
  bool get isCritical => severity == TVKAlertSeverity.critical;

  /// Get time since created
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Alert location details
class TVKAlertLocation {
  final String? zoneId;
  final String? zoneName;
  final double latitude;
  final double longitude;

  TVKAlertLocation({
    this.zoneId,
    this.zoneName,
    required this.latitude,
    required this.longitude,
  });

  factory TVKAlertLocation.fromMap(Map<String, dynamic> map) {
    return TVKAlertLocation(
      zoneId: map['zoneId'],
      zoneName: map['zoneName'],
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'zoneId': zoneId,
      'zoneName': zoneName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

/// Alert creator info
class TVKAlertCreator {
  final String odcId;
  final String name;
  final String? role;

  TVKAlertCreator({
    required this.odcId,
    required this.name,
    this.role,
  });

  factory TVKAlertCreator.fromMap(Map<String, dynamic> map) {
    return TVKAlertCreator(
      odcId: map['userId'] ?? map['volunteerId'] ?? '',
      name: map['name'] ?? '',
      role: map['role'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': odcId,
      'name': name,
      'role': role,
    };
  }
}

/// Alert type enum
enum TVKAlertType {
  overcrowding('overcrowding'),
  medical('medical'),
  security('security'),
  lostPerson('lost_person'),
  womenSafety('women_safety'),
  general('general');

  final String value;
  const TVKAlertType(this.value);

  static TVKAlertType fromString(String value) {
    return TVKAlertType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TVKAlertType.general,
    );
  }

  String get displayName {
    switch (this) {
      case TVKAlertType.overcrowding:
        return 'Overcrowding';
      case TVKAlertType.medical:
        return 'Medical Emergency';
      case TVKAlertType.security:
        return 'Security Issue';
      case TVKAlertType.lostPerson:
        return 'Lost Person';
      case TVKAlertType.womenSafety:
        return 'Women Safety';
      default:
        return 'General Alert';
    }
  }

  IconData get icon {
    switch (this) {
      case TVKAlertType.overcrowding:
        return Icons.groups;
      case TVKAlertType.medical:
        return Icons.medical_services;
      case TVKAlertType.security:
        return Icons.security;
      case TVKAlertType.lostPerson:
        return Icons.person_search;
      case TVKAlertType.womenSafety:
        return Icons.shield;
      default:
        return Icons.warning;
    }
  }
}

/// Alert severity enum
enum TVKAlertSeverity {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String value;
  const TVKAlertSeverity(this.value);

  static TVKAlertSeverity fromString(String value) {
    return TVKAlertSeverity.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TVKAlertSeverity.medium,
    );
  }

  String get displayName {
    switch (this) {
      case TVKAlertSeverity.low:
        return 'Low';
      case TVKAlertSeverity.medium:
        return 'Medium';
      case TVKAlertSeverity.high:
        return 'High';
      case TVKAlertSeverity.critical:
        return 'Critical';
    }
  }
}

/// Alert status enum
enum TVKAlertStatus {
  active('active'),
  acknowledged('acknowledged'),
  resolved('resolved'),
  escalated('escalated');

  final String value;
  const TVKAlertStatus(this.value);

  static TVKAlertStatus fromString(String value) {
    return TVKAlertStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TVKAlertStatus.active,
    );
  }

  String get displayName {
    switch (this) {
      case TVKAlertStatus.active:
        return 'Active';
      case TVKAlertStatus.acknowledged:
        return 'Acknowledged';
      case TVKAlertStatus.resolved:
        return 'Resolved';
      case TVKAlertStatus.escalated:
        return 'Escalated';
    }
  }
}
