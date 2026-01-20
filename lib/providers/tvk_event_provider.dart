import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/tvk/tvk_event.dart';
import '../models/tvk/tvk_zone.dart';
import '../models/tvk/tvk_alert.dart';
import '../models/tvk/tvk_broadcast.dart';
import '../models/tvk/tvk_event_volunteer.dart';
import '../services/tvk_event_service.dart';

/// Provider for TVK Event Dashboard state management
class TVKEventProvider extends ChangeNotifier {
  final TVKEventService _service = TVKEventService();

  // State
  TVKEvent? _event;
  TVKEventVolunteer? _currentVolunteer;
  List<TVKZone> _zones = [];
  List<TVKAlert> _alerts = [];
  List<TVKEventVolunteer> _volunteers = [];
  List<TVKBroadcast> _broadcasts = [];
  TVKEventStats? _stats;

  bool _isLoading = false;
  String? _error;

  // Subscriptions
  StreamSubscription? _zonesSubscription;
  StreamSubscription? _alertsSubscription;
  StreamSubscription? _volunteersSubscription;
  StreamSubscription? _broadcastsSubscription;
  StreamSubscription? _statsSubscription;

  // Getters
  TVKEvent? get event => _event;
  TVKEventVolunteer? get currentVolunteer => _currentVolunteer;
  List<TVKZone> get zones => _zones;
  List<TVKAlert> get alerts => _alerts;
  List<TVKAlert> get activeAlerts => _alerts.where((a) => a.isActive).toList();
  List<TVKAlert> get criticalAlerts => _alerts.where((a) => a.isCritical && a.isActive).toList();
  List<TVKEventVolunteer> get volunteers => _volunteers;
  List<TVKBroadcast> get broadcasts => _broadcasts;
  TVKEventStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveEvent => _event != null && _event!.isActive;

  // Computed getters
  int get activeVolunteerCount => _volunteers.where((v) => v.isActive).length;
  int get onBreakVolunteerCount => _volunteers.where((v) => v.isOnBreak).length;

  Map<TVKVolunteerRole, List<TVKEventVolunteer>> get volunteersByRole {
    final grouped = <TVKVolunteerRole, List<TVKEventVolunteer>>{};
    for (final volunteer in _volunteers) {
      grouped.putIfAbsent(volunteer.role, () => []).add(volunteer);
    }
    // Sort by role priority
    final sorted = Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.sortOrder.compareTo(b.key.sortOrder)),
    );
    return sorted;
  }

  List<TVKZone> get dangerZones => _zones.where((z) => z.status == TVKZoneStatus.danger).toList();
  List<TVKZone> get warningZones => _zones.where((z) => z.status == TVKZoneStatus.warning).toList();

  /// Initialize provider with event ID
  Future<void> initialize(String eventId, String odcId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load event
      _event = await _service.getEvent(eventId);
      if (_event == null) {
        _error = 'Event not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Load current volunteer
      _currentVolunteer = await _service.getCurrentVolunteer(eventId, odcId);

      // Start real-time subscriptions
      _startSubscriptions(eventId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load event: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start real-time data subscriptions
  void _startSubscriptions(String eventId) {
    // Zones stream
    _zonesSubscription = _service.streamZones(eventId).listen((zones) {
      _zones = zones;
      notifyListeners();
    });

    // Alerts stream
    _alertsSubscription = _service.streamAlerts(eventId).listen((alerts) {
      _alerts = alerts;
      notifyListeners();
    });

    // Volunteers stream
    _volunteersSubscription = _service.streamVolunteers(eventId).listen((volunteers) {
      _volunteers = volunteers;
      notifyListeners();
    });

    // Broadcasts stream
    _broadcastsSubscription = _service.streamBroadcasts(eventId).listen((broadcasts) {
      _broadcasts = broadcasts;
      notifyListeners();
    });

    // Stats stream
    _statsSubscription = _service.streamEventStats(eventId).listen((stats) {
      _stats = stats;
      notifyListeners();
    });
  }

  /// Refresh all data
  Future<void> refresh() async {
    if (_event == null) return;

    try {
      _zones = await _service.getZones(_event!.id);
      _alerts = await _service.getAlerts(_event!.id);
      _volunteers = await _service.getVolunteers(_event!.id);
      _broadcasts = await _service.getBroadcasts(_event!.id);
      _stats = await _service.getEventStats(_event!.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing TVK data: $e');
    }
  }

  // ============ ZONE ACTIONS ============

  /// Update zone crowd count
  Future<void> updateZoneCount(String zoneId, int newCount) async {
    if (_event == null) return;

    try {
      await _service.updateZoneCount(_event!.id, zoneId, newCount);
    } catch (e) {
      _error = 'Failed to update zone count: $e';
      notifyListeners();
    }
  }

  /// Get zone by ID
  TVKZone? getZone(String zoneId) {
    return _zones.firstWhere((z) => z.id == zoneId, orElse: () => _zones.first);
  }

  // ============ ALERT ACTIONS ============

  /// Create new alert
  Future<String?> createAlert({
    required TVKAlertType type,
    required TVKAlertSeverity severity,
    required String title,
    required String description,
    String? zoneId,
    String? zoneName,
    required double latitude,
    required double longitude,
  }) async {
    if (_event == null || _currentVolunteer == null) return null;

    try {
      final alert = TVKAlert(
        id: '',
        eventId: _event!.id,
        type: type,
        severity: severity,
        title: title,
        description: description,
        location: TVKAlertLocation(
          zoneId: zoneId,
          zoneName: zoneName,
          latitude: latitude,
          longitude: longitude,
        ),
        status: TVKAlertStatus.active,
        createdBy: TVKAlertCreator(
          odcId: _currentVolunteer!.odcId,
          name: _currentVolunteer!.name,
          role: _currentVolunteer!.role.value,
        ),
        assignedTo: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await _service.createAlert(_event!.id, alert);
    } catch (e) {
      _error = 'Failed to create alert: $e';
      notifyListeners();
      return null;
    }
  }

  /// Acknowledge alert
  Future<void> acknowledgeAlert(String alertId) async {
    if (_event == null) return;

    try {
      await _service.updateAlertStatus(
        _event!.id,
        alertId,
        TVKAlertStatus.acknowledged,
      );
    } catch (e) {
      _error = 'Failed to acknowledge alert: $e';
      notifyListeners();
    }
  }

  /// Resolve alert
  Future<void> resolveAlert(String alertId) async {
    if (_event == null || _currentVolunteer == null) return;

    try {
      await _service.updateAlertStatus(
        _event!.id,
        alertId,
        TVKAlertStatus.resolved,
        resolvedBy: _currentVolunteer!.name,
      );
    } catch (e) {
      _error = 'Failed to resolve alert: $e';
      notifyListeners();
    }
  }

  /// Assign volunteers to alert
  Future<void> assignVolunteersToAlert(String alertId, List<String> volunteerIds) async {
    if (_event == null) return;

    try {
      await _service.assignToAlert(_event!.id, alertId, volunteerIds);
    } catch (e) {
      _error = 'Failed to assign volunteers: $e';
      notifyListeners();
    }
  }

  // ============ VOLUNTEER ACTIONS ============

  /// Update current volunteer status
  Future<void> updateMyStatus(TVKVolunteerStatus status) async {
    if (_event == null || _currentVolunteer == null) return;

    try {
      await _service.updateVolunteerStatus(
        _event!.id,
        _currentVolunteer!.odcId,
        status,
      );
    } catch (e) {
      _error = 'Failed to update status: $e';
      notifyListeners();
    }
  }

  /// Update current volunteer location
  Future<void> updateMyLocation(double latitude, double longitude) async {
    if (_event == null || _currentVolunteer == null) return;

    try {
      await _service.updateVolunteerLocation(
        _event!.id,
        _currentVolunteer!.odcId,
        latitude,
        longitude,
      );
    } catch (e) {
      debugPrint('Failed to update location: $e');
    }
  }

  /// Check in to event
  Future<void> checkIn() async {
    if (_event == null || _currentVolunteer == null) return;

    try {
      await _service.checkInVolunteer(_event!.id, _currentVolunteer!.odcId);
    } catch (e) {
      _error = 'Failed to check in: $e';
      notifyListeners();
    }
  }

  /// Check out from event
  Future<void> checkOut() async {
    if (_event == null || _currentVolunteer == null) return;

    try {
      await _service.checkOutVolunteer(_event!.id, _currentVolunteer!.odcId);
    } catch (e) {
      _error = 'Failed to check out: $e';
      notifyListeners();
    }
  }

  /// Get volunteers by zone
  List<TVKEventVolunteer> getVolunteersByZone(String zoneId) {
    return _volunteers.where((v) => v.assignedZoneId == zoneId).toList();
  }

  // ============ BROADCAST ACTIONS ============

  /// Send broadcast message
  Future<String?> sendBroadcast({
    required TVKBroadcastType type,
    required String title,
    required String message,
    required TVKBroadcastAudience audience,
  }) async {
    if (_event == null || _currentVolunteer == null) return null;

    try {
      final broadcast = TVKBroadcast(
        id: '',
        eventId: _event!.id,
        type: type,
        title: title,
        message: message,
        audience: audience,
        sentBy: TVKBroadcastSender(
          odcId: _currentVolunteer!.odcId,
          name: _currentVolunteer!.name,
        ),
        deliveredTo: 0,
        readBy: [],
        createdAt: DateTime.now(),
      );

      return await _service.sendBroadcast(_event!.id, broadcast);
    } catch (e) {
      _error = 'Failed to send broadcast: $e';
      notifyListeners();
      return null;
    }
  }

  /// Mark broadcast as read
  Future<void> markBroadcastRead(String broadcastId) async {
    if (_event == null || _currentVolunteer == null) return;

    try {
      await _service.markBroadcastRead(
        _event!.id,
        broadcastId,
        _currentVolunteer!.odcId,
      );
    } catch (e) {
      debugPrint('Failed to mark broadcast read: $e');
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _zonesSubscription?.cancel();
    _alertsSubscription?.cancel();
    _volunteersSubscription?.cancel();
    _broadcastsSubscription?.cancel();
    _statsSubscription?.cancel();
    super.dispose();
  }
}
