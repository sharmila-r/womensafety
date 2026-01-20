import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tvk/tvk_event.dart';
import '../models/tvk/tvk_zone.dart';
import '../models/tvk/tvk_alert.dart';
import '../models/tvk/tvk_broadcast.dart';
import '../models/tvk/tvk_event_volunteer.dart';

/// Service for TVK Event Firestore operations
class TVKEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _eventsRef => _firestore.collection('tvkEvents');

  CollectionReference _zonesRef(String eventId) =>
      _eventsRef.doc(eventId).collection('zones');

  CollectionReference _alertsRef(String eventId) =>
      _eventsRef.doc(eventId).collection('alerts');

  CollectionReference _volunteersRef(String eventId) =>
      _eventsRef.doc(eventId).collection('volunteers');

  CollectionReference _broadcastsRef(String eventId) =>
      _eventsRef.doc(eventId).collection('broadcasts');

  // ============ EVENT OPERATIONS ============

  /// Get active event
  Future<TVKEvent?> getActiveEvent() async {
    final snapshot = await _eventsRef
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return TVKEvent.fromFirestore(snapshot.docs.first);
  }

  /// Get event by ID
  Future<TVKEvent?> getEvent(String eventId) async {
    final doc = await _eventsRef.doc(eventId).get();
    if (!doc.exists) return null;
    return TVKEvent.fromFirestore(doc);
  }

  /// Stream event updates
  Stream<TVKEvent?> streamEvent(String eventId) {
    return _eventsRef.doc(eventId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TVKEvent.fromFirestore(doc);
    });
  }

  // ============ ZONE OPERATIONS ============

  /// Get all zones for an event
  Future<List<TVKZone>> getZones(String eventId) async {
    final snapshot = await _zonesRef(eventId).get();
    return snapshot.docs
        .map((doc) => TVKZone.fromFirestore(doc, eventId))
        .toList();
  }

  /// Stream zones for real-time updates
  Stream<List<TVKZone>> streamZones(String eventId) {
    return _zonesRef(eventId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TVKZone.fromFirestore(doc, eventId))
          .toList();
    });
  }

  /// Update zone crowd count
  Future<void> updateZoneCount(String eventId, String zoneId, int newCount) async {
    final zoneDoc = await _zonesRef(eventId).doc(zoneId).get();
    if (!zoneDoc.exists) return;

    final zone = TVKZone.fromFirestore(zoneDoc, eventId);
    final updatedZone = zone.copyWithCount(newCount);

    await _zonesRef(eventId).doc(zoneId).update({
      'currentCount': updatedZone.currentCount,
      'densityPercent': updatedZone.densityPercent,
      'status': updatedZone.status.value,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Get zone by ID
  Future<TVKZone?> getZone(String eventId, String zoneId) async {
    final doc = await _zonesRef(eventId).doc(zoneId).get();
    if (!doc.exists) return null;
    return TVKZone.fromFirestore(doc, eventId);
  }

  // ============ ALERT OPERATIONS ============

  /// Get active alerts
  Future<List<TVKAlert>> getActiveAlerts(String eventId) async {
    final snapshot = await _alertsRef(eventId)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TVKAlert.fromFirestore(doc, eventId))
        .toList();
  }

  /// Get all alerts (with optional status filter)
  Future<List<TVKAlert>> getAlerts(String eventId, {String? status}) async {
    Query query = _alertsRef(eventId).orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query.limit(50).get();
    return snapshot.docs
        .map((doc) => TVKAlert.fromFirestore(doc, eventId))
        .toList();
  }

  /// Stream alerts for real-time updates
  Stream<List<TVKAlert>> streamAlerts(String eventId) {
    return _alertsRef(eventId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TVKAlert.fromFirestore(doc, eventId))
          .toList();
    });
  }

  /// Stream active alerts only
  Stream<List<TVKAlert>> streamActiveAlerts(String eventId) {
    return _alertsRef(eventId)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TVKAlert.fromFirestore(doc, eventId))
          .toList();
    });
  }

  /// Create new alert
  Future<String> createAlert(String eventId, TVKAlert alert) async {
    final docRef = await _alertsRef(eventId).add(alert.toMap());
    return docRef.id;
  }

  /// Update alert status
  Future<void> updateAlertStatus(
    String eventId,
    String alertId,
    TVKAlertStatus status, {
    String? resolvedBy,
  }) async {
    final updates = <String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == TVKAlertStatus.resolved && resolvedBy != null) {
      updates['resolvedBy'] = resolvedBy;
      updates['resolvedAt'] = FieldValue.serverTimestamp();
    }

    await _alertsRef(eventId).doc(alertId).update(updates);
  }

  /// Assign volunteers to alert
  Future<void> assignToAlert(
    String eventId,
    String alertId,
    List<String> volunteerIds,
  ) async {
    await _alertsRef(eventId).doc(alertId).update({
      'assignedTo': FieldValue.arrayUnion(volunteerIds),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ VOLUNTEER OPERATIONS ============

  /// Get all volunteers for an event
  Future<List<TVKEventVolunteer>> getVolunteers(String eventId) async {
    final snapshot = await _volunteersRef(eventId).get();
    return snapshot.docs
        .map((doc) => TVKEventVolunteer.fromFirestore(doc, eventId))
        .toList();
  }

  /// Stream volunteers for real-time updates
  Stream<List<TVKEventVolunteer>> streamVolunteers(String eventId) {
    return _volunteersRef(eventId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TVKEventVolunteer.fromFirestore(doc, eventId))
          .toList();
    });
  }

  /// Get current user's volunteer record for event
  Future<TVKEventVolunteer?> getCurrentVolunteer(String eventId, String odcId) async {
    final snapshot = await _volunteersRef(eventId)
        .where('odcId', isEqualTo: odcId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return TVKEventVolunteer.fromFirestore(snapshot.docs.first, eventId);
  }

  /// Update volunteer status
  Future<void> updateVolunteerStatus(
    String eventId,
    String odcId,
    TVKVolunteerStatus status,
  ) async {
    final snapshot = await _volunteersRef(eventId)
        .where('odcId', isEqualTo: odcId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;

    await snapshot.docs.first.reference.update({
      'status': status.value,
    });
  }

  /// Update volunteer location
  Future<void> updateVolunteerLocation(
    String eventId,
    String odcId,
    double latitude,
    double longitude,
  ) async {
    final snapshot = await _volunteersRef(eventId)
        .where('odcId', isEqualTo: odcId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;

    await snapshot.docs.first.reference.update({
      'currentLocation': GeoPoint(latitude, longitude),
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }

  /// Check in volunteer to event
  Future<void> checkInVolunteer(String eventId, String odcId) async {
    final snapshot = await _volunteersRef(eventId)
        .where('odcId', isEqualTo: odcId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;

    await snapshot.docs.first.reference.update({
      'checkInTime': FieldValue.serverTimestamp(),
      'checkOutTime': null,
      'status': TVKVolunteerStatus.active.value,
    });
  }

  /// Check out volunteer from event
  Future<void> checkOutVolunteer(String eventId, String odcId) async {
    final snapshot = await _volunteersRef(eventId)
        .where('odcId', isEqualTo: odcId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;

    await snapshot.docs.first.reference.update({
      'checkOutTime': FieldValue.serverTimestamp(),
      'status': TVKVolunteerStatus.offline.value,
    });
  }

  /// Get volunteers by role
  Future<List<TVKEventVolunteer>> getVolunteersByRole(
    String eventId,
    TVKVolunteerRole role,
  ) async {
    final snapshot = await _volunteersRef(eventId)
        .where('role', isEqualTo: role.value)
        .get();

    return snapshot.docs
        .map((doc) => TVKEventVolunteer.fromFirestore(doc, eventId))
        .toList();
  }

  /// Get volunteers by zone
  Future<List<TVKEventVolunteer>> getVolunteersByZone(
    String eventId,
    String zoneId,
  ) async {
    final snapshot = await _volunteersRef(eventId)
        .where('assignedZone', isEqualTo: zoneId)
        .get();

    return snapshot.docs
        .map((doc) => TVKEventVolunteer.fromFirestore(doc, eventId))
        .toList();
  }

  // ============ BROADCAST OPERATIONS ============

  /// Get recent broadcasts
  Future<List<TVKBroadcast>> getBroadcasts(String eventId, {int limit = 20}) async {
    final snapshot = await _broadcastsRef(eventId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => TVKBroadcast.fromFirestore(doc, eventId))
        .toList();
  }

  /// Stream broadcasts
  Stream<List<TVKBroadcast>> streamBroadcasts(String eventId) {
    return _broadcastsRef(eventId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TVKBroadcast.fromFirestore(doc, eventId))
          .toList();
    });
  }

  /// Send broadcast
  Future<String> sendBroadcast(String eventId, TVKBroadcast broadcast) async {
    final docRef = await _broadcastsRef(eventId).add(broadcast.toMap());

    // TODO: Trigger Cloud Function to send FCM notifications to targeted volunteers

    return docRef.id;
  }

  /// Mark broadcast as read
  Future<void> markBroadcastRead(String eventId, String broadcastId, String odcId) async {
    await _broadcastsRef(eventId).doc(broadcastId).update({
      'readBy': FieldValue.arrayUnion([odcId]),
    });
  }

  // ============ STATS ============

  /// Get event statistics
  Future<TVKEventStats> getEventStats(String eventId) async {
    final zones = await getZones(eventId);
    final volunteers = await getVolunteers(eventId);
    final activeAlerts = await getActiveAlerts(eventId);

    int totalCrowd = 0;
    double totalDensity = 0;

    for (final zone in zones) {
      totalCrowd += zone.currentCount;
      totalDensity += zone.densityPercent;
    }

    final avgDensity = zones.isNotEmpty ? totalDensity / zones.length : 0.0;
    final activeVolunteers = volunteers.where((v) => v.isActive).length;

    return TVKEventStats(
      totalCrowd: totalCrowd,
      avgDensityPercent: avgDensity,
      totalVolunteers: volunteers.length,
      activeVolunteers: activeVolunteers,
      activeAlerts: activeAlerts.length,
      criticalAlerts: activeAlerts.where((a) => a.isCritical).length,
    );
  }

  /// Stream event statistics
  Stream<TVKEventStats> streamEventStats(String eventId) {
    // Combine streams for real-time stats
    return streamZones(eventId).asyncMap((zones) async {
      final volunteers = await getVolunteers(eventId);
      final activeAlerts = await getActiveAlerts(eventId);

      int totalCrowd = 0;
      double totalDensity = 0;

      for (final zone in zones) {
        totalCrowd += zone.currentCount;
        totalDensity += zone.densityPercent;
      }

      final avgDensity = zones.isNotEmpty ? totalDensity / zones.length : 0.0;
      final activeVolunteers = volunteers.where((v) => v.isActive).length;

      return TVKEventStats(
        totalCrowd: totalCrowd,
        avgDensityPercent: avgDensity,
        totalVolunteers: volunteers.length,
        activeVolunteers: activeVolunteers,
        activeAlerts: activeAlerts.length,
        criticalAlerts: activeAlerts.where((a) => a.isCritical).length,
      );
    });
  }
}

/// Event statistics model
class TVKEventStats {
  final int totalCrowd;
  final double avgDensityPercent;
  final int totalVolunteers;
  final int activeVolunteers;
  final int activeAlerts;
  final int criticalAlerts;

  TVKEventStats({
    required this.totalCrowd,
    required this.avgDensityPercent,
    required this.totalVolunteers,
    required this.activeVolunteers,
    required this.activeAlerts,
    required this.criticalAlerts,
  });

  String get formattedCrowd {
    if (totalCrowd >= 1000) {
      return '${(totalCrowd / 1000).toStringAsFixed(1)}K';
    }
    return totalCrowd.toString();
  }

  String get formattedDensity => '${avgDensityPercent.toInt()}%';
}
