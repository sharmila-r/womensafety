import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Safety Features Section
              const Text(
                'Safety Features',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 16),

              // Auto-Alert Toggle
              Card(
                child: SwitchListTile(
                  title: const Text('Auto-Alert'),
                  subtitle: const Text(
                    'Automatically send SOS if phone is stationary for too long',
                  ),
                  value: provider.autoAlertEnabled,
                  onChanged: (value) => provider.setAutoAlertEnabled(value),
                  activeColor: const Color(0xFFE91E63),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: provider.autoAlertEnabled
                          ? const Color(0xFFE91E63).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.timer,
                      color: provider.autoAlertEnabled
                          ? const Color(0xFFE91E63)
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Stationary Alert Time
              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.access_time,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                  title: const Text('Stationary Alert Time'),
                  subtitle: Text(
                    '${provider.stationaryAlertMinutes} minutes',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTimePickerDialog(context, provider),
                ),
              ),

              const SizedBox(height: 24),

              // Notifications Section
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('SOS Alerts'),
                      subtitle: const Text('Receive SOS confirmation'),
                      value: true,
                      onChanged: (value) {},
                      activeColor: const Color(0xFFE91E63),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Location Updates'),
                      subtitle: const Text('Updates when sharing location'),
                      value: true,
                      onChanged: (value) {},
                      activeColor: const Color(0xFFE91E63),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Escort Notifications'),
                      subtitle: const Text('Updates on escort requests'),
                      value: true,
                      onChanged: (value) {},
                      activeColor: const Color(0xFFE91E63),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Privacy Section
              const Text(
                'Privacy & Security',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.lock,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                      title: const Text('App Lock'),
                      subtitle: const Text('Require PIN to open app'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Coming soon!'),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.visibility_off,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                      title: const Text('Stealth Mode'),
                      subtitle: const Text('Disguise app icon'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Coming soon!'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // About Section
              const Text(
                'About',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.info,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                      title: const Text('Version'),
                      subtitle: const Text('1.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.policy,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.help,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                      title: const Text('Help & Support'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Emergency Info Card
              Card(
                color: Colors.red.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.emergency, color: Colors.red),
                          SizedBox(width: 12),
                          Text(
                            'Emergency Numbers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildEmergencyNumber('Emergency', '911'),
                      _buildEmergencyNumber('Police', '100'),
                      _buildEmergencyNumber('Women Helpline', '181'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // App Branding
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield,
                        size: 40,
                        color: Color(0xFFE91E63),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SafeHer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE91E63),
                      ),
                    ),
                    const Text(
                      'Your Safety, Our Priority',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Made with ❤️ by Forward Alpha',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmergencyNumber(String label, String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            number,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showTimePickerDialog(BuildContext context, AppProvider provider) {
    final times = [15, 30, 45, 60, 90, 120];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Alert Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: times.map((minutes) {
            return ListTile(
              title: Text('$minutes minutes'),
              trailing: provider.stationaryAlertMinutes == minutes
                  ? const Icon(Icons.check, color: Color(0xFFE91E63))
                  : null,
              onTap: () {
                provider.setStationaryAlertMinutes(minutes);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
