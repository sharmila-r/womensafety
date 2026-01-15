class HarassmentReport {
  final String id;
  final String description;
  final String? imagePath;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime timestamp;
  final String status;
  final String? harasserDescription;

  HarassmentReport({
    required this.id,
    required this.description,
    this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.timestamp,
    this.status = 'pending',
    this.harasserDescription,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'imagePath': imagePath,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'timestamp': timestamp.toIso8601String(),
        'status': status,
        'harasserDescription': harasserDescription,
      };

  factory HarassmentReport.fromJson(Map<String, dynamic> json) =>
      HarassmentReport(
        id: json['id'],
        description: json['description'],
        imagePath: json['imagePath'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        address: json['address'],
        timestamp: DateTime.parse(json['timestamp']),
        status: json['status'] ?? 'pending',
        harasserDescription: json['harasserDescription'],
      );
}
