import 'package:cloud_firestore/cloud_firestore.dart';

/// TVK Event model representing a crowd safety event
class TVKEvent {
  final String id;
  final String name;
  final String description;
  final TVKEventLocation location;
  final DateTime startTime;
  final DateTime endTime;
  final TVKEventStatus status;
  final int capacity;
  final TVKEventSettings settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  TVKEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.capacity,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TVKEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TVKEvent(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      location: TVKEventLocation.fromMap(data['location'] ?? {}),
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: TVKEventStatus.fromString(data['status'] ?? 'draft'),
      capacity: data['capacity'] ?? 0,
      settings: TVKEventSettings.fromMap(data['settings'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'location': location.toMap(),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status.value,
      'capacity': capacity,
      'settings': settings.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool get isActive => status == TVKEventStatus.active;
  bool get isUpcoming => status == TVKEventStatus.draft && startTime.isAfter(DateTime.now());
  bool get isCompleted => status == TVKEventStatus.completed;
}

/// Event location details
class TVKEventLocation {
  final String address;
  final String venue;
  final double latitude;
  final double longitude;

  TVKEventLocation({
    required this.address,
    required this.venue,
    required this.latitude,
    required this.longitude,
  });

  factory TVKEventLocation.fromMap(Map<String, dynamic> map) {
    return TVKEventLocation(
      address: map['address'] ?? '',
      venue: map['venue'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'venue': venue,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

/// Event settings for thresholds
class TVKEventSettings {
  final int warningDensityThreshold;
  final int dangerDensityThreshold;
  final double alertRadiusKm;

  TVKEventSettings({
    this.warningDensityThreshold = 70,
    this.dangerDensityThreshold = 85,
    this.alertRadiusKm = 5.0,
  });

  factory TVKEventSettings.fromMap(Map<String, dynamic> map) {
    return TVKEventSettings(
      warningDensityThreshold: map['warningDensityThreshold'] ?? 70,
      dangerDensityThreshold: map['dangerDensityThreshold'] ?? 85,
      alertRadiusKm: (map['alertRadiusKm'] ?? 5.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'warningDensityThreshold': warningDensityThreshold,
      'dangerDensityThreshold': dangerDensityThreshold,
      'alertRadiusKm': alertRadiusKm,
    };
  }
}

/// Event status enum
enum TVKEventStatus {
  draft('draft'),
  active('active'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const TVKEventStatus(this.value);

  static TVKEventStatus fromString(String value) {
    return TVKEventStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TVKEventStatus.draft,
    );
  }
}
