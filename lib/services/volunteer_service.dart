import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/volunteer.dart';
import '../models/escort_request.dart';
import 'firebase_service.dart';
import 'push_notification_service.dart';

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

  // ==================== SOS VOLUNTEER ALERTS ====================

  /// Find volunteers who have opted in for SOS response alerts
  Future<List<Volunteer>> findSOSRespondersNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
  }) async {
    // Get volunteers who are:
    // 1. Available and accepting requests
    // 2. Opted in for SOS alerts
    // 3. Verified (at least ID verified for faster response)
    final snapshot = await _volunteersRef
        .where('availabilityStatus', isEqualTo: AvailabilityStatus.available.name)
        .where('isAcceptingRequests', isEqualTo: true)
        .where('sosAlertOptIn', isEqualTo: true)
        .get();

    final volunteers = snapshot.docs
        .map((doc) => Volunteer.fromFirestore(doc))
        .where((v) => v.verificationLevel.index >= VerificationLevel.idVerified.index)
        .toList();

    // Filter by distance
    final nearbyVolunteers = volunteers.where((v) {
      if (v.currentLocation == null) return false;
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        v.currentLocation!.latitude,
        v.currentLocation!.longitude,
      );
      return distance <= radiusKm * 1000;
    }).toList();

    // Sort by distance (closest first)
    nearbyVolunteers.sort((a, b) {
      final distA = Geolocator.distanceBetween(
        latitude, longitude,
        a.currentLocation!.latitude, a.currentLocation!.longitude,
      );
      final distB = Geolocator.distanceBetween(
        latitude, longitude,
        b.currentLocation!.latitude, b.currentLocation!.longitude,
      );
      return distA.compareTo(distB);
    });

    return nearbyVolunteers;
  }

  /// Alert nearby volunteers about an SOS
  /// Returns the number of volunteers alerted
  Future<SOSVolunteerAlertResult> alertNearbyVolunteers({
    required String senderName,
    required String senderPhone,
    required double latitude,
    required double longitude,
    required String address,
    String? message,
    double radiusKm = 5,
    int maxVolunteers = 10,
  }) async {
    final result = SOSVolunteerAlertResult();

    try {
      // Find nearby SOS responders
      final volunteers = await findSOSRespondersNearby(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      );

      if (volunteers.isEmpty) {
        debugPrint('No nearby volunteers found for SOS alert');
        return result;
      }

      // Limit to max volunteers
      final targetVolunteers = volunteers.take(maxVolunteers).toList();
      result.volunteersFound = targetVolunteers.length;

      // Create SOS alert record
      final alertRef = await _firebase.firestore.collection('sosVolunteerAlerts').add({
        'senderUserId': _userId,
        'senderName': senderName,
        'senderPhone': senderPhone,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'message': message,
        'status': 'active',
        'volunteersAlerted': targetVolunteers.map((v) => v.id).toList(),
        'respondedVolunteers': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      result.alertId = alertRef.id;

      // Get volunteer user IDs for push notifications
      final volunteerUserIds = targetVolunteers.map((v) => v.userId).toList();

      // Send push notifications
      await _sendSOSAlertToVolunteers(
        alertId: alertRef.id,
        volunteerUserIds: volunteerUserIds,
        senderName: senderName,
        latitude: latitude,
        longitude: longitude,
        address: address,
        message: message,
      );

      result.volunteersAlerted = volunteerUserIds.length;
      result.success = true;

      debugPrint('SOS alert sent to ${result.volunteersAlerted} nearby volunteers');
    } catch (e) {
      debugPrint('Error alerting nearby volunteers: $e');
      result.error = e.toString();
    }

    return result;
  }

  /// Send SOS alert notifications to volunteers
  Future<void> _sendSOSAlertToVolunteers({
    required String alertId,
    required List<String> volunteerUserIds,
    required String senderName,
    required double latitude,
    required double longitude,
    required String address,
    String? message,
  }) async {
    // Get FCM tokens for volunteers
    final tokens = <String>[];

    for (var i = 0; i < volunteerUserIds.length; i += 10) {
      final batch = volunteerUserIds.skip(i).take(10).toList();
      final snapshot = await _firebase.firestore
          .collection('userTokens')
          .where('userId', whereIn: batch)
          .get();

      for (final doc in snapshot.docs) {
        final token = doc.data()['token'] as String?;
        if (token != null && token.isNotEmpty) {
          tokens.add(token);
        }
      }
    }

    if (tokens.isEmpty) {
      debugPrint('No FCM tokens found for volunteers');
      return;
    }

    // Queue notification for Cloud Function to send
    await _firebase.firestore.collection('notificationQueue').add({
      'tokens': tokens,
      'notification': {
        'title': 'SOS Alert Nearby!',
        'body': '$senderName needs help at $address',
      },
      'data': {
        'type': 'sos_volunteer_alert',
        'alertId': alertId,
        'senderName': senderName,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'address': address,
        'message': message ?? '',
        'mapsUrl': 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      },
      'priority': 'high',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Volunteer responds to SOS alert
  Future<void> respondToSOSAlert({
    required String alertId,
    required SOSResponseType responseType,
    String? estimatedArrivalMinutes,
  }) async {
    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) throw Exception('Not registered as volunteer');

    // Update alert with response
    await _firebase.firestore.collection('sosVolunteerAlerts').doc(alertId).update({
      'respondedVolunteers': FieldValue.arrayUnion([{
        'volunteerId': volunteer.id,
        'volunteerName': volunteer.name,
        'volunteerPhone': volunteer.phone,
        'responseType': responseType.name,
        'estimatedArrivalMinutes': estimatedArrivalMinutes,
        'respondedAt': DateTime.now().toIso8601String(),
      }]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // If responding, update volunteer status
    if (responseType == SOSResponseType.onMyWay) {
      await _volunteersRef.doc(volunteer.id).update({
        'availabilityStatus': AvailabilityStatus.responding.name,
        'currentSOSAlertId': alertId,
      });
    }
  }

  /// Mark SOS as resolved
  Future<void> resolveSOSAlert(String alertId, String resolution) async {
    await _firebase.firestore.collection('sosVolunteerAlerts').doc(alertId).update({
      'status': 'resolved',
      'resolution': resolution,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    // Reset responding volunteers' status
    final alert = await _firebase.firestore.collection('sosVolunteerAlerts').doc(alertId).get();
    final respondedVolunteers = alert.data()?['respondedVolunteers'] as List<dynamic>? ?? [];

    for (final response in respondedVolunteers) {
      final volunteerId = response['volunteerId'] as String?;
      if (volunteerId != null) {
        await _volunteersRef.doc(volunteerId).update({
          'availabilityStatus': AvailabilityStatus.available.name,
          'currentSOSAlertId': null,
        });
      }
    }
  }

  /// Update volunteer's SOS alert opt-in preference
  Future<void> setSOSAlertOptIn(bool optIn) async {
    final volunteer = await getCurrentVolunteer();
    if (volunteer == null) throw Exception('Not registered as volunteer');

    await _volunteersRef.doc(volunteer.id).update({
      'sosAlertOptIn': optIn,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get active SOS alerts for volunteer
  Stream<List<SOSVolunteerAlert>> getActiveSOSAlerts() {
    return _firebase.firestore
        .collection('sosVolunteerAlerts')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SOSVolunteerAlert.fromFirestore(doc))
            .toList());
  }
}

// ==================== MODELS ====================

/// Result of alerting nearby volunteers
class SOSVolunteerAlertResult {
  bool success = false;
  String? alertId;
  int volunteersFound = 0;
  int volunteersAlerted = 0;
  String? error;

  String get statusMessage {
    if (success) {
      return 'Alert sent to $volunteersAlerted nearby volunteer(s)';
    } else if (volunteersFound == 0) {
      return 'No nearby volunteers available';
    } else {
      return 'Failed to alert volunteers: $error';
    }
  }
}

/// SOS response type from volunteer
enum SOSResponseType {
  onMyWay,
  callingEmergency,
  cannotRespond,
}

/// SOS volunteer alert model
class SOSVolunteerAlert {
  final String id;
  final String senderUserId;
  final String senderName;
  final String senderPhone;
  final double latitude;
  final double longitude;
  final String address;
  final String? message;
  final String status;
  final List<String> volunteersAlerted;
  final List<Map<String, dynamic>> respondedVolunteers;
  final DateTime createdAt;

  SOSVolunteerAlert({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.senderPhone,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.message,
    required this.status,
    required this.volunteersAlerted,
    required this.respondedVolunteers,
    required this.createdAt,
  });

  factory SOSVolunteerAlert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SOSVolunteerAlert(
      id: doc.id,
      senderUserId: data['senderUserId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhone: data['senderPhone'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      address: data['address'] ?? '',
      message: data['message'],
      status: data['status'] ?? 'active',
      volunteersAlerted: List<String>.from(data['volunteersAlerted'] ?? []),
      respondedVolunteers: List<Map<String, dynamic>>.from(data['respondedVolunteers'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
}
