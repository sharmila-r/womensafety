import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../config/country_config.dart';
import '../config/countries/base_country.dart';
import '../l10n/app_localizations.dart';
import 'ble_button_screen.dart';
import 'volunteer/volunteer_registration_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _countryManager = CountryConfigManager();

  @override
  Widget build(BuildContext context) {
    final currentCountry = _countryManager.current;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Country Selection Section
              const Text(
                'Region',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.public,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                  title: const Text('Country'),
                  subtitle: Text(currentCountry.countryName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCountryPicker(context),
                ),
              ),

              const SizedBox(height: 24),

              // Language Section
              Text(
                AppLocalizations.of(context).language,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.language,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                  title: Text(AppLocalizations.of(context).language),
                  subtitle: Text(
                    provider.languageCode == 'ta'
                        ? AppLocalizations.of(context).tamil
                        : AppLocalizations.of(context).english,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguagePicker(context, provider),
                ),
              ),

              const SizedBox(height: 24),

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
              const SizedBox(height: 8),

              // BLE SOS Button
              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.touch_app,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                  title: const Text('SOS Panic Button'),
                  subtitle: const Text(
                    'Connect a wearable Bluetooth button',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BleButtonScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Emergency Numbers Section (Country-specific)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Emergency Numbers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                  Text(
                    currentCountry.countryCode,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Card(
                color: Colors.red.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ...currentCountry.emergencyContacts.map(
                        (contact) => _buildEmergencyRow(contact),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Women Helplines Section
              const Text(
                'Women Helplines',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: currentCountry.womenHelplines.map((helpline) {
                    return Column(
                      children: [
                        ListTile(
                          leading: _getHelplineIcon(helpline.type),
                          title: Text(helpline.name),
                          subtitle: Text(
                            helpline.description ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (helpline.isTollFree)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Free',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.call, color: Colors.green),
                                onPressed: () => _makeCall(helpline.number),
                              ),
                            ],
                          ),
                        ),
                        if (helpline != currentCountry.womenHelplines.last)
                          const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // NGO Partners Section
              const Text(
                'Support Organizations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 16),

              ...currentCountry.ngoPartners.take(4).map((ngo) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.volunteer_activism,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                      title: Text(ngo.name),
                      subtitle: Text(
                        ngo.operatingRegions.join(', '),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ngo.description),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ngo.services
                                    .map((s) => Chip(
                                          label: Text(
                                            s,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          backgroundColor: const Color(0xFFE91E63)
                                              .withOpacity(0.1),
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (ngo.phone != null)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _makeCall(ngo.phone!),
                                        icon: const Icon(Icons.call, size: 16),
                                        label: const Text('Call'),
                                      ),
                                    ),
                                  if (ngo.phone != null && ngo.website != null)
                                    const SizedBox(width: 8),
                                  if (ngo.website != null)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _openWebsite(ngo.website!),
                                        icon: const Icon(Icons.language, size: 16),
                                        label: const Text('Website'),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),

              TextButton(
                onPressed: () => _showAllNGOs(context, currentCountry),
                child: const Text('View all organizations'),
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
                          const SnackBar(content: Text('Coming soon!')),
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
                          const SnackBar(content: Text('Coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Volunteer Section
              const Text(
                'Volunteer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                  title: const Text('Become a Volunteer'),
                  subtitle: const Text(
                    'Help keep others safe in your community',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VolunteerRegistrationScreen(),
                      ),
                    );
                  },
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
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Version'),
                      subtitle: Text('1.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.policy_outlined),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
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
                      'Kaavala',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE91E63),
                      ),
                    ),
                    const Text(
                      'Your Safety, Our Priority',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Made with love by Forward Alpha',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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

  Widget _buildEmergencyRow(EmergencyContact contact) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (contact.description != null)
                  Text(
                    contact.description!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _makeCall(contact.number),
            icon: const Icon(Icons.call, size: 18),
            label: Text(
              contact.number,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getHelplineIcon(EmergencyContactType type) {
    IconData icon;
    Color color;

    switch (type) {
      case EmergencyContactType.womenHelpline:
        icon = Icons.woman;
        color = const Color(0xFFE91E63);
        break;
      case EmergencyContactType.domesticViolence:
        icon = Icons.home;
        color = Colors.orange;
        break;
      case EmergencyContactType.sexualAssault:
        icon = Icons.support;
        color = Colors.purple;
        break;
      case EmergencyContactType.childHelpline:
        icon = Icons.child_care;
        color = Colors.blue;
        break;
      case EmergencyContactType.mentalHealth:
        icon = Icons.psychology;
        color = Colors.teal;
        break;
      default:
        icon = Icons.phone;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }

  void _showLanguagePicker(BuildContext context, AppProvider provider) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.language,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: Text(l10n.english),
              subtitle: const Text('English'),
              trailing: provider.languageCode == 'en'
                  ? const Icon(Icons.check, color: Color(0xFFE91E63))
                  : null,
              onTap: () {
                provider.setLanguage('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('🇮🇳', style: TextStyle(fontSize: 24)),
              title: Text(l10n.tamil),
              subtitle: const Text('தமிழ்'),
              trailing: provider.languageCode == 'ta'
                  ? const Icon(Icons.check, color: Color(0xFFE91E63))
                  : null,
              onTap: () {
                provider.setLanguage('ta');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Country',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ..._countryManager.supportedCountries.map((country) => ListTile(
                  leading: Text(
                    _getCountryFlag(country.countryCode),
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(country.countryName),
                  subtitle: Text('Emergency: ${country.emergencyNumber}'),
                  trailing: _countryManager.current.countryCode ==
                          country.countryCode
                      ? const Icon(Icons.check, color: Color(0xFFE91E63))
                      : null,
                  onTap: () {
                    setState(() {
                      _countryManager.setCountry(country.countryCode);
                    });
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getCountryFlag(String countryCode) {
    switch (countryCode) {
      case 'IN':
        return '🇮🇳';
      case 'US':
        return '🇺🇸';
      default:
        return '🌍';
    }
  }

  void _showAllNGOs(BuildContext context, BaseCountryConfig country) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Support Organizations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: country.ngoPartners.length,
                itemBuilder: (context, index) {
                  final ngo = country.ngoPartners[index];
                  return ListTile(
                    title: Text(ngo.name),
                    subtitle: Text(ngo.description, maxLines: 2),
                    trailing: ngo.acceptsReports
                        ? const Chip(
                            label: Text('Reports', style: TextStyle(fontSize: 10)),
                            backgroundColor: Color(0xFFE91E63),
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : null,
                    onTap: () {
                      if (ngo.website != null) _openWebsite(ngo.website!);
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
          children: times
              .map((minutes) => ListTile(
                    title: Text('$minutes minutes'),
                    trailing: provider.stationaryAlertMinutes == minutes
                        ? const Icon(Icons.check, color: Color(0xFFE91E63))
                        : null,
                    onTap: () {
                      provider.setStationaryAlertMinutes(minutes);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _makeCall(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWebsite(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
