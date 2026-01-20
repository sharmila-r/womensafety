import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// TVK Zone model representing an area within an event venue
class TVKZone {
  final String id;
  final String eventId;
  final String name;
  final TVKZoneType type;
  final List<LatLng> polygon;
  final LatLng center;
  final int capacity;
  final int currentCount;
  final double densityPercent;
  final TVKZoneStatus status;
  final List<String> assignedVolunteers;
  final DateTime lastUpdated;

  TVKZone({
    required this.id,
    required this.eventId,
    required this.name,
    required this.type,
    required this.polygon,
    required this.center,
    required this.capacity,
    required this.currentCount,
    required this.densityPercent,
    required this.status,
    required this.assignedVolunteers,
    required this.lastUpdated,
  });

  factory TVKZone.fromFirestore(DocumentSnapshot doc, String eventId) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse polygon points
    final polygonData = data['polygon'] as List<dynamic>? ?? [];
    final polygon = polygonData.map((point) {
      if (point is GeoPoint) {
        return LatLng(point.latitude, point.longitude);
      } else if (point is Map) {
        return LatLng(
          (point['latitude'] ?? 0).toDouble(),
          (point['longitude'] ?? 0).toDouble(),
        );
      }
      return const LatLng(0, 0);
    }).toList();

    // Parse center point
    LatLng center;
    if (data['center'] is GeoPoint) {
      final geoPoint = data['center'] as GeoPoint;
      center = LatLng(geoPoint.latitude, geoPoint.longitude);
    } else if (data['center'] is Map) {
      center = LatLng(
        (data['center']['latitude'] ?? 0).toDouble(),
        (data['center']['longitude'] ?? 0).toDouble(),
      );
    } else {
      center = const LatLng(0, 0);
    }

    return TVKZone(
      id: doc.id,
      eventId: eventId,
      name: data['name'] ?? '',
      type: TVKZoneType.fromString(data['type'] ?? 'general'),
      polygon: polygon,
      center: center,
      capacity: data['capacity'] ?? 0,
      currentCount: data['currentCount'] ?? 0,
      densityPercent: (data['densityPercent'] ?? 0).toDouble(),
      status: TVKZoneStatus.fromString(data['status'] ?? 'safe'),
      assignedVolunteers: List<String>.from(data['assignedVolunteers'] ?? []),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.value,
      'polygon': polygon.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
      'center': GeoPoint(center.latitude, center.longitude),
      'capacity': capacity,
      'currentCount': currentCount,
      'densityPercent': densityPercent,
      'status': status.value,
      'assignedVolunteers': assignedVolunteers,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Create a copy with updated crowd count
  TVKZone copyWithCount(int newCount) {
    final newDensity = capacity > 0 ? (newCount / capacity * 100) : 0.0;
    TVKZoneStatus newStatus;

    if (newDensity >= 85) {
      newStatus = TVKZoneStatus.danger;
    } else if (newDensity >= 70) {
      newStatus = TVKZoneStatus.warning;
    } else {
      newStatus = TVKZoneStatus.safe;
    }

    return TVKZone(
      id: id,
      eventId: eventId,
      name: name,
      type: type,
      polygon: polygon,
      center: center,
      capacity: capacity,
      currentCount: newCount,
      densityPercent: newDensity,
      status: newStatus,
      assignedVolunteers: assignedVolunteers,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get display icon for zone type
  String get typeIcon {
    switch (type) {
      case TVKZoneType.entry:
        return 'entry';
      case TVKZoneType.exit:
        return 'exit';
      case TVKZoneType.stage:
        return 'stage';
      case TVKZoneType.amenity:
        return 'amenity';
      case TVKZoneType.emergency:
        return 'emergency';
      default:
        return 'general';
    }
  }
}

/// Zone type enum
enum TVKZoneType {
  entry('entry'),
  exit('exit'),
  stage('stage'),
  amenity('amenity'),
  emergency('emergency'),
  general('general');

  final String value;
  const TVKZoneType(this.value);

  static TVKZoneType fromString(String value) {
    return TVKZoneType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TVKZoneType.general,
    );
  }

  String get displayName {
    switch (this) {
      case TVKZoneType.entry:
        return 'Entry Gate';
      case TVKZoneType.exit:
        return 'Exit Gate';
      case TVKZoneType.stage:
        return 'Stage Area';
      case TVKZoneType.amenity:
        return 'Amenity';
      case TVKZoneType.emergency:
        return 'Emergency Point';
      default:
        return 'General Area';
    }
  }
}

/// Zone status based on crowd density
enum TVKZoneStatus {
  safe('safe'),
  warning('warning'),
  danger('danger'),
  critical('critical');

  final String value;
  const TVKZoneStatus(this.value);

  static TVKZoneStatus fromString(String value) {
    return TVKZoneStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TVKZoneStatus.safe,
    );
  }

  String get displayName {
    switch (this) {
      case TVKZoneStatus.safe:
        return 'Safe';
      case TVKZoneStatus.warning:
        return 'Warning';
      case TVKZoneStatus.danger:
        return 'Danger';
      case TVKZoneStatus.critical:
        return 'Critical';
    }
  }
}
