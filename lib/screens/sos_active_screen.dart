import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firebase_service.dart';
import '../services/volunteer_service.dart';

/// Screen showing active SOS status and responding volunteers
class SOSActiveScreen extends StatefulWidget {
  const SOSActiveScreen({super.key});

  @override
  State<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends State<SOSActiveScreen> {
  final _firestore = FirebaseService.instance.firestore;
  final _volunteerService = VolunteerService();

  Stream<QuerySnapshot>? _alertsStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseService.instance.currentUser?.uid;
    if (_currentUserId != null) {
      _alertsStream = _firestore
          .collection('sosVolunteerAlerts')
          .where('senderUserId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_alertsStream == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('SOS Status'),
          backgroundColor: Colors.red,
        ),
        body: const Center(
          child: Text('Not logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Status'),
        backgroundColor: Colors.red,
        actions: [
          TextButton(
            onPressed: _cancelSOS,
            child: const Text(
              'Cancel SOS',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _alertsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNoActiveAlert();
          }

          final alertDoc = snapshot.data!.docs.first;
          final alertData = alertDoc.data() as Map<String, dynamic>;
          final alertId = alertDoc.id;

          return _buildAlertStatus(alertId, alertData);
        },
      ),
    );
  }

  Widget _buildNoActiveAlert() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Active SOS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any active SOS alerts',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertStatus(String alertId, Map<String, dynamic> data) {
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final volunteersAlerted = (data['volunteersAlerted'] as List?)?.length ?? 0;
    final respondedVolunteers = data['respondedVolunteers'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 50,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                const Text(
                  'SOS ALERT ACTIVE',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sent ${_formatTime(createdAt)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(
                      icon: Icons.people,
                      label: '$volunteersAlerted notified',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      icon: Icons.how_to_reg,
                      label: '${respondedVolunteers.length} responding',
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Responding Volunteers Section
          Row(
            children: [
              const Icon(Icons.people, color: Color(0xFFE91E63)),
              const SizedBox(width: 8),
              const Text(
                'Responding Volunteers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (respondedVolunteers.isNotEmpty)
                Text(
                  '${respondedVolunteers.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (respondedVolunteers.isEmpty)
            _buildWaitingForVolunteers()
          else
            ...respondedVolunteers.map((v) => _buildVolunteerCard(v as Map<String, dynamic>)),

          const SizedBox(height: 24),

          // Emergency Call Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _callEmergency,
              icon: const Icon(Icons.phone, size: 28),
              label: const Text(
                'Call Emergency (100)',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Mark Safe Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _markSafe(alertId),
              icon: const Icon(Icons.check_circle),
              label: const Text('I\'m Safe - Cancel Alert'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForVolunteers() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Waiting for volunteers to respond...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nearby verified volunteers have been notified',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerCard(Map<String, dynamic> volunteer) {
    final name = volunteer['volunteerName'] ?? 'Volunteer';
    final phone = volunteer['volunteerPhone'] ?? '';
    final responseType = volunteer['responseType'] ?? '';
    final respondedAt = volunteer['respondedAt'] as String?;

    IconData responseIcon;
    String responseText;
    Color responseColor;

    switch (responseType) {
      case 'onMyWay':
        responseIcon = Icons.directions_run;
        responseText = 'On their way!';
        responseColor = Colors.green;
        break;
      case 'callingEmergency':
        responseIcon = Icons.phone_in_talk;
        responseText = 'Calling emergency services';
        responseColor = Colors.orange;
        break;
      default:
        responseIcon = Icons.person;
        responseText = 'Responded';
        responseColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: responseColor.withOpacity(0.1),
                  child: Icon(responseIcon, color: responseColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(responseIcon, size: 14, color: responseColor),
                          const SizedBox(width: 4),
                          Text(
                            responseText,
                            style: TextStyle(
                              color: responseColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (responseType == 'onMyWay')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'COMING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (phone.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _callVolunteer(phone),
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _smsVolunteer(phone),
                      icon: const Icon(Icons.message, size: 18),
                      label: const Text('SMS'),
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  void _callEmergency() async {
    const url = 'tel:100';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _callVolunteer(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _smsVolunteer(String phone) async {
    final url = 'sms:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _cancelSOS() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel SOS?'),
        content: const Text('Are you sure you want to cancel the SOS alert?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markSafe(null);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _markSafe(String? alertId) async {
    try {
      // Find and resolve active alerts
      final alerts = await _firestore
          .collection('sosVolunteerAlerts')
          .where('senderUserId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      for (final doc in alerts.docs) {
        await _volunteerService.resolveSOSAlert(doc.id, 'User marked safe');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS alert cancelled. Stay safe!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
