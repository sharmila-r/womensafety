import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Permission setup screen shown after login to request necessary permissions
/// with prominent disclosures (required by Google Play)
class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen> {
  int _currentStep = 0;
  bool _isRequesting = false;

  final List<_PermissionStep> _steps = [
    _PermissionStep(
      permission: Permission.locationWhenInUse,
      icon: Icons.location_on,
      color: Colors.blue,
      title: 'Location Access',
      description: 'Kaavala needs your location to:',
      points: [
        'Share your location with emergency contacts during SOS',
        'Show your current position on the map',
        'Help nearby volunteers find you if needed',
      ],
      required: true,
    ),
    _PermissionStep(
      permission: Permission.locationAlways,
      icon: Icons.location_on,
      color: Colors.red,
      title: 'Background Location',
      description: 'For continuous safety monitoring, Kaavala needs background location to:',
      points: [
        'Send your location during SOS even when app is in background',
        'Monitor your journey and alert contacts if you stop unexpectedly',
        'Keep you protected even when using other apps',
      ],
      isBackgroundLocation: true,
      required: false,
    ),
    _PermissionStep(
      permission: Permission.notification,
      icon: Icons.notifications,
      color: Colors.orange,
      title: 'Notifications',
      description: 'Kaavala needs notification permission to:',
      points: [
        'Alert you when someone responds to your SOS',
        'Notify you of safety updates',
        'Receive emergency alerts from your contacts',
      ],
      required: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingPermissions();
  }

  Future<void> _checkExistingPermissions() async {
    // Skip steps for already granted permissions
    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      final status = await step.permission.status;
      if (status.isGranted || status.isLimited) {
        if (i == _currentStep && _currentStep < _steps.length - 1) {
          setState(() => _currentStep++);
        }
      }
    }
  }

  Future<void> _requestCurrentPermission() async {
    if (_isRequesting) return;

    setState(() => _isRequesting = true);

    final step = _steps[_currentStep];
    PermissionStatus status;

    if (step.isBackgroundLocation) {
      // For background location, first ensure we have "when in use"
      final whenInUse = await Permission.locationWhenInUse.status;
      if (!whenInUse.isGranted) {
        await Permission.locationWhenInUse.request();
      }
      status = await Permission.locationAlways.request();
    } else {
      status = await step.permission.request();
    }

    setState(() => _isRequesting = false);

    if (status.isGranted || status.isLimited || !step.required) {
      _nextStep();
    } else if (status.isPermanentlyDenied) {
      _showSettingsDialog(step);
    }
  }

  void _skipCurrentPermission() {
    if (!_steps[_currentStep].required) {
      _nextStep();
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _completeSetup();
    }
  }

  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_setup_complete', true);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showSettingsDialog(_PermissionStep step) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${step.title} Required'),
        content: Text(
          step.required
              ? 'This permission is required for the app to work properly. Please enable it in settings.'
              : 'This permission helps keep you safer. You can enable it in settings later.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (!step.required) _nextStep();
            },
            child: Text(step.required ? 'Cancel' : 'Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Progress indicator
              Row(
                children: List.generate(_steps.length, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? const Color(0xFFE91E63)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              // Step counter
              Text(
                'Step ${_currentStep + 1} of ${_steps.length}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const Spacer(),
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: step.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.icon,
                  size: 64,
                  color: step.color,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                step.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Points
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: step.color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: step.color.withOpacity(0.2)),
                ),
                child: Column(
                  children: step.points
                      .map((point) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.check_circle,
                                    color: step.color, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const Spacer(),
              // Privacy note
              Text(
                'Your data is never sold or shared with advertisers.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Allow button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _requestCurrentPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isRequesting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Allow ${step.title}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              // Skip button (only for non-required permissions)
              if (!step.required)
                TextButton(
                  onPressed: _skipCurrentPermission,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStep {
  final Permission permission;
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final List<String> points;
  final bool required;
  final bool isBackgroundLocation;

  _PermissionStep({
    required this.permission,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.points,
    this.required = false,
    this.isBackgroundLocation = false,
  });
}
