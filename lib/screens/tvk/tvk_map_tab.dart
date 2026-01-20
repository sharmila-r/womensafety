import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/tvk_event_provider.dart';
import '../../models/tvk/tvk_zone.dart';
import '../../models/tvk/tvk_event_volunteer.dart';
import '../../services/location_service.dart';
import '../../widgets/tvk/tvk_theme.dart';
import 'tvk_zone_detail_screen.dart';

/// Map tab for TVK Dashboard showing zones, volunteers, and crowd density
class TVKMapTab extends StatefulWidget {
  const TVKMapTab({super.key});

  @override
  State<TVKMapTab> createState() => _TVKMapTabState();
}

class _TVKMapTabState extends State<TVKMapTab> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Timer? _locationTimer;

  // Map elements
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};

  // Filter state
  bool _showVolunteers = true;
  TVKZoneStatus? _zoneFilter;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    // Get current position
    _currentPosition = await LocationService.getCurrentLocation();
    if (mounted) setState(() {});

    // Start location updates for current volunteer
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final position = await LocationService.getCurrentLocation();
      if (position != null && mounted) {
        context.read<TVKEventProvider>().updateMyLocation(
          position.latitude,
          position.longitude,
        );
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TVKEventProvider>(
      builder: (context, provider, child) {
        _buildMapElements(provider);

        return Column(
          children: [
            // Filter bar
            _buildFilterBar(provider),
            // Map
            Expanded(
              child: Stack(
                children: [
                  _buildMap(provider),
                  // Legend
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: _buildLegend(),
                  ),
                  // My location button
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'my_location',
                      backgroundColor: Colors.white,
                      onPressed: _goToMyLocation,
                      child: const Icon(Icons.my_location, color: TVKColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(TVKEventProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Zone filter chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'All Zones',
                    selected: _zoneFilter == null,
                    onSelected: () => setState(() => _zoneFilter = null),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Danger',
                    selected: _zoneFilter == TVKZoneStatus.danger,
                    color: TVKColors.zoneDanger,
                    onSelected: () => setState(() => _zoneFilter = TVKZoneStatus.danger),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Warning',
                    selected: _zoneFilter == TVKZoneStatus.warning,
                    color: TVKColors.zoneWarning,
                    onSelected: () => setState(() => _zoneFilter = TVKZoneStatus.warning),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Safe',
                    selected: _zoneFilter == TVKZoneStatus.safe,
                    color: TVKColors.zoneSafe,
                    onSelected: () => setState(() => _zoneFilter = TVKZoneStatus.safe),
                  ),
                ],
              ),
            ),
          ),
          // Volunteer toggle
          IconButton(
            icon: Icon(
              _showVolunteers ? Icons.people : Icons.people_outline,
              color: _showVolunteers ? TVKColors.primary : TVKColors.textSecondary,
            ),
            onPressed: () => setState(() => _showVolunteers = !_showVolunteers),
            tooltip: _showVolunteers ? 'Hide Volunteers' : 'Show Volunteers',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    Color? color,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : TVKColors.textPrimary,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: color ?? TVKColors.primary,
      backgroundColor: TVKColors.background,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildMap(TVKEventProvider provider) {
    // Default to event location or Chennai
    LatLng initialPosition;
    if (provider.event?.location != null) {
      initialPosition = LatLng(
        provider.event!.location.latitude,
        provider.event!.location.longitude,
      );
    } else if (_currentPosition != null) {
      initialPosition = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    } else {
      // Default to Chennai
      initialPosition = const LatLng(13.0827, 80.2707);
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 15,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      polygons: _polygons,
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );
  }

  void _buildMapElements(TVKEventProvider provider) {
    _polygons = {};
    _markers = {};

    // Build zone polygons
    for (final zone in provider.zones) {
      // Apply filter
      if (_zoneFilter != null && zone.status != _zoneFilter) continue;

      if (zone.polygon.isNotEmpty) {
        _polygons.add(_createZonePolygon(zone));
      }

      // Add zone center marker
      _markers.add(_createZoneCenterMarker(zone));
    }

    // Build volunteer markers
    if (_showVolunteers) {
      for (final volunteer in provider.volunteers) {
        if (volunteer.hasLocation && volunteer.isActive) {
          _markers.add(_createVolunteerMarker(volunteer));
        }
      }
    }
  }

  Polygon _createZonePolygon(TVKZone zone) {
    final points = zone.polygon.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final color = TVKTheme.getZoneStatusColor(zone.status.value);

    return Polygon(
      polygonId: PolygonId('zone_${zone.id}'),
      points: points,
      fillColor: color.withAlpha(77), // 30% opacity
      strokeColor: color,
      strokeWidth: 2,
      consumeTapEvents: true,
      onTap: () => _onZoneTapped(zone),
    );
  }

  Marker _createZoneCenterMarker(TVKZone zone) {
    // Calculate center of polygon
    double latSum = 0, lngSum = 0;
    for (final point in zone.polygon) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    final center = LatLng(
      latSum / zone.polygon.length,
      lngSum / zone.polygon.length,
    );

    return Marker(
      markerId: MarkerId('zone_center_${zone.id}'),
      position: center,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        _getZoneMarkerHue(zone.status),
      ),
      infoWindow: InfoWindow(
        title: zone.name,
        snippet: '${zone.currentCount}/${zone.capacity} (${zone.densityPercent.toInt()}%)',
        onTap: () => _onZoneTapped(zone),
      ),
      onTap: () => _onZoneTapped(zone),
    );
  }

  double _getZoneMarkerHue(TVKZoneStatus status) {
    switch (status) {
      case TVKZoneStatus.safe:
        return BitmapDescriptor.hueGreen;
      case TVKZoneStatus.warning:
        return BitmapDescriptor.hueOrange;
      case TVKZoneStatus.danger:
        return BitmapDescriptor.hueRed;
      case TVKZoneStatus.critical:
        return BitmapDescriptor.hueViolet;
    }
  }

  Marker _createVolunteerMarker(TVKEventVolunteer volunteer) {
    return Marker(
      markerId: MarkerId('volunteer_${volunteer.odcId}'),
      position: LatLng(volunteer.latitude!, volunteer.longitude!),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        _getVolunteerMarkerHue(volunteer.role),
      ),
      infoWindow: InfoWindow(
        title: volunteer.name,
        snippet: '${volunteer.role.displayName} - ${volunteer.status.displayName}',
      ),
      alpha: volunteer.isActive ? 1.0 : 0.5,
    );
  }

  double _getVolunteerMarkerHue(TVKVolunteerRole role) {
    switch (role) {
      case TVKVolunteerRole.coordinator:
        return BitmapDescriptor.hueViolet;
      case TVKVolunteerRole.zoneCaptain:
        return BitmapDescriptor.hueYellow;
      case TVKVolunteerRole.medical:
        return BitmapDescriptor.hueGreen;
      case TVKVolunteerRole.security:
        return BitmapDescriptor.hueBlue;
      case TVKVolunteerRole.general:
        return BitmapDescriptor.hueCyan;
    }
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Density',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: TVKColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          _buildLegendItem(TVKColors.zoneSafe, 'Safe (<50%)'),
          _buildLegendItem(TVKColors.zoneWarning, 'Warning (50-80%)'),
          _buildLegendItem(TVKColors.zoneDanger, 'Danger (>80%)'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withAlpha(77),
            border: Border.all(color: color, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: TVKColors.textPrimary),
        ),
      ],
    );
  }

  void _onZoneTapped(TVKZone zone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TVKZoneDetailScreen(zone: zone),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    } else {
      final position = await LocationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() => _currentPosition = position);
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );
      }
    }
  }
}
