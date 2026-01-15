import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/volunteer.dart';

/// NGO Partner status
enum NGOStatus {
  pending,    // Applied, awaiting verification
  verified,   // Verified and active
  suspended,  // Temporarily suspended
  rejected,   // Application rejected
}

/// NGO Partner model
class NGOPartner {
  final String id;
  final String name;
  final String registrationNumber;
  final String email;
  final String phone;
  final String? website;
  final String address;
  final String city;
  final String state;
  final String country;
  final String description;
  final List<String> focusAreas; // domestic_violence, trafficking, harassment, etc.
  final NGOStatus status;
  final String? verifiedByAdminId;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Contact person
  final String contactPersonName;
  final String contactPersonRole;
  final String contactPersonPhone;
  final String contactPersonEmail;

  // Capabilities
  final bool canReceiveAlerts;
  final bool canVouchVolunteers;
  final bool canReceiveReports;
  final double serviceRadiusKm;
  final GeoPoint? location;

  // Stats
  final int volunteersVouched;
  final int alertsResponded;
  final int reportsHandled;

  NGOPartner({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.email,
    required this.phone,
    this.website,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.description,
    required this.focusAreas,
    this.status = NGOStatus.pending,
    this.verifiedByAdminId,
    this.verifiedAt,
    required this.createdAt,
    this.updatedAt,
    required this.contactPersonName,
    required this.contactPersonRole,
    required this.contactPersonPhone,
    required this.contactPersonEmail,
    this.canReceiveAlerts = false,
    this.canVouchVolunteers = false,
    this.canReceiveReports = false,
    this.serviceRadiusKm = 50,
    this.location,
    this.volunteersVouched = 0,
    this.alertsResponded = 0,
    this.reportsHandled = 0,
  });

  factory NGOPartner.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NGOPartner(
      id: doc.id,
      name: data['name'] ?? '',
      registrationNumber: data['registrationNumber'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      website: data['website'],
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      country: data['country'] ?? '',
      description: data['description'] ?? '',
      focusAreas: List<String>.from(data['focusAreas'] ?? []),
      status: NGOStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => NGOStatus.pending,
      ),
      verifiedByAdminId: data['verifiedByAdminId'],
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      contactPersonName: data['contactPersonName'] ?? '',
      contactPersonRole: data['contactPersonRole'] ?? '',
      contactPersonPhone: data['contactPersonPhone'] ?? '',
      contactPersonEmail: data['contactPersonEmail'] ?? '',
      canReceiveAlerts: data['canReceiveAlerts'] ?? false,
      canVouchVolunteers: data['canVouchVolunteers'] ?? false,
      canReceiveReports: data['canReceiveReports'] ?? false,
      serviceRadiusKm: (data['serviceRadiusKm'] ?? 50).toDouble(),
      location: data['location'] as GeoPoint?,
      volunteersVouched: data['volunteersVouched'] ?? 0,
      alertsResponded: data['alertsResponded'] ?? 0,
      reportsHandled: data['reportsHandled'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'registrationNumber': registrationNumber,
    'email': email,
    'phone': phone,
    'website': website,
    'address': address,
    'city': city,
    'state': state,
    'country': country,
    'description': description,
    'focusAreas': focusAreas,
    'status': status.name,
    'verifiedByAdminId': verifiedByAdminId,
    'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
    'contactPersonName': contactPersonName,
    'contactPersonRole': contactPersonRole,
    'contactPersonPhone': contactPersonPhone,
    'contactPersonEmail': contactPersonEmail,
    'canReceiveAlerts': canReceiveAlerts,
    'canVouchVolunteers': canVouchVolunteers,
    'canReceiveReports': canReceiveReports,
    'serviceRadiusKm': serviceRadiusKm,
    'location': location,
    'volunteersVouched': volunteersVouched,
    'alertsResponded': alertsResponded,
    'reportsHandled': reportsHandled,
  };
}

/// Alert sent to NGO
class NGOAlert {
  final String id;
  final String ngoId;
  final String alertType; // sos, escort_request, report
  final String sourceId; // ID of the alert/report/request
  final String? userId;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String status; // pending, acknowledged, responded, closed
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? respondedAt;
  final String? responseNotes;

  NGOAlert({
    required this.id,
    required this.ngoId,
    required this.alertType,
    required this.sourceId,
    this.userId,
    this.latitude,
    this.longitude,
    this.address,
    this.status = 'pending',
    required this.createdAt,
    this.acknowledgedAt,
    this.respondedAt,
    this.responseNotes,
  });

  factory NGOAlert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NGOAlert(
      id: doc.id,
      ngoId: data['ngoId'] ?? '',
      alertType: data['alertType'] ?? '',
      sourceId: data['sourceId'] ?? '',
      userId: data['userId'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      address: data['address'],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acknowledgedAt: (data['acknowledgedAt'] as Timestamp?)?.toDate(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      responseNotes: data['responseNotes'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'ngoId': ngoId,
    'alertType': alertType,
    'sourceId': sourceId,
    'userId': userId,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
    'acknowledgedAt': acknowledgedAt != null ? Timestamp.fromDate(acknowledgedAt!) : null,
    'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    'responseNotes': responseNotes,
  };
}

/// NGO Partner Service
class NGOService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ngosRef =>
      _firestore.collection('ngoPartners');

  CollectionReference<Map<String, dynamic>> get _alertsRef =>
      _firestore.collection('ngoAlerts');

  CollectionReference<Map<String, dynamic>> get _volunteersRef =>
      _firestore.collection('volunteers');

  // ==================== NGO REGISTRATION ====================

  /// Register a new NGO partner
  Future<String> registerNGO({
    required String name,
    required String registrationNumber,
    required String email,
    required String phone,
    String? website,
    required String address,
    required String city,
    required String state,
    required String country,
    required String description,
    required List<String> focusAreas,
    required String contactPersonName,
    required String contactPersonRole,
    required String contactPersonPhone,
    required String contactPersonEmail,
    GeoPoint? location,
  }) async {
    // Check if already registered
    final existing = await _ngosRef
        .where('registrationNumber', isEqualTo: registrationNumber)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('NGO with this registration number already exists');
    }

    final ngo = NGOPartner(
      id: '',
      name: name,
      registrationNumber: registrationNumber,
      email: email,
      phone: phone,
      website: website,
      address: address,
      city: city,
      state: state,
      country: country,
      description: description,
      focusAreas: focusAreas,
      contactPersonName: contactPersonName,
      contactPersonRole: contactPersonRole,
      contactPersonPhone: contactPersonPhone,
      contactPersonEmail: contactPersonEmail,
      location: location,
      createdAt: DateTime.now(),
    );

    final docRef = await _ngosRef.add(ngo.toFirestore());
    return docRef.id;
  }

  /// Get NGO by ID
  Future<NGOPartner?> getNGOById(String id) async {
    final doc = await _ngosRef.doc(id).get();
    if (!doc.exists) return null;
    return NGOPartner.fromFirestore(doc);
  }

  /// Get all verified NGOs
  Future<List<NGOPartner>> getVerifiedNGOs() async {
    final snapshot = await _ngosRef
        .where('status', isEqualTo: NGOStatus.verified.name)
        .get();
    return snapshot.docs.map((doc) => NGOPartner.fromFirestore(doc)).toList();
  }

  /// Get NGOs by focus area
  Future<List<NGOPartner>> getNGOsByFocusArea(String focusArea) async {
    final snapshot = await _ngosRef
        .where('status', isEqualTo: NGOStatus.verified.name)
        .where('focusAreas', arrayContains: focusArea)
        .get();
    return snapshot.docs.map((doc) => NGOPartner.fromFirestore(doc)).toList();
  }

  /// Get nearby NGOs (for alert routing)
  Future<List<NGOPartner>> getNearbyNGOs({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    String? focusArea,
  }) async {
    final allNGOs = focusArea != null
        ? await getNGOsByFocusArea(focusArea)
        : await getVerifiedNGOs();

    // Filter by distance
    return allNGOs.where((ngo) {
      if (ngo.location == null) return false;
      final distance = _haversineDistance(
        latitude, longitude,
        ngo.location!.latitude, ngo.location!.longitude,
      );
      return distance <= ngo.serviceRadiusKm;
    }).toList();
  }

  // ==================== VOLUNTEER VOUCHING ====================

  /// Vouch for a volunteer (by verified NGO)
  Future<void> vouchVolunteer({
    required String ngoId,
    required String volunteerId,
    required String ngoName,
  }) async {
    final ngo = await getNGOById(ngoId);
    if (ngo == null) throw Exception('NGO not found');
    if (ngo.status != NGOStatus.verified) throw Exception('NGO not verified');
    if (!ngo.canVouchVolunteers) throw Exception('NGO cannot vouch volunteers');

    // Update volunteer
    await _volunteersRef.doc(volunteerId).update({
      'verificationLevel': VerificationLevel.trusted.name,
      'vouchedByNgoName': ngoName,
      'lastVerifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update NGO stats
    await _ngosRef.doc(ngoId).update({
      'volunteersVouched': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get volunteers vouched by NGO
  Future<List<Volunteer>> getVouchedVolunteers(String ngoName) async {
    final snapshot = await _volunteersRef
        .where('vouchedByNgoName', isEqualTo: ngoName)
        .get();
    return snapshot.docs.map((doc) => Volunteer.fromFirestore(doc)).toList();
  }

  // ==================== ALERT ROUTING ====================

  /// Send alert to nearby NGOs
  Future<List<String>> broadcastAlertToNGOs({
    required String alertType,
    required String sourceId,
    String? userId,
    required double latitude,
    required double longitude,
    String? address,
    String? focusArea,
  }) async {
    // Find nearby NGOs that can receive alerts
    final nearbyNGOs = await getNearbyNGOs(
      latitude: latitude,
      longitude: longitude,
      focusArea: focusArea,
    );

    final alertableNGOs = nearbyNGOs.where((n) => n.canReceiveAlerts).toList();

    final alertIds = <String>[];
    for (final ngo in alertableNGOs) {
      final alert = NGOAlert(
        id: '',
        ngoId: ngo.id,
        alertType: alertType,
        sourceId: sourceId,
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        address: address,
        createdAt: DateTime.now(),
      );

      final docRef = await _alertsRef.add(alert.toFirestore());
      alertIds.add(docRef.id);

      // TODO: Send push notification to NGO app/contacts
    }

    return alertIds;
  }

  /// Forward report to NGO
  Future<String> forwardReportToNGO({
    required String reportId,
    required String ngoId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final ngo = await getNGOById(ngoId);
    if (ngo == null) throw Exception('NGO not found');
    if (!ngo.canReceiveReports) throw Exception('NGO cannot receive reports');

    final alert = NGOAlert(
      id: '',
      ngoId: ngoId,
      alertType: 'report',
      sourceId: reportId,
      latitude: latitude,
      longitude: longitude,
      address: address,
      createdAt: DateTime.now(),
    );

    final docRef = await _alertsRef.add(alert.toFirestore());
    return docRef.id;
  }

  /// Get alerts for NGO
  Stream<List<NGOAlert>> getAlertsForNGO(String ngoId) {
    return _alertsRef
        .where('ngoId', isEqualTo: ngoId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NGOAlert.fromFirestore(doc))
            .toList());
  }

  /// Acknowledge alert
  Future<void> acknowledgeAlert(String alertId) async {
    await _alertsRef.doc(alertId).update({
      'status': 'acknowledged',
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark alert as responded
  Future<void> respondToAlert(String alertId, String notes) async {
    final doc = await _alertsRef.doc(alertId).get();
    if (!doc.exists) throw Exception('Alert not found');

    final alert = NGOAlert.fromFirestore(doc);

    await _alertsRef.doc(alertId).update({
      'status': 'responded',
      'respondedAt': FieldValue.serverTimestamp(),
      'responseNotes': notes,
    });

    // Update NGO stats
    await _ngosRef.doc(alert.ngoId).update({
      'alertsResponded': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Close alert
  Future<void> closeAlert(String alertId) async {
    await _alertsRef.doc(alertId).update({
      'status': 'closed',
    });
  }

  // ==================== ADMIN FUNCTIONS ====================

  /// Get pending NGO applications
  Future<List<NGOPartner>> getPendingApplications() async {
    final snapshot = await _ngosRef
        .where('status', isEqualTo: NGOStatus.pending.name)
        .orderBy('createdAt')
        .get();
    return snapshot.docs.map((doc) => NGOPartner.fromFirestore(doc)).toList();
  }

  /// Verify NGO
  Future<void> verifyNGO({
    required String ngoId,
    required String adminId,
    bool canReceiveAlerts = true,
    bool canVouchVolunteers = true,
    bool canReceiveReports = true,
  }) async {
    await _ngosRef.doc(ngoId).update({
      'status': NGOStatus.verified.name,
      'verifiedByAdminId': adminId,
      'verifiedAt': FieldValue.serverTimestamp(),
      'canReceiveAlerts': canReceiveAlerts,
      'canVouchVolunteers': canVouchVolunteers,
      'canReceiveReports': canReceiveReports,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject NGO application
  Future<void> rejectNGO(String ngoId, String reason) async {
    await _ngosRef.doc(ngoId).update({
      'status': NGOStatus.rejected.name,
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Suspend NGO
  Future<void> suspendNGO(String ngoId, String reason) async {
    await _ngosRef.doc(ngoId).update({
      'status': NGOStatus.suspended.name,
      'suspensionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== UTILITIES ====================

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.14159265359 / 180;
}
