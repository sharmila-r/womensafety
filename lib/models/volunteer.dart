import 'package:cloud_firestore/cloud_firestore.dart';

/// Volunteer verification levels
enum VerificationLevel {
  unverified,    // Just registered
  phoneVerified, // Phone OTP verified
  idVerified,    // Government ID uploaded and verified
  backgroundChecked, // Background check cleared
  trusted,       // Vouched by NGO or admin
}

/// Volunteer availability status
enum AvailabilityStatus {
  available,
  busy,
  offline,
}

/// Volunteer model
class Volunteer {
  final String id;
  final String userId; // Firebase Auth UID
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final String? bio;
  final String country;

  // Verification
  final VerificationLevel verificationLevel;
  final String? idDocumentUrl;
  final String? selfieUrl;
  final DateTime? idVerifiedAt;
  final String? backgroundCheckId;
  final String? backgroundCheckStatus; // pending, cleared, flagged
  final DateTime? backgroundCheckDate;
  final String? verifiedByAdminId;
  final String? vouchedByNgoName;

  // Availability
  final AvailabilityStatus availabilityStatus;
  final bool isAcceptingRequests;
  final double serviceRadiusKm;
  final GeoPoint? currentLocation;
  final List<String> availableDays; // ['monday', 'tuesday', ...]
  final String? availableTimeStart; // '09:00'
  final String? availableTimeEnd;   // '21:00'

  // Stats
  final int totalEscorts;
  final double averageRating;
  final int ratingCount;
  final int cancelledCount;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActiveAt;

  Volunteer({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
    this.bio,
    required this.country,
    this.verificationLevel = VerificationLevel.unverified,
    this.idDocumentUrl,
    this.selfieUrl,
    this.idVerifiedAt,
    this.backgroundCheckId,
    this.backgroundCheckStatus,
    this.backgroundCheckDate,
    this.verifiedByAdminId,
    this.vouchedByNgoName,
    this.availabilityStatus = AvailabilityStatus.offline,
    this.isAcceptingRequests = false,
    this.serviceRadiusKm = 10.0,
    this.currentLocation,
    this.availableDays = const [],
    this.availableTimeStart,
    this.availableTimeEnd,
    this.totalEscorts = 0,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.cancelledCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.lastActiveAt,
  });

  /// Check if volunteer is fully verified
  bool get isFullyVerified =>
      verificationLevel == VerificationLevel.backgroundChecked ||
      verificationLevel == VerificationLevel.trusted;

  /// Check if volunteer can accept escort requests
  bool get canAcceptRequests =>
      isFullyVerified &&
      isAcceptingRequests &&
      availabilityStatus == AvailabilityStatus.available;

  /// Get verification badge text
  String get verificationBadge {
    switch (verificationLevel) {
      case VerificationLevel.trusted:
        return 'Trusted';
      case VerificationLevel.backgroundChecked:
        return 'Verified';
      case VerificationLevel.idVerified:
        return 'ID Verified';
      case VerificationLevel.phoneVerified:
        return 'Phone Verified';
      case VerificationLevel.unverified:
        return 'Unverified';
    }
  }

  factory Volunteer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Volunteer(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      country: data['country'] ?? 'US',
      verificationLevel: VerificationLevel.values.firstWhere(
        (e) => e.name == data['verificationLevel'],
        orElse: () => VerificationLevel.unverified,
      ),
      idDocumentUrl: data['idDocumentUrl'],
      selfieUrl: data['selfieUrl'],
      idVerifiedAt: (data['idVerifiedAt'] as Timestamp?)?.toDate(),
      backgroundCheckId: data['backgroundCheckId'],
      backgroundCheckStatus: data['backgroundCheckStatus'],
      backgroundCheckDate: (data['backgroundCheckDate'] as Timestamp?)?.toDate(),
      verifiedByAdminId: data['verifiedByAdminId'],
      vouchedByNgoName: data['vouchedByNgoName'],
      availabilityStatus: AvailabilityStatus.values.firstWhere(
        (e) => e.name == data['availabilityStatus'],
        orElse: () => AvailabilityStatus.offline,
      ),
      isAcceptingRequests: data['isAcceptingRequests'] ?? false,
      serviceRadiusKm: (data['serviceRadiusKm'] ?? 10.0).toDouble(),
      currentLocation: data['currentLocation'] as GeoPoint?,
      availableDays: List<String>.from(data['availableDays'] ?? []),
      availableTimeStart: data['availableTimeStart'],
      availableTimeEnd: data['availableTimeEnd'],
      totalEscorts: data['totalEscorts'] ?? 0,
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      cancelledCount: data['cancelledCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'name': name,
    'phone': phone,
    'email': email,
    'photoUrl': photoUrl,
    'bio': bio,
    'country': country,
    'verificationLevel': verificationLevel.name,
    'idDocumentUrl': idDocumentUrl,
    'selfieUrl': selfieUrl,
    'idVerifiedAt': idVerifiedAt != null ? Timestamp.fromDate(idVerifiedAt!) : null,
    'backgroundCheckId': backgroundCheckId,
    'backgroundCheckStatus': backgroundCheckStatus,
    'backgroundCheckDate': backgroundCheckDate != null ? Timestamp.fromDate(backgroundCheckDate!) : null,
    'verifiedByAdminId': verifiedByAdminId,
    'vouchedByNgoName': vouchedByNgoName,
    'availabilityStatus': availabilityStatus.name,
    'isAcceptingRequests': isAcceptingRequests,
    'serviceRadiusKm': serviceRadiusKm,
    'currentLocation': currentLocation,
    'availableDays': availableDays,
    'availableTimeStart': availableTimeStart,
    'availableTimeEnd': availableTimeEnd,
    'totalEscorts': totalEscorts,
    'averageRating': averageRating,
    'ratingCount': ratingCount,
    'cancelledCount': cancelledCount,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
    'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
  };

  Volunteer copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? email,
    String? photoUrl,
    String? bio,
    String? country,
    VerificationLevel? verificationLevel,
    String? idDocumentUrl,
    String? selfieUrl,
    DateTime? idVerifiedAt,
    String? backgroundCheckId,
    String? backgroundCheckStatus,
    DateTime? backgroundCheckDate,
    String? verifiedByAdminId,
    String? vouchedByNgoName,
    AvailabilityStatus? availabilityStatus,
    bool? isAcceptingRequests,
    double? serviceRadiusKm,
    GeoPoint? currentLocation,
    List<String>? availableDays,
    String? availableTimeStart,
    String? availableTimeEnd,
    int? totalEscorts,
    double? averageRating,
    int? ratingCount,
    int? cancelledCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActiveAt,
  }) {
    return Volunteer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      country: country ?? this.country,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      idDocumentUrl: idDocumentUrl ?? this.idDocumentUrl,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      idVerifiedAt: idVerifiedAt ?? this.idVerifiedAt,
      backgroundCheckId: backgroundCheckId ?? this.backgroundCheckId,
      backgroundCheckStatus: backgroundCheckStatus ?? this.backgroundCheckStatus,
      backgroundCheckDate: backgroundCheckDate ?? this.backgroundCheckDate,
      verifiedByAdminId: verifiedByAdminId ?? this.verifiedByAdminId,
      vouchedByNgoName: vouchedByNgoName ?? this.vouchedByNgoName,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      isAcceptingRequests: isAcceptingRequests ?? this.isAcceptingRequests,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      currentLocation: currentLocation ?? this.currentLocation,
      availableDays: availableDays ?? this.availableDays,
      availableTimeStart: availableTimeStart ?? this.availableTimeStart,
      availableTimeEnd: availableTimeEnd ?? this.availableTimeEnd,
      totalEscorts: totalEscorts ?? this.totalEscorts,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}

/// Volunteer rating model
class VolunteerRating {
  final String id;
  final String volunteerId;
  final String escortRequestId;
  final String userId;
  final int rating; // 1-5
  final String? comment;
  final DateTime createdAt;

  VolunteerRating({
    required this.id,
    required this.volunteerId,
    required this.escortRequestId,
    required this.userId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory VolunteerRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VolunteerRating(
      id: doc.id,
      volunteerId: data['volunteerId'] ?? '',
      escortRequestId: data['escortRequestId'] ?? '',
      userId: data['userId'] ?? '',
      rating: data['rating'] ?? 0,
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'volunteerId': volunteerId,
    'escortRequestId': escortRequestId,
    'userId': userId,
    'rating': rating,
    'comment': comment,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
