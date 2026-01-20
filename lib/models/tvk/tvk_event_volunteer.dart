import 'package:cloud_firestore/cloud_firestore.dart';

/// TVK Event Volunteer model for volunteer assignments to events
class TVKEventVolunteer {
  final String id;
  final String eventId;
  final String odcId;
  final String name;
  final String phone;
  final String? photoUrl;
  final TVKVolunteerRole role;
  final String? assignedZoneId;
  final String? assignedZoneName;
  final TVKVolunteerStatus status;
  final double? latitude;
  final double? longitude;
  final DateTime? lastLocationUpdate;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  TVKEventVolunteer({
    required this.id,
    required this.eventId,
    required this.odcId,
    required this.name,
    required this.phone,
    this.photoUrl,
    required this.role,
    this.assignedZoneId,
    this.assignedZoneName,
    required this.status,
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
    this.checkInTime,
    this.checkOutTime,
  });

  factory TVKEventVolunteer.fromFirestore(DocumentSnapshot doc, String eventId) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse location
    double? lat, lng;
    if (data['currentLocation'] is GeoPoint) {
      final geoPoint = data['currentLocation'] as GeoPoint;
      lat = geoPoint.latitude;
      lng = geoPoint.longitude;
    } else if (data['latitude'] != null && data['longitude'] != null) {
      lat = (data['latitude'] as num).toDouble();
      lng = (data['longitude'] as num).toDouble();
    }

    return TVKEventVolunteer(
      id: doc.id,
      eventId: eventId,
      odcId: data['odcId'] ?? data['volunteerId'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      photoUrl: data['photoUrl'],
      role: TVKVolunteerRole.fromString(data['role'] ?? 'general'),
      assignedZoneId: data['assignedZone'] ?? data['assignedZoneId'],
      assignedZoneName: data['assignedZoneName'],
      status: TVKVolunteerStatus.fromString(data['status'] ?? 'offline'),
      latitude: lat,
      longitude: lng,
      lastLocationUpdate: (data['lastLocationUpdate'] as Timestamp?)?.toDate(),
      checkInTime: (data['checkInTime'] as Timestamp?)?.toDate(),
      checkOutTime: (data['checkOutTime'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'odcId': odcId,
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role.value,
      'assignedZone': assignedZoneId,
      'assignedZoneName': assignedZoneName,
      'status': status.value,
      'currentLocation': latitude != null && longitude != null
          ? GeoPoint(latitude!, longitude!)
          : null,
      'lastLocationUpdate': lastLocationUpdate != null
          ? Timestamp.fromDate(lastLocationUpdate!)
          : null,
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
    };
  }

  bool get isActive => status == TVKVolunteerStatus.active;
  bool get isOnBreak => status == TVKVolunteerStatus.onBreak;
  bool get isResponding => status == TVKVolunteerStatus.responding;
  bool get isOffline => status == TVKVolunteerStatus.offline;
  bool get isCheckedIn => checkInTime != null && checkOutTime == null;
  bool get hasLocation => latitude != null && longitude != null;

  /// Get initials for avatar
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Get time since last location update
  String? get locationAge {
    if (lastLocationUpdate == null) return null;
    final diff = DateTime.now().difference(lastLocationUpdate!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

/// Volunteer role in event
enum TVKVolunteerRole {
  coordinator('coordinator'),
  zoneCaptain('zone_captain'),
  medical('medical'),
  security('security'),
  general('general');

  final String value;
  const TVKVolunteerRole(this.value);

  static TVKVolunteerRole fromString(String value) {
    return TVKVolunteerRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TVKVolunteerRole.general,
    );
  }

  String get displayName {
    switch (this) {
      case TVKVolunteerRole.coordinator:
        return 'Coordinator';
      case TVKVolunteerRole.zoneCaptain:
        return 'Zone Captain';
      case TVKVolunteerRole.medical:
        return 'Medical';
      case TVKVolunteerRole.security:
        return 'Security';
      case TVKVolunteerRole.general:
        return 'Volunteer';
    }
  }

  int get sortOrder {
    switch (this) {
      case TVKVolunteerRole.coordinator:
        return 0;
      case TVKVolunteerRole.zoneCaptain:
        return 1;
      case TVKVolunteerRole.medical:
        return 2;
      case TVKVolunteerRole.security:
        return 3;
      case TVKVolunteerRole.general:
        return 4;
    }
  }
}

/// Volunteer status in event
enum TVKVolunteerStatus {
  active('active'),
  onBreak('on_break'),
  responding('responding'),
  offline('offline');

  final String value;
  const TVKVolunteerStatus(this.value);

  static TVKVolunteerStatus fromString(String value) {
    return TVKVolunteerStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TVKVolunteerStatus.offline,
    );
  }

  String get displayName {
    switch (this) {
      case TVKVolunteerStatus.active:
        return 'Active';
      case TVKVolunteerStatus.onBreak:
        return 'On Break';
      case TVKVolunteerStatus.responding:
        return 'Responding';
      case TVKVolunteerStatus.offline:
        return 'Offline';
    }
  }
}
