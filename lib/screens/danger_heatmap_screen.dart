import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/heatmap_service.dart';
import '../services/location_service.dart';

class DangerHeatmapScreen extends StatefulWidget {
  const DangerHeatmapScreen({super.key});

  @override
  State<DangerHeatmapScreen> createState() => _DangerHeatmapScreenState();
}

class _DangerHeatmapScreenState extends State<DangerHeatmapScreen> {
  final HeatmapService _heatmapService = HeatmapService();

  GoogleMapController? _mapController;
  Position? _currentPosition;
  List<DangerCluster> _clusters = [];
  Map<String, dynamic>? _cityStats;
  bool _isLoading = true;
  Set<Circle> _heatmapCircles = {};
  Set<Marker> _markers = {};
  bool _showMarkers = true;
  double _currentRadius = 5.0;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    // Get current location
    final position = await LocationService.getCurrentLocation();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get current location'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      // Default to a central location if no permission
      setState(() {
        _currentPosition = Position(
          latitude: 28.6139,
          longitude: 77.2090,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        _isLoading = false;
      });
      return;
    }

    setState(() => _currentPosition = position);
    await _loadHeatmapData();
  }

  Future<void> _loadHeatmapData() async {
    if (_currentPosition == null) return;

    setState(() => _isLoading = true);

    try {
      // Load danger clusters
      final clusters = await _heatmapService.getDangerClusters(
        centerLat: _currentPosition!.latitude,
        centerLng: _currentPosition!.longitude,
        radiusKm: _currentRadius,
      );

      // Load city stats
      final stats = await _heatmapService.getCityStats(
        centerLat: _currentPosition!.latitude,
        centerLng: _currentPosition!.longitude,
        radiusKm: _currentRadius * 2,
      );

      setState(() {
        _clusters = clusters;
        _cityStats = stats;
        _updateMapOverlays();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateMapOverlays() {
    // Create circles for heatmap visualization
    final circles = <Circle>{};
    final markers = <Marker>{};

    for (final cluster in _clusters) {
      // Calculate circle radius based on report count
      final radius = 50.0 + (cluster.reportCount * 5).clamp(0, 150).toDouble();

      // Heatmap circle
      circles.add(Circle(
        circleId: CircleId('heat_${cluster.latitude}_${cluster.longitude}'),
        center: cluster.latLng,
        radius: radius,
        fillColor: _getSeverityColor(cluster.severity).withOpacity(0.3),
        strokeColor: _getSeverityColor(cluster.severity).withOpacity(0.7),
        strokeWidth: 2,
      ));

      // Info marker
      if (_showMarkers) {
        markers.add(Marker(
          markerId: MarkerId('marker_${cluster.latitude}_${cluster.longitude}'),
          position: cluster.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(cluster.hue),
          infoWindow: InfoWindow(
            title: '${cluster.severity.toUpperCase()} Risk Zone',
            snippet: '${cluster.reportCount} incidents reported',
          ),
          onTap: () => _showClusterDetails(cluster),
        ));
      }
    }

    setState(() {
      _heatmapCircles = circles;
      _markers = markers;
    });
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.yellow;
    }
  }

  void _showClusterDetails(DangerCluster cluster) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(cluster.severity).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${cluster.severity.toUpperCase()} RISK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getSeverityColor(cluster.severity),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                _buildStatItem(
                  Icons.warning_amber,
                  '${cluster.reportCount}',
                  'Incidents',
                  Colors.red,
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  Icons.show_chart,
                  '${(cluster.intensity * 100).round()}%',
                  'Intensity',
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Incident types
            if (cluster.incidentTypes.isNotEmpty) ...[
              const Text(
                'Incident Types',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cluster.incidentTypes.map((type) => Chip(
                  label: Text(type),
                  backgroundColor: Colors.grey[200],
                )).toList(),
              ),
            ],
            const SizedBox(height: 16),

            // Last reported
            if (cluster.lastReportedAt != null)
              Text(
                'Last reported: ${_formatDate(cluster.lastReportedAt!)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),

            const SizedBox(height: 16),

            // Safety tip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getSafetyTip(cluster.severity),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).round()} weeks ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getSafetyTip(String severity) {
    switch (severity) {
      case 'high':
        return 'Avoid this area if possible, especially after dark. If you must pass through, stay on well-lit main roads and keep your phone ready.';
      case 'medium':
        return 'Be extra vigilant in this area. Keep your phone accessible and consider sharing your live location with a trusted contact.';
      default:
        return 'Stay aware of your surroundings. Trust your instincts and don\'t hesitate to seek help if you feel unsafe.';
    }
  }

  void _showStatsDialog() {
    if (_cityStats == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Color(0xFFE91E63)),
            SizedBox(width: 8),
            Text('Area Statistics'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsRow('Total Incidents', '${_cityStats!['totalIncidents']}'),
            _buildStatsRow('Danger Zones', '${_cityStats!['totalZones']}'),
            _buildStatsRow('High Risk', '${_cityStats!['highRiskZones']} zones', Colors.red),
            _buildStatsRow('Medium Risk', '${_cityStats!['mediumRiskZones']} zones', Colors.orange),
            const Divider(height: 24),
            const Text(
              'Incident Types:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...(_cityStats!['incidentTypes'] as Map<String, int>).entries.map(
              (e) => _buildStatsRow(e.key, '${e.value}'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danger Zones'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showMarkers ? Icons.place : Icons.place_outlined),
            onPressed: () {
              setState(() {
                _showMarkers = !_showMarkers;
                _updateMapOverlays();
              });
            },
            tooltip: _showMarkers ? 'Hide markers' : 'Show markers',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showStatsDialog,
            tooltip: 'View statistics',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHeatmapData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          if (_currentPosition != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 14,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              circles: _heatmapCircles,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onCameraMove: (position) {
                // Could trigger reload on significant camera movement
              },
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 16),
                        Text('Loading danger zones...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Legend
          Positioned(
            bottom: 100,
            left: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Risk Level',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(Colors.red, 'High'),
                    _buildLegendItem(Colors.orange, 'Medium'),
                    _buildLegendItem(Colors.yellow, 'Low'),
                  ],
                ),
              ),
            ),
          ),

          // Radius selector
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('Radius:'),
                    Expanded(
                      child: Slider(
                        value: _currentRadius,
                        min: 1,
                        max: 20,
                        divisions: 19,
                        label: '${_currentRadius.round()} km',
                        onChanged: (value) {
                          setState(() => _currentRadius = value);
                        },
                        onChangeEnd: (value) {
                          _loadHeatmapData();
                        },
                      ),
                    ),
                    Text('${_currentRadius.round()} km'),
                  ],
                ),
              ),
            ),
          ),

          // Quick stats banner
          if (_clusters.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat(
                        '${_clusters.length}',
                        'Zones',
                        Icons.location_on,
                      ),
                      _buildQuickStat(
                        '${_clusters.where((c) => c.severity == 'high').length}',
                        'High Risk',
                        Icons.warning,
                        Colors.red,
                      ),
                      _buildQuickStat(
                        '${_clusters.fold<int>(0, (sum, c) => sum + c.reportCount)}',
                        'Incidents',
                        Icons.report,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              border: Border.all(color: color, width: 2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String value, String label, IconData icon, [Color? color]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color ?? Colors.grey[600], size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
