import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/volunteer_service.dart';

/// Screen for volunteers to respond to SOS alerts
class SOSResponseScreen extends StatefulWidget {
  final String alertId;
  final String senderName;
  final String senderPhone;
  final double latitude;
  final double longitude;
  final String address;
  final String? message;

  const SOSResponseScreen({
    super.key,
    required this.alertId,
    required this.senderName,
    required this.senderPhone,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.message,
  });

  @override
  State<SOSResponseScreen> createState() => _SOSResponseScreenState();
}

class _SOSResponseScreenState extends State<SOSResponseScreen> {
  final VolunteerService _volunteerService = VolunteerService();
  bool _isResponding = false;
  bool _hasResponded = false;
  SOSResponseType? _responseType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Alert'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert Header
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
                    size: 60,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SOMEONE NEEDS HELP!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.senderName} has triggered an SOS alert',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Location Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.address,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openMaps,
                        icon: const Icon(Icons.directions),
                        label: const Text('Open in Maps'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Contact Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person, color: Color(0xFFE91E63)),
                        SizedBox(width: 8),
                        Text(
                          'Person in Need',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.senderName,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.senderPhone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _callPerson,
                            icon: const Icon(Icons.call),
                            label: const Text('Call'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _sendSMS,
                            icon: const Icon(Icons.message),
                            label: const Text('SMS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (widget.message != null && widget.message!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.chat, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'Message',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(widget.message!),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Response Buttons
            if (!_hasResponded) ...[
              const Text(
                'How would you like to respond?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // On My Way Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isResponding ? null : () => _respond(SOSResponseType.onMyWay),
                  icon: const Icon(Icons.directions_run, size: 28),
                  label: const Text(
                    'I\'M ON MY WAY',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Calling Emergency Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isResponding ? null : () => _respond(SOSResponseType.callingEmergency),
                  icon: const Icon(Icons.phone_in_talk),
                  label: const Text('I\'ll Call Emergency Services'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cannot Respond Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isResponding ? null : () => _respond(SOSResponseType.cannotRespond),
                  child: const Text(
                    'I Cannot Respond Right Now',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ] else ...[
              // Response Confirmation
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 48,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getResponseMessage(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The person has been notified of your response',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            if (_isResponding)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getResponseMessage() {
    switch (_responseType) {
      case SOSResponseType.onMyWay:
        return 'You\'re on your way to help!';
      case SOSResponseType.callingEmergency:
        return 'You\'re calling emergency services';
      case SOSResponseType.cannotRespond:
        return 'Response recorded';
      default:
        return 'Response sent';
    }
  }

  Future<void> _respond(SOSResponseType type) async {
    setState(() {
      _isResponding = true;
      _responseType = type;
    });

    try {
      await _volunteerService.respondToSOSAlert(
        alertId: widget.alertId,
        responseType: type,
      );

      setState(() {
        _isResponding = false;
        _hasResponded = true;
      });

      if (type == SOSResponseType.onMyWay) {
        // Open maps to navigate
        _openMaps();
      }
    } catch (e) {
      setState(() => _isResponding = false);
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

  void _openMaps() async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _callPerson() async {
    final url = 'tel:${widget.senderPhone}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _sendSMS() async {
    final url = 'sms:${widget.senderPhone}?body=I received your SOS alert and I\'m coming to help!';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}
