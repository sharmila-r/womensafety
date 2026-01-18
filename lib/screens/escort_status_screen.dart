import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/escort_request.dart';
import '../services/escort_request_service.dart';
import 'chat_screen.dart';

/// Screen showing the status of an escort request for users
class EscortStatusScreen extends StatefulWidget {
  final String requestId;

  const EscortStatusScreen({super.key, required this.requestId});

  @override
  State<EscortStatusScreen> createState() => _EscortStatusScreenState();
}

class _EscortStatusScreenState extends State<EscortStatusScreen> {
  final _escortService = EscortRequestService();
  GoogleMapController? _mapController;
  StreamSubscription? _locationSubscription;
  GeoPoint? _volunteerLocation;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _listenToVolunteerLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToVolunteerLocation() {
    _locationSubscription = _escortService
        .streamVolunteerLocation(widget.requestId)
        .listen((location) {
      if (mounted && location != null) {
        setState(() => _volunteerLocation = location);
        _updateMapCamera(location);
      }
    });
  }

  void _updateMapCamera(GeoPoint location) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(location.latitude, location.longitude)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escort Status'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('escortRequests')
            .doc(widget.requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Request not found'));
          }

          final request = EscortRequest.fromFirestore(snapshot.data!);
          return _buildStatusContent(request);
        },
      ),
    );
  }

  Widget _buildStatusContent(EscortRequest request) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Live Map for in-progress escorts
          if ((request.isConfirmed || request.isInProgress) &&
              request.assignedVolunteerName != null)
            _buildLiveTrackingMap(request),

          // Status Progress
          _buildStatusProgress(request),
          const SizedBox(height: 24),

          // Request Info Card
          _buildRequestInfoCard(request),
          const SizedBox(height: 16),

          // Volunteer Info Card (if assigned)
          if (request.assignedVolunteerName != null)
            _buildVolunteerCard(request),

          // Action Buttons
          const SizedBox(height: 24),
          _buildActionButtons(request),

          // Rating prompt for completed
          if (request.isCompleted && request.rating == null) ...[
            const SizedBox(height: 24),
            _buildRatingPrompt(request),
          ],

          // Rating display if already rated
          if (request.rating != null) ...[
            const SizedBox(height: 24),
            _buildRatingDisplay(request),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveTrackingMap(EscortRequest request) {
    // Initial position: volunteer location or user's request location
    final initialLat = _volunteerLocation?.latitude ?? request.latitude;
    final initialLng = _volunteerLocation?.longitude ?? request.longitude;

    final markers = <Marker>{
      // User's pickup location
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(request.latitude, request.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(
          title: 'Pickup Location',
          snippet: request.eventLocation,
        ),
      ),
    };

    // Add volunteer marker if location is available
    if (_volunteerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('volunteer'),
          position: LatLng(_volunteerLocation!.latitude, _volunteerLocation!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: request.assignedVolunteerName ?? 'Volunteer',
            snippet: 'Volunteer location',
          ),
        ),
      );
    }

    return Column(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Map Toggle Header
              InkWell(
                onTap: () => setState(() => _showMap = !_showMap),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFE91E63).withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(
                        _showMap ? Icons.map : Icons.map_outlined,
                        color: const Color(0xFFE91E63),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Live Tracking',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE91E63),
                              ),
                            ),
                            Text(
                              _volunteerLocation != null
                                  ? 'Volunteer location available'
                                  : 'Waiting for volunteer location...',
                              style: TextStyle(
                                fontSize: 12,
                                color: _volunteerLocation != null
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _showMap ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFFE91E63),
                      ),
                    ],
                  ),
                ),
              ),
              // Map
              if (_showMap)
                SizedBox(
                  height: 250,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(initialLat, initialLng),
                      zoom: 15,
                    ),
                    markers: markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatusProgress(EscortRequest request) {
    final steps = [
      _StatusStep(
        title: 'Requested',
        subtitle: _formatTime(request.createdAt),
        icon: Icons.send,
        isCompleted: true,
        isActive: request.isPending,
      ),
      _StatusStep(
        title: 'Confirmed',
        subtitle: request.confirmedAt != null
            ? _formatTime(request.confirmedAt!)
            : 'Waiting for volunteer',
        icon: Icons.check_circle,
        isCompleted: !request.isPending,
        isActive: request.isConfirmed,
      ),
      _StatusStep(
        title: 'In Progress',
        subtitle: request.isInProgress ? 'Escorting now' : 'Not started',
        icon: Icons.directions_walk,
        isCompleted: request.isInProgress || request.isCompleted,
        isActive: request.isInProgress,
      ),
      _StatusStep(
        title: 'Completed',
        subtitle: request.completedAt != null
            ? _formatTime(request.completedAt!)
            : '',
        icon: Icons.done_all,
        isCompleted: request.isCompleted,
        isActive: request.isCompleted,
      ),
    ];

    if (request.isCancelled) {
      return Card(
        color: Colors.red.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.cancel, color: Colors.red, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Cancelled',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.red,
                      ),
                    ),
                    if (request.cancellationReason != null)
                      Text(
                        request.cancellationReason!,
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              _buildStepRow(steps[i]),
              if (i < steps.length - 1)
                Container(
                  margin: const EdgeInsets.only(left: 20),
                  height: 30,
                  width: 2,
                  color: steps[i].isCompleted
                      ? const Color(0xFFE91E63)
                      : Colors.grey[300],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(_StatusStep step) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: step.isCompleted
                ? const Color(0xFFE91E63)
                : (step.isActive ? Colors.orange : Colors.grey[300]),
          ),
          child: Icon(
            step.icon,
            color: step.isCompleted || step.isActive ? Colors.white : Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: step.isCompleted || step.isActive
                      ? Colors.black
                      : Colors.grey,
                ),
              ),
              if (step.subtitle.isNotEmpty)
                Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: step.isActive ? Colors.orange : Colors.grey,
                  ),
                ),
            ],
          ),
        ),
        if (step.isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'CURRENT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRequestInfoCard(EscortRequest request) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.eventName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.eventLocation,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(request.eventDateTime),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            if (request.notes != null && request.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.notes!,
                      style: const TextStyle(color: Colors.grey),
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

  Widget _buildVolunteerCard(EscortRequest request) {
    return Card(
      color: Colors.green.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Volunteer',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
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
                        request.assignedVolunteerName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.verified, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Verified Volunteer',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Call button
                if (request.assignedVolunteerPhone != null)
                  IconButton(
                    onPressed: () => _callVolunteer(request.assignedVolunteerPhone!),
                    icon: const Icon(Icons.call, color: Colors.green),
                    tooltip: 'Call volunteer',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(EscortRequest request) {
    return Column(
      children: [
        // Chat button
        if (request.chatId != null && !request.isCompleted && !request.isCancelled)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatId: request.chatId!,
                      otherUserName: request.assignedVolunteerName ?? 'Volunteer',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('Chat with Volunteer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

        // Cancel button for pending/confirmed
        if (request.isPending || request.isConfirmed) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _cancelRequest(request),
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text(
                'Cancel Request',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRatingPrompt(EscortRequest request) {
    return Card(
      color: Colors.amber.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 40),
            const SizedBox(height: 8),
            const Text(
              'How was your experience?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Rate your volunteer to help others',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showRatingDialog(request),
              icon: const Icon(Icons.star),
              label: const Text('Rate Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingDisplay(EscortRequest request) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 32),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You rated: ${request.rating!.toStringAsFixed(1)}/5',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (request.review != null)
                  Text(
                    request.review!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelRequest(EscortRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text('Are you sure you want to cancel this escort request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _escortService.cancelRequest(request.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request cancelled')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _callVolunteer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _showRatingDialog(EscortRequest request) async {
    double rating = 5;
    final reviewController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate Your Experience'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How was your escort with ${request.assignedVolunteerName}?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () {
                      setDialogState(() => rating = index + 1.0);
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(
                  labelText: 'Review (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _escortService.rateEscort(
                    requestId: request.id,
                    rating: rating,
                    review: reviewController.text.isEmpty
                        ? null
                        : reviewController.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thank you for your feedback!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return 'Today at ${_formatTime(dateTime)}';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${_formatTime(dateTime)}';
  }
}

class _StatusStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCompleted;
  final bool isActive;

  _StatusStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
    required this.isActive,
  });
}
