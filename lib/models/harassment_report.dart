class HarassmentReport {
  final String id;
  final String harassmentType;
  final String description;
  final String? imagePath;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime reportedAt;
  final String status;
  final String? harasserDescription;

  HarassmentReport({
    required this.id,
    required this.harassmentType,
    required this.description,
    this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.reportedAt,
    this.status = 'pending',
    this.harasserDescription,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'harassmentType': harassmentType,
        'description': description,
        'imagePath': imagePath,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'reportedAt': reportedAt.toIso8601String(),
        'status': status,
        'harasserDescription': harasserDescription,
      };

  factory HarassmentReport.fromJson(Map<String, dynamic> json) =>
      HarassmentReport(
        id: json['id'],
        harassmentType: json['harassmentType'] ?? 'Other',
        description: json['description'],
        imagePath: json['imagePath'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        address: json['address'],
        reportedAt: DateTime.parse(json['reportedAt']),
        status: json['status'] ?? 'pending',
        harasserDescription: json['harasserDescription'],
      );
}
