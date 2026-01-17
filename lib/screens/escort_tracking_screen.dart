import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../providers/app_provider.dart';
import '../services/background_location_service.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';
import '../services/firebase_service.dart';
import '../models/trusted_contact.dart';
import '../config/env_config.dart';

/// Real-time escort tracking screen
/// Shares live location with trusted contacts during an escort/journey
class EscortTrackingScreen extends StatefulWidget {
  final String? escortId;
  final String? destination;
  final String? volunteerName;
  final double? destinationLat;
  final double? destinationLng;

  const EscortTrackingScreen({
    super.key,
    this.escortId,
    this.destination,
    this.volunteerName,
    this.destinationLat,
    this.destinationLng,
  });

  @override
  State<EscortTrackingScreen> createState() => _EscortTrackingScreenState();
}

class _EscortTrackingScreenState extends State<EscortTrackingScreen> {
  final BackgroundLocationService _backgroundService = BackgroundLocationService();
  final FirebaseService _firebase = FirebaseService.instance;

  GoogleMapController? _mapController;
  StreamSubscription? _locationSubscription;

  bool _isTracking = false;
  bool _isLoading = true;
  Position? _currentPosition;
  String? _currentAddress;
  String? _trackingSessionId;

  final List<LatLng> _routePoints = [];
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  DateTime? _startTime;
  double _totalDistance = 0;
  bool _contactsNotified = false;

  // ETA and route visualization
  String? _etaText;
  String? _distanceToDestination;
  List<LatLng> _plannedRoute = [];
  Timer? _etaUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _etaUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    setState(() => _isLoading = true);

    try {
      await _backgroundService.initialize();

      // Get current position
      _currentPosition = await LocationService.getCurrentLocation();
      if (_currentPosition != null) {
        _currentAddress = await LocationService.getAddressFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        _updateMarker(_currentPosition!);

        // Fetch route and ETA if destination is provided
        if (widget.destinationLat != null && widget.destinationLng != null) {
          await _fetchRouteAndETA();
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
      }
    }
  }

  /// Fetch route from Google Directions API and calculate ETA
  Future<void> _fetchRouteAndETA() async {
    if (_currentPosition == null ||
        widget.destinationLat == null ||
        widget.destinationLng == null) {
      return;
    }

    try {
      final apiKey = EnvConfig.googleMapsApiKey;
      if (apiKey.isEmpty) {
        debugPrint('Google Maps API key not configured');
        return;
      }

      final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
      final destination = '${widget.destinationLat},${widget.destinationLng}';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$origin'
        '&destination=$destination'
        '&mode=walking'
        '&key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Extract ETA and distance
          final duration = leg['duration'];
          final distance = leg['distance'];

          setState(() {
            _etaText = duration['text'];
            _distanceToDestination = distance['text'];
          });

          // Decode polyline for route visualization
          final encodedPolyline = route['overview_polyline']['points'];
          _plannedRoute = _decodePolyline(encodedPolyline);
          _updatePlannedRoutePolyline();

          // Add destination marker
          _addDestinationMarker();

          debugPrint('ETA: $_etaText, Distance: $_distanceToDestination');
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    }
  }

  /// Decode Google Maps encoded polyline
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;

      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Update polyline with planned route
  void _updatePlannedRoutePolyline() {
    if (_plannedRoute.isEmpty) return;

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('planned_route'),
        points: _plannedRoute,
        color: Colors.blue.withOpacity(0.6),
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );
    setState(() {});
  }

  /// Add destination marker
  void _addDestinationMarker() {
    if (widget.destinationLat == null || widget.destinationLng == null) return;

    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destinationLat!, widget.destinationLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Destination',
          snippet: widget.destination ?? 'Your destination',
        ),
      ),
    );
    setState(() {});
  }

  /// Start periodic ETA updates
  void _startETAUpdates() {
    _etaUpdateTimer?.cancel();
    _etaUpdateTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _fetchRouteAndETA();
    });
  }

  Future<void> _startTracking() async {
    final provider = Provider.of<AppProvider>(context, listen: false);

    // Create tracking session in Firestore
    final sessionRef = await _firebase.firestore.collection('trackingSessions').add({
      'userId': _firebase.auth.currentUser?.uid,
      'startTime': FieldValue.serverTimestamp(),
      'destination': widget.destination,
      'volunteerName': widget.volunteerName,
      'escortId': widget.escortId,
      'status': 'active',
      'routePoints': [],
      'lastLocation': _currentPosition != null ? {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      } : null,
    });

    _trackingSessionId = sessionRef.id;
    _startTime = DateTime.now();

    // Start background tracking
    await _backgroundService.startTracking();

    // Listen to location updates
    _locationSubscription = _backgroundService.locationStream.listen((data) {
      if (data != null) {
        _handleLocationUpdate(data);
      }
    });

    // Notify trusted contacts
    if (!_contactsNotified) {
      await _notifyTrustedContacts(provider.emergencyContacts);
      _contactsNotified = true;
    }

    // Start periodic ETA updates if destination is set
    if (widget.destinationLat != null && widget.destinationLng != null) {
      _startETAUpdates();
    }

    setState(() => _isTracking = true);
  }

  void _handleLocationUpdate(Map<String, dynamic> data) {
    final lat = (data['latitude'] as num).toDouble();
    final lng = (data['longitude'] as num).toDouble();
    final distance = data['distance_from_last'] != null
        ? (data['distance_from_last'] as num).toDouble()
        : null;

    setState(() {
      _currentPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
        altitude: (data['altitude'] as num?)?.toDouble() ?? 0.0,
        heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
        speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );

      if (distance != null) {
        _totalDistance += distance;
      }

      _routePoints.add(LatLng(lat, lng));
      _updateMarker(_currentPosition!);
      _updatePolyline();
    });

    // Update Firestore with latest location
    _updateFirestoreLocation(lat, lng);

    // Move camera
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(lat, lng)),
    );
  }

  Future<void> _updateFirestoreLocation(double lat, double lng) async {
    if (_trackingSessionId == null) return;

    await _firebase.firestore
        .collection('trackingSessions')
        .doc(_trackingSessionId)
        .update({
      'lastLocation': {
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().toIso8601String(),
      },
      'routePoints': FieldValue.arrayUnion([
        {'lat': lat, 'lng': lng, 'time': DateTime.now().toIso8601String()}
      ]),
      'totalDistance': _totalDistance,
    });
  }

  Future<void> _notifyTrustedContacts(List<TrustedContact> contacts) async {
    if (contacts.isEmpty) return;

    final trackingUrl = _getTrackingUrl();
    final message = widget.volunteerName != null
        ? '🚶 I\'m being escorted by ${widget.volunteerName}. Track my live location: $trackingUrl'
        : '📍 I\'ve started sharing my live location with you. Track me here: $trackingUrl';

    // Send SMS to all emergency contacts
    final phoneNumbers = contacts.map((c) => c.phone).toList();
    await SmsService.sendSMS(
      phoneNumbers: phoneNumbers,
      message: message,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location shared with ${contacts.length} contacts'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _getTrackingUrl() {
    // Generate a shareable tracking URL
    // In production, this would be a web app URL that shows the live location
    if (_trackingSessionId != null) {
      return 'https://kaavala.app/track/$_trackingSessionId';
    }
    // Fallback to Google Maps link
    if (_currentPosition != null) {
      return 'https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
    }
    return 'https://kaavala.app/track';
  }

  Future<void> _stopTracking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Tracking?'),
        content: const Text(
          'This will stop sharing your location with your trusted contacts. Are you sure you\'ve reached safely?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Tracking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('I\'m Safe'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _backgroundService.stopTracking();
    _locationSubscription?.cancel();

    // Update Firestore session
    if (_trackingSessionId != null) {
      await _firebase.firestore
          .collection('trackingSessions')
          .doc(_trackingSessionId)
          .update({
        'status': 'completed',
        'endTime': FieldValue.serverTimestamp(),
        'totalDistance': _totalDistance,
      });
    }

    // Notify contacts that tracking ended
    final provider = Provider.of<AppProvider>(context, listen: false);
    final phoneNumbers = provider.emergencyContacts.map((c) => c.phone).toList();
    if (phoneNumbers.isNotEmpty) {
      await SmsService.sendSMS(
        phoneNumbers: phoneNumbers,
        message: '✅ I\'ve reached my destination safely. Thank you for watching over me!',
      );
    }

    setState(() => _isTracking = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tracking ended. Contacts notified.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _updateMarker(Position position) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(position.latitude, position.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: const InfoWindow(title: 'You are here'),
      ),
    );
  }

  void _updatePolyline() {
    _polylines.clear();
    if (_routePoints.length > 1) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: const Color(0xFFE91E63),
          width: 4,
        ),
      );
    }
  }

  void _shareLocation() {
    final url = _getTrackingUrl();
    Share.share(
      'Track my live location: $url',
      subject: 'My Live Location',
    );
  }

  void _triggerSOS() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.triggerSOS();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Alert sent!'),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isTracking ? 'Live Tracking' : 'Start Escort Tracking'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          if (_isTracking)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareLocation,
              tooltip: 'Share Location',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Status bar
                _buildStatusBar(),

                // Map
                Expanded(
                  child: _currentPosition == null
                      ? const Center(child: Text('Getting location...'))
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            zoom: 16,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                          markers: _markers,
                          polylines: _polylines,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: false,
                        ),
                ),

                // Control panel
                _buildControlPanel(),
              ],
            ),
    );
  }

  Widget _buildStatusBar() {
    if (!_isTracking && _etaText == null) return const SizedBox.shrink();

    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _isTracking ? Colors.green.shade50 : Colors.blue.shade50,
      child: Row(
        children: [
          if (_isTracking) ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          // ETA display
          if (_etaText != null) ...[
            if (_isTracking) const SizedBox(width: 16),
            const Icon(Icons.schedule, size: 16, color: Colors.blue),
            const SizedBox(width: 4),
            Text(
              'ETA: $_etaText',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_distanceToDestination != null) ...[
              const SizedBox(width: 8),
              Text(
                '($_distanceToDestination)',
                style: TextStyle(
                  color: Colors.blue.shade300,
                  fontSize: 12,
                ),
              ),
            ],
          ],
          const Spacer(),
          if (_isTracking)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(_totalDistance / 1000).toStringAsFixed(2)} km traveled',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Destination info
            if (widget.destination != null) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFE91E63)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Destination',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          widget.destination!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Volunteer info
            if (widget.volunteerName != null) ...[
              Row(
                children: [
                  const Icon(Icons.volunteer_activism, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Escorted by: ${widget.volunteerName}'),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            if (!_isTracking) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'Start Live Tracking',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your trusted contacts will receive your live location',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Row(
                children: [
                  // SOS Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _triggerSOS,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.warning),
                      label: const Text('SOS'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Stop tracking button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _stopTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('I\'m Safe - End'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
