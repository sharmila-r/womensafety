import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
      // Check if this is demo mode
      if (eventId == 'demo_event') {
        _initializeDemoMode(odcId);
        return;
      }

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

  /// Initialize with demo/mock data for testing
  void _initializeDemoMode(String odcId) {
    // Create demo event
    _event = TVKEvent(
      id: 'demo_event',
      name: 'TVK Chennai Rally - Demo',
      description: 'Demo event for testing TVK Kavalan dashboard',
      location: TVKEventLocation(
        venue: 'Marina Beach, Chennai',
        address: 'Marina Beach Road, Chennai, Tamil Nadu',
        latitude: 13.0524,
        longitude: 80.2820,
      ),
      startTime: DateTime.now().subtract(const Duration(hours: 2)),
      endTime: DateTime.now().add(const Duration(hours: 4)),
      status: TVKEventStatus.active,
      capacity: 50000,
      settings: TVKEventSettings(),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now(),
    );

    // Create demo volunteer
    _currentVolunteer = TVKEventVolunteer(
      id: odcId,
      eventId: 'demo_event',
      odcId: odcId,
      name: 'Demo Volunteer',
      phone: '+91 98765 43210',
      role: TVKVolunteerRole.general,
      assignedZoneId: 'zone_a',
      assignedZoneName: 'Zone A - Main Stage',
      status: TVKVolunteerStatus.active,
      checkInTime: DateTime.now().subtract(const Duration(hours: 1)),
      latitude: 13.0524,
      longitude: 80.2820,
      lastLocationUpdate: DateTime.now(),
    );

    // Create demo zones
    _zones = [
      TVKZone(
        id: 'zone_a',
        eventId: 'demo_event',
        name: 'Zone A - Main Stage',
        type: TVKZoneType.stage,
        capacity: 15000,
        currentCount: 12500,
        densityPercent: 83,
        status: TVKZoneStatus.warning,
        polygon: [
          const LatLng(13.0530, 80.2810),
          const LatLng(13.0530, 80.2830),
          const LatLng(13.0518, 80.2830),
          const LatLng(13.0518, 80.2810),
        ],
        center: const LatLng(13.0524, 80.2820),
        assignedVolunteers: ['vol_003', 'vol_004'],
        lastUpdated: DateTime.now(),
      ),
      TVKZone(
        id: 'zone_b',
        eventId: 'demo_event',
        name: 'Zone B - Amenities',
        type: TVKZoneType.amenity,
        capacity: 5000,
        currentCount: 2500,
        densityPercent: 50,
        status: TVKZoneStatus.safe,
        polygon: [
          const LatLng(13.0540, 80.2810),
          const LatLng(13.0540, 80.2830),
          const LatLng(13.0530, 80.2830),
          const LatLng(13.0530, 80.2810),
        ],
        center: const LatLng(13.0535, 80.2820),
        assignedVolunteers: ['vol_002'],
        lastUpdated: DateTime.now(),
      ),
      TVKZone(
        id: 'zone_c',
        eventId: 'demo_event',
        name: 'Zone C - Entry Gate',
        type: TVKZoneType.entry,
        capacity: 3000,
        currentCount: 2800,
        densityPercent: 93,
        status: TVKZoneStatus.danger,
        polygon: [
          const LatLng(13.0510, 80.2810),
          const LatLng(13.0510, 80.2830),
          const LatLng(13.0500, 80.2830),
          const LatLng(13.0500, 80.2810),
        ],
        center: const LatLng(13.0505, 80.2820),
        assignedVolunteers: ['vol_001'],
        lastUpdated: DateTime.now(),
      ),
    ];

    // Create demo alerts
    _alerts = [
      TVKAlert(
        id: 'alert_1',
        eventId: 'demo_event',
        type: TVKAlertType.overcrowding,
        severity: TVKAlertSeverity.high,
        title: 'Overcrowding at Entry Gate',
        description: 'Heavy crowd at Zone C entry point. Immediate attention needed.',
        location: TVKAlertLocation(
          zoneId: 'zone_c',
          zoneName: 'Zone C - Entry Gate',
          latitude: 13.0505,
          longitude: 80.2820,
        ),
        status: TVKAlertStatus.active,
        createdBy: TVKAlertCreator(
          odcId: 'vol_001',
          name: 'Rajesh K',
          role: 'zone_captain',
        ),
        assignedTo: [],
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      TVKAlert(
        id: 'alert_2',
        eventId: 'demo_event',
        type: TVKAlertType.medical,
        severity: TVKAlertSeverity.medium,
        title: 'Medical assistance needed',
        description: 'Person feeling dizzy near amenities area.',
        location: TVKAlertLocation(
          zoneId: 'zone_b',
          zoneName: 'Zone B - Amenities',
          latitude: 13.0535,
          longitude: 80.2820,
        ),
        status: TVKAlertStatus.acknowledged,
        createdBy: TVKAlertCreator(
          odcId: 'vol_002',
          name: 'Priya S',
          role: 'general',
        ),
        assignedTo: ['vol_003'],
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    ];

    // Create demo volunteers
    _volunteers = [
      _currentVolunteer!,
      TVKEventVolunteer(
        id: 'vol_001',
        eventId: 'demo_event',
        odcId: 'vol_001',
        name: 'Rajesh Kumar',
        phone: '+91 98765 43211',
        role: TVKVolunteerRole.zoneCaptain,
        assignedZoneId: 'zone_c',
        assignedZoneName: 'Zone C - Entry Gate',
        status: TVKVolunteerStatus.active,
        checkInTime: DateTime.now().subtract(const Duration(hours: 3)),
        latitude: 13.0505,
        longitude: 80.2820,
        lastLocationUpdate: DateTime.now(),
      ),
      TVKEventVolunteer(
        id: 'vol_002',
        eventId: 'demo_event',
        odcId: 'vol_002',
        name: 'Priya Sharma',
        phone: '+91 98765 43212',
        role: TVKVolunteerRole.general,
        assignedZoneId: 'zone_b',
        assignedZoneName: 'Zone B - Amenities',
        status: TVKVolunteerStatus.active,
        checkInTime: DateTime.now().subtract(const Duration(hours: 2)),
        latitude: 13.0535,
        longitude: 80.2820,
        lastLocationUpdate: DateTime.now(),
      ),
      TVKEventVolunteer(
        id: 'vol_003',
        eventId: 'demo_event',
        odcId: 'vol_003',
        name: 'Dr. Anand R',
        phone: '+91 98765 43213',
        role: TVKVolunteerRole.medical,
        assignedZoneId: 'zone_a',
        assignedZoneName: 'Zone A - Main Stage',
        status: TVKVolunteerStatus.active,
        checkInTime: DateTime.now().subtract(const Duration(hours: 2)),
        latitude: 13.0524,
        longitude: 80.2820,
        lastLocationUpdate: DateTime.now(),
      ),
      TVKEventVolunteer(
        id: 'vol_004',
        eventId: 'demo_event',
        odcId: 'vol_004',
        name: 'Suresh M',
        phone: '+91 98765 43214',
        role: TVKVolunteerRole.security,
        assignedZoneId: 'zone_a',
        assignedZoneName: 'Zone A - Main Stage',
        status: TVKVolunteerStatus.onBreak,
        checkInTime: DateTime.now().subtract(const Duration(hours: 2)),
        latitude: 13.0520,
        longitude: 80.2815,
        lastLocationUpdate: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    ];

    // Create demo broadcasts
    _broadcasts = [
      TVKBroadcast(
        id: 'broadcast_1',
        eventId: 'demo_event',
        type: TVKBroadcastType.announcement,
        title: 'Water Break Reminder',
        message: 'All volunteers please take a water break. Stay hydrated!',
        audience: TVKBroadcastAudience(type: TVKAudienceType.all),
        sentBy: TVKBroadcastSender(odcId: 'admin_001', name: 'Control Room'),
        deliveredTo: 15,
        readBy: ['vol_001', 'vol_002'],
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      TVKBroadcast(
        id: 'broadcast_2',
        eventId: 'demo_event',
        type: TVKBroadcastType.emergency,
        title: 'Zone C Alert',
        message: 'All nearby volunteers report to Zone C immediately. Crowd control needed.',
        audience: TVKBroadcastAudience(
          type: TVKAudienceType.zone,
          zones: ['zone_c', 'zone_b'],
        ),
        sentBy: TVKBroadcastSender(odcId: 'admin_001', name: 'Control Room'),
        deliveredTo: 8,
        readBy: ['vol_001'],
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];

    // Create demo stats
    _stats = TVKEventStats(
      totalCrowd: 17800,
      avgDensityPercent: 75.3,
      totalVolunteers: 5,
      activeVolunteers: 4,
      activeAlerts: 2,
      criticalAlerts: 1,
    );

    _isLoading = false;
    notifyListeners();
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
