import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/volunteer.dart';
import '../services/volunteer_service.dart';
import '../services/location_service.dart';
import 'volunteer_profile_screen.dart';

/// Screen showing nearby available volunteers
class NearbyVolunteersScreen extends StatefulWidget {
  const NearbyVolunteersScreen({super.key});

  @override
  State<NearbyVolunteersScreen> createState() => _NearbyVolunteersScreenState();
}

class _NearbyVolunteersScreenState extends State<NearbyVolunteersScreen> {
  final _volunteerService = VolunteerService();

  List<Volunteer> _volunteers = [];
  bool _isLoading = true;
  Position? _currentPosition;
  double _searchRadius = 10; // km

  @override
  void initState() {
    super.initState();
    _loadVolunteers();
  }

  Future<void> _loadVolunteers() async {
    setState(() => _isLoading = true);

    try {
      _currentPosition = await LocationService.getCurrentLocation();

      if (_currentPosition != null) {
        _volunteers = await _volunteerService.findNearbyVolunteers(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          radiusKm: _searchRadius,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Volunteers'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showRadiusFilter,
            tooltip: 'Filter radius',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVolunteers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _volunteers.isEmpty
              ? _buildEmptyState()
              : _buildVolunteerList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No volunteers nearby',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No verified volunteers are currently available within ${_searchRadius.toInt()} km',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showRadiusFilter,
              icon: const Icon(Icons.expand),
              label: const Text('Expand Search Radius'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerList() {
    return Column(
      children: [
        // Header with count
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE91E63).withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.people, color: Color(0xFFE91E63)),
              const SizedBox(width: 8),
              Text(
                '${_volunteers.length} volunteer${_volunteers.length == 1 ? '' : 's'} within ${_searchRadius.toInt()} km',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadVolunteers,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _volunteers.length,
              itemBuilder: (context, index) {
                return _buildVolunteerCard(_volunteers[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVolunteerCard(Volunteer volunteer) {
    final distance = _calculateDistance(volunteer);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewVolunteerProfile(volunteer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: _getVerificationColor(volunteer.verificationLevel),
                backgroundImage: volunteer.photoUrl != null
                    ? NetworkImage(volunteer.photoUrl!)
                    : null,
                child: volunteer.photoUrl == null
                    ? Text(
                        volunteer.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            volunteer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _buildVerificationBadge(volunteer),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Rating
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          volunteer.averageRating > 0
                              ? '${volunteer.averageRating.toStringAsFixed(1)} (${volunteer.ratingCount})'
                              : 'New',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.directions_walk, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${volunteer.totalEscorts} escorts',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Distance
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Color(0xFFE91E63)),
                        const SizedBox(width: 4),
                        Text(
                          distance,
                          style: const TextStyle(
                            color: Color(0xFFE91E63),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Bio
                    if (volunteer.bio != null && volunteer.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        volunteer.bio!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(Volunteer volunteer) {
    Color color;
    IconData icon;
    String label;

    switch (volunteer.verificationLevel) {
      case VerificationLevel.trusted:
        color = Colors.purple;
        icon = Icons.workspace_premium;
        label = 'Trusted';
        break;
      case VerificationLevel.backgroundChecked:
        color = Colors.green;
        icon = Icons.verified;
        label = 'Verified';
        break;
      case VerificationLevel.idVerified:
        color = Colors.blue;
        icon = Icons.badge;
        label = 'ID Verified';
        break;
      default:
        color = Colors.grey;
        icon = Icons.pending;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getVerificationColor(VerificationLevel level) {
    switch (level) {
      case VerificationLevel.trusted:
        return Colors.purple;
      case VerificationLevel.backgroundChecked:
        return Colors.green;
      case VerificationLevel.idVerified:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _calculateDistance(Volunteer volunteer) {
    if (_currentPosition == null || volunteer.currentLocation == null) {
      return 'Unknown';
    }

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      volunteer.currentLocation!.latitude,
      volunteer.currentLocation!.longitude,
    );

    if (distance < 1000) {
      return '${distance.toInt()} m away';
    }
    return '${(distance / 1000).toStringAsFixed(1)} km away';
  }

  void _viewVolunteerProfile(Volunteer volunteer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VolunteerProfileScreen(volunteer: volunteer),
      ),
    );
  }

  void _showRadiusFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Radius'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5.0, 10.0, 15.0, 25.0, 50.0].map((radius) {
            return ListTile(
              title: Text('${radius.toInt()} km'),
              trailing: _searchRadius == radius
                  ? const Icon(Icons.check, color: Color(0xFFE91E63))
                  : null,
              onTap: () {
                Navigator.pop(context);
                setState(() => _searchRadius = radius);
                _loadVolunteers();
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
