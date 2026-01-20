import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/sms_service.dart';
import '../services/auth_service.dart';
import '../services/volunteer_service.dart';
import '../services/chat_service.dart';
import '../models/volunteer.dart';
import 'tracking_screen.dart';
import 'recording_screen.dart';
import 'recordings_screen.dart';
import 'fake_call_screen.dart';
import 'escort_tracking_screen.dart';
import 'chat_list_screen.dart';
import 'volunteer/volunteer_dashboard_screen.dart';
import 'nearby_volunteers_screen.dart';
import 'sos_active_screen.dart';
import '../services/evidence_recording_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final AuthService _authService = AuthService();
  final VolunteerService _volunteerService = VolunteerService();
  final ChatService _chatService = ChatService();

  Volunteer? _volunteer;
  bool _isCheckingVolunteer = true;
  int _unreadMessages = 0;
  bool? _showVolunteerView; // null = not set yet, defaults to true for volunteers

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkVolunteerStatus();
    _listenToUnreadMessages();
  }

  void _listenToUnreadMessages() {
    _chatService.getTotalUnreadCount().listen((count) {
      if (mounted) {
        setState(() => _unreadMessages = count);
      }
    });
  }

  Future<void> _checkVolunteerStatus() async {
    try {
      final volunteer = await _volunteerService.getCurrentVolunteer();
      if (mounted) {
        setState(() {
          _volunteer = volunteer;
          _isCheckingVolunteer = false;
          // Default to volunteer dashboard view if user is a volunteer
          if (volunteer != null && _showVolunteerView == null) {
            _showVolunteerView = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingVolunteer = false);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If volunteer and showing volunteer view, display dashboard
    if (_volunteer != null && _showVolunteerView == true) {
      return WillPopScope(
        onWillPop: () async {
          setState(() => _showVolunteerView = false);
          return false; // Don't pop, just switch view
        },
        child: Stack(
          children: [
            const VolunteerDashboardScreen(),
            // Floating button to switch back to user view
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: () => setState(() => _showVolunteerView = false),
                backgroundColor: const Color(0xFFE91E63),
                icon: const Icon(Icons.home),
                label: const Text('User View'),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE91E63), Color(0xFFFCE4EC)],
          ),
        ),
        child: SafeArea(
          child: Consumer<AppProvider>(
            builder: (context, provider, child) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kaavala',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Your Safety, Our Priority',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            // Debug: Show phone number
                            if (_authService.currentUser?.phoneNumber != null)
                              Text(
                                _authService.currentUser!.phoneNumber!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            // Messages Button
                            Stack(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ChatListScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.chat_bubble_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  tooltip: 'Messages',
                                ),
                                if (_unreadMessages > 0)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: Text(
                                        _unreadMessages > 9 ? '9+' : _unreadMessages.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            // Volunteer Dashboard Toggle Button
                            if (_volunteer != null)
                              IconButton(
                                onPressed: () => setState(() => _showVolunteerView = true),
                                icon: const Icon(
                                  Icons.volunteer_activism,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                tooltip: 'Switch to Volunteer View',
                              ),
                            IconButton(
                              onPressed: () {
                                // Call emergency
                                _showEmergencyDialog(context, provider);
                              },
                              icon: const Icon(
                                Icons.phone,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Volunteer Status Card (if volunteer)
                  if (_volunteer != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () => setState(() => _showVolunteerView = true),
                        child: Card(
                          color: _volunteer!.verificationLevel == VerificationLevel.backgroundChecked
                              ? Colors.green.shade50
                              : Colors.amber.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.volunteer_activism,
                                  color: _volunteer!.verificationLevel == VerificationLevel.backgroundChecked
                                      ? Colors.green
                                      : Colors.amber.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Volunteer: ${_volunteer!.name}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Tap to open Volunteer Dashboard',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _volunteer!.verificationLevel == VerificationLevel.backgroundChecked
                                              ? Colors.green
                                              : Colors.amber.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.toggle_on, size: 24, color: Color(0xFFE91E63)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_volunteer != null) const SizedBox(height: 8),

                  // Location Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xFFE91E63),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Location',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    provider.currentAddress.isNotEmpty
                                        ? provider.currentAddress
                                        : 'Fetching location...',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => provider.updateCurrentLocation(),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SOS Button
                  GestureDetector(
                    onLongPress: () {
                      _triggerSOS(context, provider);
                    },
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: provider.isSOSActive ? 1.0 : _pulseAnimation.value,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: provider.isSOSActive
                                  ? Colors.red
                                  : const Color(0xFFE91E63),
                              boxShadow: [
                                BoxShadow(
                                  color: (provider.isSOSActive
                                          ? Colors.red
                                          : const Color(0xFFE91E63))
                                      .withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  provider.isSOSActive
                                      ? Icons.warning
                                      : Icons.touch_app,
                                  size: 50,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  provider.isSOSActive ? 'SOS ACTIVE' : 'SOS',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (!provider.isSOSActive)
                                  const Text(
                                    'Long press to activate',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (provider.isSOSActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SOSActiveScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFE91E63),
                            ),
                            icon: const Icon(Icons.people),
                            label: const Text('View Responding Volunteers'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => provider.deactivateSOS(),
                            child: const Text(
                              'Deactivate SOS',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Quick Actions - Row 1
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickAction(
                          icon: Icons.share_location,
                          label: 'Share\nLocation',
                          onTap: () {
                            if (provider.trustedContacts.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Please add trusted contacts first'),
                                  action: SnackBarAction(
                                    label: 'Add',
                                    onPressed: () => Navigator.pushNamed(context, '/contacts'),
                                  ),
                                ),
                              );
                            } else {
                              provider.shareCurrentLocation();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Location shared with trusted contacts')),
                              );
                            }
                          },
                          isActive: provider.isLocationSharing,
                        ),
                        _buildQuickAction(
                          icon: Icons.directions_walk,
                          label: 'Safe\nJourney',
                          onTap: () => _startSafeJourney(context),
                        ),
                        _buildQuickAction(
                          icon: Icons.call,
                          label: 'Call\n${provider.emergencyNumber}',
                          onTap: () => _showEmergencyDialog(context, provider),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quick Actions - Row 2 (Recording, Fake Call)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickAction(
                          icon: provider.isRecording ? Icons.stop : Icons.mic,
                          label: provider.isRecording ? 'Stop\nRecording' : 'Record\nAudio',
                          onTap: () => _handleRecording(context, provider),
                          isActive: provider.isRecording,
                        ),
                        _buildQuickAction(
                          icon: Icons.videocam,
                          label: 'Record\nVideo',
                          onTap: () => _openVideoRecording(context),
                        ),
                        _buildQuickAction(
                          icon: Icons.phone_callback,
                          label: 'Fake\nCall',
                          onTap: () => _showFakeCallScheduler(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quick Actions - Row 3 (Nearby Volunteers, Recordings)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickAction(
                          icon: Icons.people,
                          label: 'Nearby\nVolunteers',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NearbyVolunteersScreen(),
                            ),
                          ),
                        ),
                        _buildQuickAction(
                          icon: Icons.folder,
                          label: 'My\nRecordings',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RecordingsScreen(),
                            ),
                          ),
                        ),
                        _buildQuickAction(
                          icon: Icons.map,
                          label: 'Safety\nMap',
                          onTap: () => _showComingSoon(context, 'Safety Map'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Status Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              provider.emergencyContacts.isNotEmpty
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: provider.emergencyContacts.isNotEmpty
                                  ? Colors.green
                                  : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${provider.emergencyContacts.length} Emergency Contacts',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              provider.autoAlertEnabled
                                  ? Icons.notifications_active
                                  : Icons.notifications_off,
                              color: provider.autoAlertEnabled
                                  ? Colors.green
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              provider.autoAlertEnabled
                                  ? 'Auto-Alert ON'
                                  : 'Auto-Alert OFF',
                              style: TextStyle(
                                fontSize: 12,
                                color: provider.autoAlertEnabled
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE91E63) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFFE91E63),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerSOS(BuildContext context, AppProvider provider) {
    final hasContacts = provider.emergencyContacts.isNotEmpty;
    final alertVolunteers = provider.alertNearbyVolunteers;

    // Block only if no emergency contacts AND not alerting volunteers
    if (!hasContacts && !alertVolunteers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add emergency contacts or enable "Alert Nearby Volunteers" in Settings'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Build message based on who will be alerted
    String alertMessage;
    if (hasContacts && alertVolunteers) {
      alertMessage = 'This will send your location to emergency contacts and nearby volunteers. Continue?';
    } else if (hasContacts) {
      alertMessage = 'This will send your location to all emergency contacts. Continue?';
    } else {
      alertMessage = 'This will alert nearby verified volunteers. Continue?';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm SOS'),
          ],
        ),
        content: Text(alertMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.triggerSOS();

              // Show appropriate confirmation message
              String confirmMsg;
              if (hasContacts && alertVolunteers) {
                confirmMsg = 'SOS Alert sent to contacts and nearby volunteers!';
              } else if (hasContacts) {
                confirmMsg = 'SOS Alert sent to emergency contacts!';
              } else {
                confirmMsg = 'SOS Alert sent to nearby volunteers!';
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(confirmMsg),
                    backgroundColor: Colors.red,
                  ),
                );

                // Open SOS status screen if alerting volunteers
                if (alertVolunteers) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SOSActiveScreen(),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context, AppProvider provider) {
    final emergencyNumber = provider.emergencyNumber;
    final countryName = provider.countryName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Call'),
        content: Text('Call $emergencyNumber ($countryName emergency)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SmsService.callEmergencyNumber();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Call $emergencyNumber'),
          ),
        ],
      ),
    );
  }

  /// Handle audio recording toggle
  Future<void> _handleRecording(BuildContext context, AppProvider provider) async {
    if (provider.isRecording) {
      final recording = await provider.stopAudioRecording();
      if (recording != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording saved (${recording.duration?.inSeconds ?? 0}s)'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RecordingsScreen()),
                );
              },
            ),
          ),
        );
      }
    } else {
      final success = await provider.startAudioRecording();
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start recording. Check microphone permission.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Open video recording screen
  void _openVideoRecording(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecordingScreen(
          initialType: RecordingType.video,
        ),
      ),
    );
  }

  /// Show fake call scheduler
  void _showFakeCallScheduler(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const FakeCallScheduler(),
    );
  }

  /// Show coming soon dialog
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Start safe journey with destination input
  void _startSafeJourney(BuildContext context) {
    final destinationController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Safe Journey',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your live location with trusted contacts while traveling',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: 'Where are you going? (optional)',
                hintText: 'e.g., Home, Office, Mall',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EscortTrackingScreen(
                        destination: destinationController.text.isNotEmpty
                            ? destinationController.text
                            : null,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Safe Journey'),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Your contacts will receive SMS with live tracking link',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
