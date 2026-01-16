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
  responding, // Actively responding to SOS
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
  final DateTime? dateOfBirth;

  // KYC Stage (Stage 2)
  final bool aadhaarVerified;
  final double? faceMatchScore;
  final bool livenessPasssed;
  final DateTime? kycCompletedAt;

  // Verification
  final VerificationLevel verificationLevel;
  final String? idDocumentUrl;
  final String? selfieUrl;
  final DateTime? idVerifiedAt;
  final String? backgroundCheckId;
  final String? backgroundCheckStatus; // pending, in_progress, completed, review_required, rejected
  final Map<String, dynamic>? bgvChecks; // Store individual check results
  final DateTime? backgroundCheckDate;
  final DateTime? bgvCompletedAt;
  final String? verifiedByAdminId;
  final String? vouchedByNgoName;
  final DateTime? lastVerifiedAt; // For annual re-verification

  // Availability
  final AvailabilityStatus availabilityStatus;
  final bool isAcceptingRequests;
  final bool sosAlertOptIn; // Opt-in to receive SOS alerts from nearby users
  final String? currentSOSAlertId; // Currently responding to this SOS
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
    this.dateOfBirth,
    this.aadhaarVerified = false,
    this.faceMatchScore,
    this.livenessPasssed = false,
    this.kycCompletedAt,
    this.verificationLevel = VerificationLevel.unverified,
    this.idDocumentUrl,
    this.selfieUrl,
    this.idVerifiedAt,
    this.backgroundCheckId,
    this.backgroundCheckStatus,
    this.bgvChecks,
    this.backgroundCheckDate,
    this.bgvCompletedAt,
    this.verifiedByAdminId,
    this.vouchedByNgoName,
    this.lastVerifiedAt,
    this.availabilityStatus = AvailabilityStatus.offline,
    this.isAcceptingRequests = false,
    this.sosAlertOptIn = false,
    this.currentSOSAlertId,
    this.serviceRadiusKm = 0.0, // Default to 0, set based on verification level
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

  /// Check if volunteer is fully verified (Stage 3 complete)
  bool get isFullyVerified =>
      verificationLevel == VerificationLevel.backgroundChecked ||
      verificationLevel == VerificationLevel.trusted;

  /// Check if volunteer has basic KYC (Stage 2 complete)
  bool get hasBasicKyc =>
      verificationLevel.index >= VerificationLevel.idVerified.index;

  /// Check if volunteer can accept escort requests
  /// Full responders (Stage 3) can respond within 5km
  /// Limited responders (Stage 2) can respond within 500m
  bool get canAcceptRequests =>
      hasBasicKyc &&
      isAcceptingRequests &&
      availabilityStatus == AvailabilityStatus.available;

  /// Get service radius based on verification level (in km)
  double get effectiveServiceRadius {
    switch (verificationLevel) {
      case VerificationLevel.trusted:
      case VerificationLevel.backgroundChecked:
        return 5.0; // 5km - Full responder
      case VerificationLevel.idVerified:
        return 0.5; // 500m - Limited responder
      case VerificationLevel.phoneVerified:
      case VerificationLevel.unverified:
        return 0.0; // Cannot respond
    }
  }

  /// Get verification badge text
  String get verificationBadge {
    switch (verificationLevel) {
      case VerificationLevel.trusted:
        return 'Trusted';
      case VerificationLevel.backgroundChecked:
        return 'Active';
      case VerificationLevel.idVerified:
        return 'Verified';
      case VerificationLevel.phoneVerified:
        return 'Registered';
      case VerificationLevel.unverified:
        return 'Unverified';
    }
  }

  /// Get status description
  String get statusDescription {
    switch (verificationLevel) {
      case VerificationLevel.trusted:
      case VerificationLevel.backgroundChecked:
        return 'Full responder (5km radius)';
      case VerificationLevel.idVerified:
        return 'Limited responder (500m radius)';
      case VerificationLevel.phoneVerified:
        return 'View only, cannot respond';
      case VerificationLevel.unverified:
        return 'Complete registration to continue';
    }
  }

  /// Check if annual re-verification is needed
  bool get needsReverification {
    if (lastVerifiedAt == null) return false;
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    return lastVerifiedAt!.isBefore(oneYearAgo);
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
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate(),
      aadhaarVerified: data['aadhaarVerified'] ?? false,
      faceMatchScore: data['faceMatchScore']?.toDouble(),
      livenessPasssed: data['livenessPasssed'] ?? false,
      kycCompletedAt: (data['kycCompletedAt'] as Timestamp?)?.toDate(),
      verificationLevel: VerificationLevel.values.firstWhere(
        (e) => e.name == data['verificationLevel'],
        orElse: () => VerificationLevel.unverified,
      ),
      idDocumentUrl: data['idDocumentUrl'],
      selfieUrl: data['selfieUrl'],
      idVerifiedAt: (data['idVerifiedAt'] as Timestamp?)?.toDate(),
      backgroundCheckId: data['backgroundCheckId'],
      backgroundCheckStatus: data['backgroundCheckStatus'],
      bgvChecks: data['bgvChecks'] as Map<String, dynamic>?,
      backgroundCheckDate: (data['backgroundCheckDate'] as Timestamp?)?.toDate(),
      bgvCompletedAt: (data['bgvCompletedAt'] as Timestamp?)?.toDate(),
      verifiedByAdminId: data['verifiedByAdminId'],
      vouchedByNgoName: data['vouchedByNgoName'],
      lastVerifiedAt: (data['lastVerifiedAt'] as Timestamp?)?.toDate(),
      availabilityStatus: AvailabilityStatus.values.firstWhere(
        (e) => e.name == data['availabilityStatus'],
        orElse: () => AvailabilityStatus.offline,
      ),
      isAcceptingRequests: data['isAcceptingRequests'] ?? false,
      sosAlertOptIn: data['sosAlertOptIn'] ?? false,
      currentSOSAlertId: data['currentSOSAlertId'],
      serviceRadiusKm: (data['serviceRadiusKm'] ?? 0.0).toDouble(),
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
    'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
    'aadhaarVerified': aadhaarVerified,
    'faceMatchScore': faceMatchScore,
    'livenessPasssed': livenessPasssed,
    'kycCompletedAt': kycCompletedAt != null ? Timestamp.fromDate(kycCompletedAt!) : null,
    'verificationLevel': verificationLevel.name,
    'idDocumentUrl': idDocumentUrl,
    'selfieUrl': selfieUrl,
    'idVerifiedAt': idVerifiedAt != null ? Timestamp.fromDate(idVerifiedAt!) : null,
    'backgroundCheckId': backgroundCheckId,
    'backgroundCheckStatus': backgroundCheckStatus,
    'bgvChecks': bgvChecks,
    'backgroundCheckDate': backgroundCheckDate != null ? Timestamp.fromDate(backgroundCheckDate!) : null,
    'bgvCompletedAt': bgvCompletedAt != null ? Timestamp.fromDate(bgvCompletedAt!) : null,
    'verifiedByAdminId': verifiedByAdminId,
    'vouchedByNgoName': vouchedByNgoName,
    'lastVerifiedAt': lastVerifiedAt != null ? Timestamp.fromDate(lastVerifiedAt!) : null,
    'availabilityStatus': availabilityStatus.name,
    'isAcceptingRequests': isAcceptingRequests,
    'sosAlertOptIn': sosAlertOptIn,
    'currentSOSAlertId': currentSOSAlertId,
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
    DateTime? dateOfBirth,
    bool? aadhaarVerified,
    double? faceMatchScore,
    bool? livenessPasssed,
    DateTime? kycCompletedAt,
    VerificationLevel? verificationLevel,
    String? idDocumentUrl,
    String? selfieUrl,
    DateTime? idVerifiedAt,
    String? backgroundCheckId,
    String? backgroundCheckStatus,
    Map<String, dynamic>? bgvChecks,
    DateTime? backgroundCheckDate,
    DateTime? bgvCompletedAt,
    String? verifiedByAdminId,
    String? vouchedByNgoName,
    DateTime? lastVerifiedAt,
    AvailabilityStatus? availabilityStatus,
    bool? isAcceptingRequests,
    bool? sosAlertOptIn,
    String? currentSOSAlertId,
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
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      faceMatchScore: faceMatchScore ?? this.faceMatchScore,
      livenessPasssed: livenessPasssed ?? this.livenessPasssed,
      kycCompletedAt: kycCompletedAt ?? this.kycCompletedAt,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      idDocumentUrl: idDocumentUrl ?? this.idDocumentUrl,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      idVerifiedAt: idVerifiedAt ?? this.idVerifiedAt,
      backgroundCheckId: backgroundCheckId ?? this.backgroundCheckId,
      backgroundCheckStatus: backgroundCheckStatus ?? this.backgroundCheckStatus,
      bgvChecks: bgvChecks ?? this.bgvChecks,
      backgroundCheckDate: backgroundCheckDate ?? this.backgroundCheckDate,
      bgvCompletedAt: bgvCompletedAt ?? this.bgvCompletedAt,
      verifiedByAdminId: verifiedByAdminId ?? this.verifiedByAdminId,
      vouchedByNgoName: vouchedByNgoName ?? this.vouchedByNgoName,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      isAcceptingRequests: isAcceptingRequests ?? this.isAcceptingRequests,
      sosAlertOptIn: sosAlertOptIn ?? this.sosAlertOptIn,
      currentSOSAlertId: currentSOSAlertId ?? this.currentSOSAlertId,
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
