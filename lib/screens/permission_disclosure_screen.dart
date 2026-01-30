import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prominent disclosure screen for sensitive permissions (required by Google Play)
class PermissionDisclosureScreen extends StatelessWidget {
  final PermissionType permissionType;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const PermissionDisclosureScreen({
    super.key,
    required this.permissionType,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getPermissionConfig();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: config.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  config.icon,
                  size: 64,
                  color: config.color,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                config.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                config.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Data usage info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'How your data is used:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...config.dataUsagePoints.map((point) => Padding(
                          padding: const EdgeInsets.only(left: 28, top: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 16)),
                              Expanded(
                                child: Text(
                                  point,
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const Spacer(),
              // Accept button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    config.acceptButtonText,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Decline button
              TextButton(
                onPressed: onDecline,
                child: Text(
                  config.declineButtonText,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  _PermissionConfig _getPermissionConfig() {
    switch (permissionType) {
      case PermissionType.backgroundLocation:
        return _PermissionConfig(
          icon: Icons.location_on,
          color: Colors.red,
          title: 'Background Location Access',
          description:
              'Kaavala needs access to your location even when the app is in the background to keep you safe.',
          dataUsagePoints: [
            'Share your live location with emergency contacts during SOS',
            'Monitor your location for safety alerts when traveling',
            'Send your location to responders if you need help',
            'Your location data is never sold or shared with advertisers',
          ],
          acceptButtonText: 'Allow Background Location',
          declineButtonText: 'Not Now',
        );
      case PermissionType.sms:
        return _PermissionConfig(
          icon: Icons.sms,
          color: Colors.green,
          title: 'SMS Permission',
          description:
              'Kaavala needs SMS permission to automatically send emergency alerts to your trusted contacts when you trigger SOS.',
          dataUsagePoints: [
            'Send automatic SOS alerts with your location',
            'Alert emergency contacts without manual intervention',
            'Send check-in messages to let contacts know you\'re safe',
            'SMS is only sent when you trigger SOS or share location',
          ],
          acceptButtonText: 'Allow SMS',
          declineButtonText: 'Not Now',
        );
      case PermissionType.contacts:
        return _PermissionConfig(
          icon: Icons.contacts,
          color: Colors.blue,
          title: 'Contacts Access',
          description:
              'Kaavala needs access to your contacts to help you quickly add trusted contacts and emergency contacts.',
          dataUsagePoints: [
            'Import contacts as emergency or trusted contacts',
            'Your contacts stay on your device',
            'Contact data is never uploaded to servers',
            'Only contacts you select are used by the app',
          ],
          acceptButtonText: 'Allow Contacts Access',
          declineButtonText: 'Not Now',
        );
      case PermissionType.camera:
        return _PermissionConfig(
          icon: Icons.camera_alt,
          color: Colors.purple,
          title: 'Camera Access',
          description:
              'Kaavala may use the camera to capture photo or video evidence in emergency situations.',
          dataUsagePoints: [
            'Record video evidence during emergencies',
            'Capture photos for harassment reports',
            'Evidence is stored securely on your device',
            'You control when recordings are shared',
          ],
          acceptButtonText: 'Allow Camera',
          declineButtonText: 'Not Now',
        );
      case PermissionType.microphone:
        return _PermissionConfig(
          icon: Icons.mic,
          color: Colors.orange,
          title: 'Microphone Access',
          description:
              'Kaavala may use the microphone to record audio evidence in emergency situations.',
          dataUsagePoints: [
            'Record audio evidence during emergencies',
            'Capture audio for safety documentation',
            'Recordings are stored securely on your device',
            'You control when recordings are shared',
          ],
          acceptButtonText: 'Allow Microphone',
          declineButtonText: 'Not Now',
        );
    }
  }
}

class _PermissionConfig {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final List<String> dataUsagePoints;
  final String acceptButtonText;
  final String declineButtonText;

  _PermissionConfig({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.dataUsagePoints,
    required this.acceptButtonText,
    required this.declineButtonText,
  });
}

enum PermissionType {
  backgroundLocation,
  sms,
  contacts,
  camera,
  microphone,
}

/// Helper class to manage permission disclosures
class PermissionDisclosureManager {
  static const _prefPrefix = 'permission_disclosed_';

  /// Check if disclosure has been shown for a permission
  static Future<bool> hasShownDisclosure(PermissionType type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefPrefix${type.name}') ?? false;
  }

  /// Mark disclosure as shown
  static Future<void> markDisclosureShown(PermissionType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefPrefix${type.name}', true);
  }

  /// Show disclosure screen if not already shown, then request permission
  static Future<bool> requestWithDisclosure(
    BuildContext context,
    PermissionType type,
    Permission permission,
  ) async {
    // Check if already granted
    if (await permission.isGranted) {
      return true;
    }

    // Check if disclosure already shown
    final alreadyShown = await hasShownDisclosure(type);

    if (!alreadyShown && context.mounted) {
      // Show disclosure screen
      final accepted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PermissionDisclosureScreen(
            permissionType: type,
            onAccept: () {
              Navigator.pop(context, true);
            },
            onDecline: () {
              Navigator.pop(context, false);
            },
          ),
        ),
      );

      if (accepted != true) {
        return false;
      }

      // Mark as shown
      await markDisclosureShown(type);
    }

    // Request actual permission
    final status = await permission.request();
    return status.isGranted || status.isLimited;
  }

  /// Request background location with proper disclosure
  static Future<bool> requestBackgroundLocation(BuildContext context) async {
    // First need "when in use" location
    final whenInUse = await requestWithDisclosure(
      context,
      PermissionType.backgroundLocation,
      Permission.locationWhenInUse,
    );

    if (!whenInUse) return false;

    // Then request background (Android requires this flow)
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Request SMS permission with disclosure
  static Future<bool> requestSmsPermission(BuildContext context) async {
    return await requestWithDisclosure(
      context,
      PermissionType.sms,
      Permission.sms,
    );
  }
}
