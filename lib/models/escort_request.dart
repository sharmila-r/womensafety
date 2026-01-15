class EscortRequest {
  final String id;
  final String eventName;
  final String eventLocation;
  final double latitude;
  final double longitude;
  final DateTime eventDateTime;
  final String? notes;
  final String status;
  final String? assignedVolunteerId;
  final String? assignedVolunteerName;
  final DateTime createdAt;

  EscortRequest({
    required this.id,
    required this.eventName,
    required this.eventLocation,
    required this.latitude,
    required this.longitude,
    required this.eventDateTime,
    this.notes,
    this.status = 'pending',
    this.assignedVolunteerId,
    this.assignedVolunteerName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventName': eventName,
        'eventLocation': eventLocation,
        'latitude': latitude,
        'longitude': longitude,
        'eventDateTime': eventDateTime.toIso8601String(),
        'notes': notes,
        'status': status,
        'assignedVolunteerId': assignedVolunteerId,
        'assignedVolunteerName': assignedVolunteerName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory EscortRequest.fromJson(Map<String, dynamic> json) => EscortRequest(
        id: json['id'],
        eventName: json['eventName'],
        eventLocation: json['eventLocation'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        eventDateTime: DateTime.parse(json['eventDateTime']),
        notes: json['notes'],
        status: json['status'] ?? 'pending',
        assignedVolunteerId: json['assignedVolunteerId'],
        assignedVolunteerName: json['assignedVolunteerName'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}
