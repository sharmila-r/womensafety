import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/background_location_service.dart';
import '../services/location_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final BackgroundLocationService _backgroundService = BackgroundLocationService();
  GoogleMapController? _mapController;
  StreamSubscription? _locationSubscription;

  bool _isTracking = false;
  Position? _currentPosition;
  final List<LatLng> _routePoints = [];
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  double _totalDistance = 0;
  DateTime? _trackingStartTime;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    await _backgroundService.initialize();
    _isTracking = await _backgroundService.isTracking();

    // Get current position
    _currentPosition = await LocationService.getCurrentLocation();
    if (_currentPosition != null) {
      _updateMarker(_currentPosition!);
    }

    // Listen to location updates
    _locationSubscription = _backgroundService.locationStream.listen((data) {
      if (data != null) {
        final lat = data['latitude'] as double;
        final lng = data['longitude'] as double;
        final distance = data['distance_from_last'] as double?;

        setState(() {
          _currentPosition = Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: data['accuracy'] ?? 0,
            altitude: data['altitude'] ?? 0,
            heading: data['heading'] ?? 0,
            speed: data['speed'] ?? 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );

          if (distance != null) {
            _totalDistance += distance;
          }

          _routePoints.add(LatLng(lat, lng));
          _updateMarker(_currentPosition!);
          _updatePolyline();
        });

        // Move camera to new position
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(lat, lng)),
        );
      }
    });

    setState(() {});
  }

  void _updateMarker(Position position) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(position.latitude, position.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(
          title: 'You are here',
          snippet: 'Accuracy: ${position.accuracy.toStringAsFixed(0)}m',
        ),
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

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _backgroundService.stopTracking();
      setState(() {
        _isTracking = false;
      });
    } else {
      final started = await _backgroundService.startTracking();
      if (started) {
        setState(() {
          _isTracking = true;
          _trackingStartTime = DateTime.now();
          _routePoints.clear();
          _totalDistance = 0;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start tracking. Please grant location permission.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleTracking,
            tooltip: _isTracking ? 'Stop tracking' : 'Start tracking',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(16),
            color: _isTracking ? const Color(0xFFE91E63) : Colors.grey,
            child: Row(
              children: [
                Icon(
                  _isTracking ? Icons.location_on : Icons.location_off,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isTracking ? 'Tracking Active' : 'Tracking Stopped',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_isTracking && _trackingStartTime != null)
                        Text(
                          'Started ${_formatDuration(DateTime.now().difference(_trackingStartTime!))}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isTracking)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(_totalDistance / 1000).toStringAsFixed(2)} km',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
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
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  ),
          ),

          // Bottom Info Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoTile(
                      icon: Icons.speed,
                      label: 'Speed',
                      value: _currentPosition != null
                          ? '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h'
                          : '--',
                    ),
                    _buildInfoTile(
                      icon: Icons.explore,
                      label: 'Heading',
                      value: _currentPosition != null
                          ? '${_currentPosition!.heading.toStringAsFixed(0)}°'
                          : '--',
                    ),
                    _buildInfoTile(
                      icon: Icons.height,
                      label: 'Altitude',
                      value: _currentPosition != null
                          ? '${_currentPosition!.altitude.toStringAsFixed(0)}m'
                          : '--',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Consumer<AppProvider>(
                  builder: (context, provider, _) {
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => provider.shareCurrentLocation(),
                            icon: const Icon(Icons.share_location),
                            label: const Text('Share Location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _toggleTracking,
                            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                            label: Text(_isTracking ? 'Stop' : 'Start'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFE91E63)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
