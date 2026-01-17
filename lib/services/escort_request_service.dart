import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/escort_request.dart';
import '../models/volunteer.dart';
import 'firebase_service.dart';
import 'chat_service.dart';

/// Service for managing escort requests in Firestore
class EscortRequestService {
  final FirebaseService _firebase = FirebaseService.instance;
  final ChatService _chatService = ChatService();

  CollectionReference get _requestsRef =>
      _firebase.firestore.collection('escortRequests');

  CollectionReference get _volunteersRef =>
      _firebase.firestore.collection('volunteers');

  String? get _userId => _firebase.auth.currentUser?.uid;

  // ==================== USER METHODS ====================

  /// Create a new escort request
  Future<EscortRequest> createRequest({
    required String eventName,
    required String eventLocation,
    required double latitude,
    required double longitude,
    required DateTime eventDateTime,
    String? notes,
  }) async {
    if (_userId == null) throw Exception('User not logged in');

    // Get user info
    final userDoc = await _firebase.firestore
        .collection('users')
        .doc(_userId)
        .get();
    final userData = userDoc.data() ?? {};

    final request = EscortRequest(
      id: '',
      userId: _userId!,
      userName: userData['name'] ?? 'Unknown',
      userPhone: userData['phone'],
      eventName: eventName,
      eventLocation: eventLocation,
      latitude: latitude,
      longitude: longitude,
      eventDateTime: eventDateTime,
      notes: notes,
      status: EscortRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    final docRef = await _requestsRef.add(request.toFirestore());

    // Notify nearby volunteers
    await _notifyNearbyVolunteers(
      requestId: docRef.id,
      eventName: eventName,
      eventLocation: eventLocation,
      latitude: latitude,
      longitude: longitude,
      eventDateTime: eventDateTime,
    );

    return request.copyWith(id: docRef.id);
  }

  /// Get user's escort requests (real-time stream)
  Stream<List<EscortRequest>> getUserRequests() {
    if (_userId == null) return Stream.value([]);

    return _requestsRef
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EscortRequest.fromFirestore(doc))
            .toList());
  }

  /// Get a specific request
  Future<EscortRequest?> getRequest(String requestId) async {
    final doc = await _requestsRef.doc(requestId).get();
    if (!doc.exists) return null;
    return EscortRequest.fromFirestore(doc);
  }

  /// Cancel a request (by user)
  Future<void> cancelRequest(String requestId, {String? reason}) async {
    await _requestsRef.doc(requestId).update({
      'status': EscortRequestStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancellationReason': reason ?? 'Cancelled by user',
    });
  }

  /// Rate and review completed escort
  Future<void> rateEscort({
    required String requestId,
    required double rating,
    String? review,
  }) async {
    await _requestsRef.doc(requestId).update({
      'rating': rating,
      'review': review,
    });

    // Update volunteer's average rating
    final request = await getRequest(requestId);
    if (request?.assignedVolunteerId != null) {
      await _updateVolunteerRating(request!.assignedVolunteerId!, rating);
    }
  }

  // ==================== VOLUNTEER METHODS ====================

  /// Get pending requests near volunteer's location
  Stream<List<EscortRequest>> getNearbyPendingRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) {
    return _requestsRef
        .where('status', isEqualTo: EscortRequestStatus.pending.name)
        .orderBy('eventDateTime')
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => EscortRequest.fromFirestore(doc))
          .toList();

      // Filter by distance (client-side)
      return requests.where((request) {
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          request.latitude,
          request.longitude,
        );
        return distance <= radiusKm * 1000;
      }).toList();
    });
  }

  /// Accept an escort request (by volunteer)
  Future<void> acceptRequest(String requestId) async {
    if (_userId == null) throw Exception('User not logged in');

    // Get volunteer info
    final volunteerQuery = await _volunteersRef
        .where('userId', isEqualTo: _userId)
        .limit(1)
        .get();

    if (volunteerQuery.docs.isEmpty) {
      throw Exception('You are not registered as a volunteer');
    }

    final volunteer = Volunteer.fromFirestore(volunteerQuery.docs.first);

    if (!volunteer.canAcceptRequests) {
      throw Exception('You are not eligible to accept requests');
    }

    // Get request and user info
    final request = await getRequest(requestId);
    if (request == null) throw Exception('Request not found');
    if (!request.isPending) throw Exception('Request is no longer available');

    // Create chat between user and volunteer
    final chat = await _chatService.getOrCreateChat(
      otherUserId: request.userId,
      otherUserName: request.userName,
      currentUserName: volunteer.name,
      escortRequestId: requestId,
    );

    // Update request
    await _requestsRef.doc(requestId).update({
      'status': EscortRequestStatus.confirmed.name,
      'assignedVolunteerId': volunteer.id,
      'assignedVolunteerName': volunteer.name,
      'assignedVolunteerPhone': volunteer.phone,
      'chatId': chat.id,
      'confirmedAt': FieldValue.serverTimestamp(),
    });

    // Update volunteer status
    await _volunteersRef.doc(volunteer.id).update({
      'availabilityStatus': AvailabilityStatus.busy.name,
    });

    // Send system message in chat
    await _chatService.sendSystemMessage(
      chatId: chat.id,
      content: '${volunteer.name} accepted your escort request',
    );

    // Notify user
    await _notifyUser(
      userId: request.userId,
      title: 'Escort Confirmed!',
      body: '${volunteer.name} will escort you to ${request.eventName}',
      data: {'type': 'escort_confirmed', 'requestId': requestId},
    );
  }

  /// Start the escort (volunteer arrived)
  Future<void> startEscort(String requestId) async {
    await _requestsRef.doc(requestId).update({
      'status': EscortRequestStatus.inProgress.name,
    });

    final request = await getRequest(requestId);
    if (request?.chatId != null) {
      await _chatService.sendSystemMessage(
        chatId: request!.chatId!,
        content: 'Escort started',
      );
    }
  }

  /// Complete the escort
  Future<void> completeEscort(String requestId) async {
    final request = await getRequest(requestId);
    if (request == null) throw Exception('Request not found');

    await _requestsRef.doc(requestId).update({
      'status': EscortRequestStatus.completed.name,
      'completedAt': FieldValue.serverTimestamp(),
    });

    // Update volunteer status and stats
    if (request.assignedVolunteerId != null) {
      await _volunteersRef.doc(request.assignedVolunteerId).update({
        'availabilityStatus': AvailabilityStatus.available.name,
        'totalEscorts': FieldValue.increment(1),
      });
    }

    if (request.chatId != null) {
      await _chatService.sendSystemMessage(
        chatId: request.chatId!,
        content: 'Escort completed. Thank you!',
      );
    }

    // Notify user to rate
    await _notifyUser(
      userId: request.userId,
      title: 'Escort Completed',
      body: 'Please rate your experience with ${request.assignedVolunteerName}',
      data: {'type': 'escort_completed', 'requestId': requestId},
    );
  }

  /// Cancel request (by volunteer)
  Future<void> volunteerCancelRequest(String requestId, String reason) async {
    final request = await getRequest(requestId);
    if (request == null) throw Exception('Request not found');

    await _requestsRef.doc(requestId).update({
      'status': EscortRequestStatus.pending.name, // Back to pending so others can accept
      'assignedVolunteerId': null,
      'assignedVolunteerName': null,
      'assignedVolunteerPhone': null,
      'confirmedAt': null,
    });

    // Update volunteer status
    if (request.assignedVolunteerId != null) {
      await _volunteersRef.doc(request.assignedVolunteerId).update({
        'availabilityStatus': AvailabilityStatus.available.name,
      });
    }

    if (request.chatId != null) {
      await _chatService.sendSystemMessage(
        chatId: request.chatId!,
        content: 'Volunteer cancelled: $reason',
      );
    }

    // Notify user
    await _notifyUser(
      userId: request.userId,
      title: 'Escort Cancelled',
      body: 'Your volunteer had to cancel. Looking for another...',
      data: {'type': 'escort_cancelled', 'requestId': requestId},
    );
  }

  // ==================== HELPER METHODS ====================

  /// Notify nearby volunteers about new request
  Future<void> _notifyNearbyVolunteers({
    required String requestId,
    required String eventName,
    required String eventLocation,
    required double latitude,
    required double longitude,
    required DateTime eventDateTime,
  }) async {
    // Find available volunteers within 10km
    final volunteersSnapshot = await _volunteersRef
        .where('availabilityStatus', isEqualTo: AvailabilityStatus.available.name)
        .where('isAcceptingRequests', isEqualTo: true)
        .get();

    final nearbyVolunteerIds = <String>[];

    for (final doc in volunteersSnapshot.docs) {
      final volunteer = Volunteer.fromFirestore(doc);
      if (volunteer.currentLocation != null) {
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          volunteer.currentLocation!.latitude,
          volunteer.currentLocation!.longitude,
        );
        if (distance <= volunteer.serviceRadiusKm * 1000) {
          nearbyVolunteerIds.add(volunteer.userId);
        }
      }
    }

    if (nearbyVolunteerIds.isEmpty) return;

    // Get FCM tokens
    final tokensSnapshot = await _firebase.firestore
        .collection('userTokens')
        .where('userId', whereIn: nearbyVolunteerIds.take(10).toList())
        .get();

    final tokens = tokensSnapshot.docs
        .map((doc) => doc.data()['token'] as String)
        .toList();

    if (tokens.isEmpty) return;

    // Send notification
    await _firebase.firestore.collection('notificationQueue').add({
      'tokens': tokens,
      'notification': {
        'title': 'New Escort Request',
        'body': '$eventName at $eventLocation',
      },
      'data': {
        'type': 'escort_request',
        'requestId': requestId,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
      'priority': 'high',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Notify a specific user
  Future<void> _notifyUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final tokenDoc = await _firebase.firestore
        .collection('userTokens')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (tokenDoc.docs.isEmpty) return;

    final token = tokenDoc.docs.first.data()['token'];

    await _firebase.firestore.collection('notificationQueue').add({
      'tokens': [token],
      'notification': {'title': title, 'body': body},
      'data': data ?? {},
      'priority': 'high',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update volunteer's average rating
  Future<void> _updateVolunteerRating(String volunteerId, double newRating) async {
    final volunteerDoc = await _volunteersRef.doc(volunteerId).get();
    final data = volunteerDoc.data() as Map<String, dynamic>?;

    if (data == null) return;

    final currentRating = (data['averageRating'] as num?)?.toDouble() ?? 0;
    final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

    final newAverage = ratingCount == 0
        ? newRating
        : ((currentRating * ratingCount) + newRating) / (ratingCount + 1);

    await _volunteersRef.doc(volunteerId).update({
      'averageRating': newAverage,
      'ratingCount': ratingCount + 1,
    });
  }
}
