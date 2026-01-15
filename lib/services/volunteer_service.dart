import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../models/volunteer.dart';
import '../models/escort_request.dart';
import 'firebase_service.dart';

/// Service for volunteer operations
class VolunteerService {
  final FirebaseService _firebase = FirebaseService.instance;

  String? get _userId => _firebase.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _volunteersRef =>
      _firebase.firestore.collection('volunteers');

  CollectionReference<Map<String, dynamic>> get _ratingsRef =>
      _firebase.firestore.collection('volunteerRatings');

  CollectionReference<Map<String, dynamic>> get _escortRequestsRef =>
      _firebase.firestore.collection('escortRequests');

  // ==================== REGISTRATION ====================

  /// Register as a volunteer (Stage 1)
  Future<String> registerVolunteer({
    required String name,
    required String phone,
    String? email,
    String? bio,
    required String country,
    DateTime? dateOfBirth,
  }) async {
    if (_userId == null) throw Exception('User not logged in');

    // Check if already registered
    final existing = await getVolunteerByUserId(_userId!);
    if (existing != null) {
      throw Exception('Already registered as a volunteer');
    }

    final volunteer = Volunteer(
      id: '',
      userId: _userId!,
      name: name,
      phone: phone,
      email: email,
      bio: bio,
      country: country,
      dateOfBirth: dateOfBirth,
      verificationLevel: VerificationLevel.phoneVerified,
      createdAt: DateTime.now(),
    );

    final docRef = await _volunteersRef.add(volunteer.toFirestore());
    return docRef.id;
  }

  /// Get volunteer by user ID
  Future<Volunteer?> getVolunteerByUserId(String userId) async {
    final snapshot = await _volunteersRef
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Volunteer.fromFirestore(snapshot.docs.first);
  }

  /// Get current user's volunteer profile
  Future<Volunteer?> getCurrentVolunteer() async {
    if (_userId == null) return null;
    return getVolunteerByUserId(_userId!);
  }

  /// Check if current user is a volunteer
  Future<bool> isVolunteer() async {
    final volunteer = await getCurrentVolunteer();
    return volunteer != null;
  }

  // ==================== ID VERIFICATION ====================

  /// Upload ID document for verification
  Future<String> uploadIdDocument(File imageFile) async {
    if (_userId == null) throw Exception('User not logged in');

    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) throw Exception('Not registered as volunteer');

    // Upload to Firebase Storage
    final ref = _firebase.storage
        .ref()
        .child('volunteers')
        .child(volunteer.id)
        .child('id_document.jpg');

    await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final downloadUrl = await ref.getDownloadURL();

    // Update volunteer record
    await _volunteersRef.doc(volunteer.id).update({
      'idDocumentUrl': downloadUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return downloadUrl;
  }

  /// Upload selfie for verification
  Future<String> uploadSelfie(File imageFile) async {
    if (_userId == null) throw Exception('User not logged in');

    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) throw Exception('Not registered as volunteer');

    final ref = _firebase.storage
        .ref()
        .child('volunteers')
        .child(volunteer.id)
        .child('selfie.jpg');

    await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final downloadUrl = await ref.getDownloadURL();

    await _volunteersRef.doc(volunteer.id).update({
      'selfieUrl': downloadUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return downloadUrl;
  }

  /// Submit ID verification - Stage 2 (after KYC)
  /// For India: Aadhaar + Face Match + Liveness (selfie required, no doc upload)
  /// For USA/Others: ID document + selfie required
  Future<void> submitIdVerification({
    bool isAadhaarVerified = false,
    double? faceMatchScore,
    bool livenessPasssed = false,
  }) async {
    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) throw Exception('Not registered as volunteer');

    // For India: only selfie needed (Aadhaar verification is done via API)
    // For others: both ID document and selfie needed
    final isIndia = volunteer.country == 'IN';

    if (!isIndia && volunteer.idDocumentUrl == null) {
      throw Exception('Please upload ID document first');
    }
    if (volunteer.selfieUrl == null) {
      throw Exception('Please upload selfie first');
    }

    // Update verification status
    await _volunteersRef.doc(volunteer.id).update({
      'verificationLevel': VerificationLevel.idVerified.name,
      'idVerifiedAt': FieldValue.serverTimestamp(),
      'aadhaarVerified': isAadhaarVerified,
      'faceMatchScore': faceMatchScore,
      'livenessPasssed': livenessPasssed,
      'kycCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== BACKGROUND CHECK ====================

  /// Initiate background check
  /// In production, this would integrate with Checkr/Onfido/AuthBridge
  Future<String> initiateBackgroundCheck({
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String ssn, // or national ID for India
    required String address,
  }) async {
    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) throw Exception('Not registered as volunteer');

    if (volunteer.verificationLevel.index < VerificationLevel.idVerified.index) {
      throw Exception('Please complete ID verification first');
    }

    // TODO: Integrate with actual background check provider
    // For now, simulate by storing the request
    final checkId = 'bgc_${DateTime.now().millisecondsSinceEpoch}';

    await _volunteersRef.doc(volunteer.id).update({
      'backgroundCheckId': checkId,
      'backgroundCheckStatus': 'pending',
      'backgroundCheckDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // In production, call external API:
    // final result = await CheckrApi.createCheck(...)
    // await _handleBackgroundCheckResult(volunteer.id, result);

    return checkId;
  }

  /// Update background check status (called by webhook or admin)
  Future<void> updateBackgroundCheckStatus(
    String volunteerId,
    String status, // 'pending', 'cleared', 'flagged'
  ) async {
    final updates = <String, dynamic>{
      'backgroundCheckStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'cleared') {
      updates['verificationLevel'] = VerificationLevel.backgroundChecked.name;
    }

    await _volunteersRef.doc(volunteerId).update(updates);
  }

  // ==================== AVAILABILITY ====================

  /// Update volunteer availability
  Future<void> updateAvailability({
    required AvailabilityStatus status,
    required bool isAcceptingRequests,
    double? serviceRadiusKm,
    List<String>? availableDays,
    String? availableTimeStart,
    String? availableTimeEnd,
  }) async {
    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) throw Exception('Not registered as volunteer');

    final updates = <String, dynamic>{
      'availabilityStatus': status.name,
      'isAcceptingRequests': isAcceptingRequests,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    };

    if (serviceRadiusKm != null) updates['serviceRadiusKm'] = serviceRadiusKm;
    if (availableDays != null) updates['availableDays'] = availableDays;
    if (availableTimeStart != null) updates['availableTimeStart'] = availableTimeStart;
    if (availableTimeEnd != null) updates['availableTimeEnd'] = availableTimeEnd;

    await _volunteersRef.doc(volunteer.id).update(updates);
  }

  /// Update current location
  Future<void> updateLocation(Position position) async {
    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) return;

    await _volunteersRef.doc(volunteer.id).update({
      'currentLocation': GeoPoint(position.latitude, position.longitude),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  /// Go online/offline
  Future<void> setOnlineStatus(bool isOnline) async {
    await updateAvailability(
      status: isOnline ? AvailabilityStatus.available : AvailabilityStatus.offline,
      isAcceptingRequests: isOnline,
    );
  }

  // ==================== ESCORT REQUESTS ====================

  /// Get pending escort requests near volunteer
  Future<List<EscortRequest>> getNearbyRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    final volunteer = await getCurrentVolunteer();
    if (volunteer == null || !volunteer.canAcceptRequests) {
      return [];
    }

    // Get pending requests
    // Note: For production, use GeoFlutterFire for proper geo queries
    final snapshot = await _escortRequestsRef
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final requests = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return EscortRequest.fromJson(data);
    }).toList();

    // Filter by distance (client-side for now)
    return requests.where((request) {
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        request.latitude,
        request.longitude,
      );
      return distance <= radiusKm * 1000;
    }).toList();
  }

  /// Accept an escort request
  Future<void> acceptEscortRequest(String requestId) async {
    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) throw Exception('Not registered as volunteer');
    if (!volunteer.canAcceptRequests) {
      throw Exception('You are not eligible to accept requests');
    }

    await _escortRequestsRef.doc(requestId).update({
      'status': 'confirmed',
      'assignedVolunteerId': volunteer.id,
      'assignedVolunteerName': volunteer.name,
      'assignedAt': FieldValue.serverTimestamp(),
    });

    // Update volunteer status
    await _volunteersRef.doc(volunteer.id).update({
      'availabilityStatus': AvailabilityStatus.busy.name,
    });
  }

  /// Complete an escort
  Future<void> completeEscort(String requestId) async {
    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) throw Exception('Not registered as volunteer');

    await _escortRequestsRef.doc(requestId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });

    // Update volunteer stats
    await _volunteersRef.doc(volunteer.id).update({
      'totalEscorts': FieldValue.increment(1),
      'availabilityStatus': AvailabilityStatus.available.name,
    });
  }

  /// Cancel an escort
  Future<void> cancelEscort(String requestId, String reason) async {
    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) throw Exception('Not registered as volunteer');

    await _escortRequestsRef.doc(requestId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancellationReason': reason,
      'cancelledBy': 'volunteer',
    });

    await _volunteersRef.doc(volunteer.id).update({
      'cancelledCount': FieldValue.increment(1),
      'availabilityStatus': AvailabilityStatus.available.name,
    });
  }

  /// Get volunteer's assigned requests
  Stream<List<EscortRequest>> getAssignedRequests() {
    final volunteer = getCurrentVolunteer();
    if (volunteer == null) return Stream.value([]);

    return _escortRequestsRef
        .where('assignedVolunteerId', isEqualTo: _userId)
        .where('status', whereIn: ['confirmed', 'in_progress'])
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return EscortRequest.fromJson(data);
            }).toList());
  }

  // ==================== RATINGS ====================

  /// Rate a volunteer after escort
  Future<void> rateVolunteer({
    required String volunteerId,
    required String escortRequestId,
    required int rating,
    String? comment,
  }) async {
    if (_userId == null) throw Exception('User not logged in');

    // Save rating
    await _ratingsRef.add({
      'volunteerId': volunteerId,
      'escortRequestId': escortRequestId,
      'userId': _userId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update volunteer average rating
    final ratingsSnapshot = await _ratingsRef
        .where('volunteerId', isEqualTo: volunteerId)
        .get();

    final ratings = ratingsSnapshot.docs
        .map((doc) => doc.data()['rating'] as int)
        .toList();

    final averageRating = ratings.reduce((a, b) => a + b) / ratings.length;

    await _volunteersRef.doc(volunteerId).update({
      'averageRating': averageRating,
      'ratingCount': ratings.length,
    });
  }

  /// Get volunteer ratings
  Future<List<VolunteerRating>> getVolunteerRatings(String volunteerId) async {
    final snapshot = await _ratingsRef
        .where('volunteerId', isEqualTo: volunteerId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => VolunteerRating.fromFirestore(doc))
        .toList();
  }

  // ==================== SEARCH ====================

  /// Find available volunteers near a location
  Future<List<Volunteer>> findNearbyVolunteers({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    // Get available volunteers
    final snapshot = await _volunteersRef
        .where('availabilityStatus', isEqualTo: AvailabilityStatus.available.name)
        .where('isAcceptingRequests', isEqualTo: true)
        .where('verificationLevel', whereIn: [
          VerificationLevel.backgroundChecked.name,
          VerificationLevel.trusted.name,
        ])
        .get();

    final volunteers = snapshot.docs
        .map((doc) => Volunteer.fromFirestore(doc))
        .toList();

    // Filter by distance
    return volunteers.where((v) {
      if (v.currentLocation == null) return false;
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        v.currentLocation!.latitude,
        v.currentLocation!.longitude,
      );
      return distance <= radiusKm * 1000;
    }).toList()
      ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
  }
}
