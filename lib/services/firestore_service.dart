import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trusted_contact.dart';
import '../models/harassment_report.dart';
import '../models/escort_request.dart';
import 'firebase_service.dart';

/// Firestore service for cloud data operations
class FirestoreService {
  final FirebaseService _firebase = FirebaseService.instance;

  String? get _userId => _firebase.currentUser?.uid;

  // ==================== CONTACTS ====================

  /// Get contacts collection reference for current user
  CollectionReference<Map<String, dynamic>> get _contactsRef {
    if (_userId == null) throw Exception('User not logged in');
    return _firebase.firestore
        .collection(FirestoreCollections.users)
        .doc(_userId)
        .collection(FirestoreCollections.contacts);
  }

  /// Add a trusted contact
  Future<void> addContact(TrustedContact contact) async {
    await _contactsRef.doc(contact.id).set(contact.toJson());
  }

  /// Update a trusted contact
  Future<void> updateContact(TrustedContact contact) async {
    await _contactsRef.doc(contact.id).update(contact.toJson());
  }

  /// Delete a trusted contact
  Future<void> deleteContact(String contactId) async {
    await _contactsRef.doc(contactId).delete();
  }

  /// Get all contacts
  Future<List<TrustedContact>> getContacts() async {
    final snapshot = await _contactsRef.get();
    return snapshot.docs
        .map((doc) => TrustedContact.fromJson(doc.data()))
        .toList();
  }

  /// Stream contacts for real-time updates
  Stream<List<TrustedContact>> contactsStream() {
    return _contactsRef.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => TrustedContact.fromJson(doc.data())).toList());
  }

  /// Sync local contacts to cloud
  Future<void> syncContacts(List<TrustedContact> localContacts) async {
    final batch = _firebase.firestore.batch();

    for (final contact in localContacts) {
      batch.set(_contactsRef.doc(contact.id), contact.toJson());
    }

    await batch.commit();
  }

  // ==================== REPORTS ====================

  /// Reports collection reference
  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      _firebase.firestore.collection(FirestoreCollections.reports);

  /// Submit a harassment report
  Future<String> submitReport(HarassmentReport report) async {
    final docRef = await _reportsRef.add({
      ...report.toJson(),
      'userId': _userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Get user's reports
  Future<List<HarassmentReport>> getUserReports() async {
    if (_userId == null) return [];

    final snapshot = await _reportsRef
        .where('userId', isEqualTo: _userId)
        .orderBy('reportedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return HarassmentReport.fromJson(data);
    }).toList();
  }

  /// Update report status
  Future<void> updateReportStatus(String reportId, String status) async {
    await _reportsRef.doc(reportId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== ESCORT REQUESTS ====================

  /// Escort requests collection reference
  CollectionReference<Map<String, dynamic>> get _escortRequestsRef =>
      _firebase.firestore.collection(FirestoreCollections.escortRequests);

  /// Create an escort request
  Future<String> createEscortRequest(EscortRequest request) async {
    final docRef = await _escortRequestsRef.add({
      ...request.toJson(),
      'userId': _userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Get user's escort requests
  Future<List<EscortRequest>> getUserEscortRequests() async {
    if (_userId == null) return [];

    final snapshot = await _escortRequestsRef
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return EscortRequest.fromFirestore(doc);
    }).toList();
  }

  /// Update escort request status
  Future<void> updateEscortRequestStatus(
    String requestId,
    String status, {
    String? volunteerId,
    String? volunteerName,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (volunteerId != null) {
      updates['assignedVolunteerId'] = volunteerId;
      updates['assignedVolunteerName'] = volunteerName;
      updates['assignedAt'] = FieldValue.serverTimestamp();
    }

    await _escortRequestsRef.doc(requestId).update(updates);
  }

  /// Stream escort requests for real-time updates
  Stream<List<EscortRequest>> escortRequestsStream() {
    if (_userId == null) return Stream.value([]);

    return _escortRequestsRef
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return EscortRequest.fromFirestore(doc);
            }).toList());
  }

  // ==================== HEATMAP DATA ====================

  /// Heatmap collection reference
  CollectionReference<Map<String, dynamic>> get _heatmapRef =>
      _firebase.firestore.collection(FirestoreCollections.heatmapData);

  /// Add incident to heatmap (anonymized)
  Future<void> addToHeatmap({
    required double latitude,
    required double longitude,
    required String harassmentType,
  }) async {
    // Create a geohash for the location (simplified - use actual geohash in production)
    final geohash = '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';

    final docRef = _heatmapRef.doc(geohash);
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.update({
        'incidentCount': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
        'types.$harassmentType': FieldValue.increment(1),
      });
    } else {
      await docRef.set({
        'latitude': latitude,
        'longitude': longitude,
        'geohash': geohash,
        'incidentCount': 1,
        'lastUpdated': FieldValue.serverTimestamp(),
        'types': {harassmentType: 1},
      });
    }
  }

  /// Get heatmap data for a region
  Future<List<Map<String, dynamic>>> getHeatmapData({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    // Note: For production, use GeoFlutterFire for proper geo queries
    final snapshot = await _heatmapRef
        .where('latitude', isGreaterThanOrEqualTo: minLat)
        .where('latitude', isLessThanOrEqualTo: maxLat)
        .get();

    return snapshot.docs
        .map((doc) => doc.data())
        .where((data) =>
            data['longitude'] >= minLng && data['longitude'] <= maxLng)
        .toList();
  }

  // ==================== LOCATION HISTORY ====================

  /// Save location to history
  Future<void> saveLocationHistory({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    if (_userId == null) return;

    await _firebase.firestore
        .collection(FirestoreCollections.locationHistory)
        .doc(_userId)
        .collection('history')
        .add({
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get location history
  Future<List<Map<String, dynamic>>> getLocationHistory({
    int limit = 50,
  }) async {
    if (_userId == null) return [];

    final snapshot = await _firebase.firestore
        .collection(FirestoreCollections.locationHistory)
        .doc(_userId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
