import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/volunteer.dart';
import '../../models/escort_request.dart';
import '../../services/volunteer_service.dart';
import '../../services/location_service.dart';

class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  State<VolunteerDashboardScreen> createState() =>
      _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends State<VolunteerDashboardScreen> {
  final _volunteerService = VolunteerService();

  Volunteer? _volunteer;
  List<EscortRequest> _nearbyRequests = [];
  bool _isLoading = true;
  bool _isOnline = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _volunteer = await _volunteerService.getCurrentVolunteer();
      _currentPosition = await LocationService.getCurrentLocation();

      if (_volunteer != null) {
        _isOnline = _volunteer!.availabilityStatus == AvailabilityStatus.available;

        if (_isOnline && _currentPosition != null) {
          _nearbyRequests = await _volunteerService.getNearbyRequests(
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            radiusKm: _volunteer!.serviceRadiusKm,
          );
        }
      }
    } catch (e) {
      _showError(e.toString());
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Volunteer Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_volunteer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Volunteer Dashboard')),
        body: const Center(child: Text('Not registered as volunteer')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 16),

            // Verification Status
            _buildVerificationCard(),
            const SizedBox(height: 16),

            // Stats
            _buildStatsRow(),
            const SizedBox(height: 24),

            // Online Toggle
            _buildOnlineToggle(),
            const SizedBox(height: 24),

            // Nearby Requests
            if (_isOnline) ...[
              const Text(
                'Nearby Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_nearbyRequests.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No requests nearby',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const Text(
                          'We\'ll notify you when someone needs help',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._nearbyRequests.map((request) => _buildRequestCard(request)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: _isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: _isOnline ? Colors.green : Colors.grey,
              child: _volunteer!.photoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        _volunteer!.photoUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      _volunteer!.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _volunteer!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: _isOnline ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildVerificationBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadge() {
    Color color;
    IconData icon;

    switch (_volunteer!.verificationLevel) {
      case VerificationLevel.trusted:
        color = Colors.purple;
        icon = Icons.workspace_premium;
        break;
      case VerificationLevel.backgroundChecked:
        color = Colors.green;
        icon = Icons.verified;
        break;
      case VerificationLevel.idVerified:
        color = Colors.blue;
        icon = Icons.badge;
        break;
      case VerificationLevel.phoneVerified:
        color = Colors.orange;
        icon = Icons.phone_android;
        break;
      default:
        color = Colors.grey;
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            _volunteer!.verificationBadge,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard() {
    if (_volunteer!.isFullyVerified) return const SizedBox.shrink();

    String message;
    String action;
    Color color;

    switch (_volunteer!.verificationLevel) {
      case VerificationLevel.phoneVerified:
        message = 'Upload your ID to get verified';
        action = 'Upload ID';
        color = Colors.orange;
        break;
      case VerificationLevel.idVerified:
        if (_volunteer!.backgroundCheckStatus == 'pending') {
          message = 'Background check in progress';
          action = 'Check Status';
          color = Colors.blue;
        } else {
          message = 'Complete background check to accept requests';
          action = 'Start Check';
          color = Colors.orange;
        }
        break;
      default:
        message = 'Complete verification to become a volunteer';
        action = 'Get Verified';
        color = Colors.red;
    }

    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
            TextButton(
              onPressed: () {
                // Navigate to verification screen
              },
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.directions_walk,
            value: '${_volunteer!.totalEscorts}',
            label: 'Escorts',
            color: const Color(0xFFE91E63),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.star,
            value: _volunteer!.averageRating.toStringAsFixed(1),
            label: '${_volunteer!.ratingCount} ratings',
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.location_on,
            value: '${_volunteer!.serviceRadiusKm.toInt()}',
            label: 'km radius',
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineToggle() {
    final canGoOnline = _volunteer!.isFullyVerified;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Availability',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        canGoOnline
                            ? 'Toggle to accept escort requests'
                            : 'Complete verification to go online',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isOnline,
                  onChanged: canGoOnline ? _toggleOnlineStatus : null,
                  activeColor: Colors.green,
                ),
              ],
            ),
            if (_isOnline) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: () => _showRadiusDialog(),
                    icon: const Icon(Icons.tune),
                    label: Text('${_volunteer!.serviceRadiusKm.toInt()} km'),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.schedule),
                    label: const Text('Schedule'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(EscortRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE91E63),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.eventName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDateTime(request.eventDateTime),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _calculateDistance(request),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.eventLocation,
                    style: TextStyle(color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (request.notes != null && request.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.notes!,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewRequestDetails(request),
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return 'Today at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.day}/${dateTime.month} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _calculateDistance(EscortRequest request) {
    if (_currentPosition == null) return '--';
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      request.latitude,
      request.longitude,
    );
    if (distance < 1000) {
      return '${distance.toInt()}m away';
    }
    return '${(distance / 1000).toStringAsFixed(1)}km away';
  }

  void _toggleOnlineStatus(bool value) async {
    setState(() => _isOnline = value);
    try {
      await _volunteerService.setOnlineStatus(value);
      if (value && _currentPosition != null) {
        await _volunteerService.updateLocation(_currentPosition!);
        _nearbyRequests = await _volunteerService.getNearbyRequests(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );
        setState(() {});
      }
    } catch (e) {
      _showError(e.toString());
      setState(() => _isOnline = !value);
    }
  }

  void _showRadiusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Service Radius'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 15, 20, 25].map((km) {
            return ListTile(
              title: Text('$km km'),
              trailing: _volunteer!.serviceRadiusKm == km
                  ? const Icon(Icons.check, color: Color(0xFFE91E63))
                  : null,
              onTap: () async {
                Navigator.pop(context);
                await _volunteerService.updateAvailability(
                  status: _volunteer!.availabilityStatus,
                  isAcceptingRequests: _volunteer!.isAcceptingRequests,
                  serviceRadiusKm: km.toDouble(),
                );
                _loadData();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    // Show volunteer settings
  }

  void _viewRequestDetails(EscortRequest request) {
    // Navigate to request details
  }

  void _acceptRequest(EscortRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Request?'),
        content: Text(
          'You will be assigned to escort for "${request.eventName}". The user will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _volunteerService.acceptEscortRequest(request.id);
        _showSuccess('Request accepted! Contact the user to coordinate.');
        _loadData();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}
