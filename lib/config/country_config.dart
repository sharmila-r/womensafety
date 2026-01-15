import 'dart:io';
import 'countries/base_country.dart';
import 'countries/india.dart';
import 'countries/usa.dart';

/// Singleton class to manage country configuration
class CountryConfigManager {
  static final CountryConfigManager _instance = CountryConfigManager._internal();
  factory CountryConfigManager() => _instance;
  CountryConfigManager._internal();

  /// All supported countries
  static final Map<String, BaseCountryConfig> _countries = {
    'IN': IndiaConfig(),
    'US': USAConfig(),
  };

  /// Currently selected country config
  BaseCountryConfig? _currentConfig;

  /// Get current country configuration
  BaseCountryConfig get current {
    _currentConfig ??= _detectCountry();
    return _currentConfig!;
  }

  /// Get all supported countries
  List<BaseCountryConfig> get supportedCountries => _countries.values.toList();

  /// Get country by code
  BaseCountryConfig? getCountry(String code) => _countries[code.toUpperCase()];

  /// Set country manually
  void setCountry(String countryCode) {
    final config = _countries[countryCode.toUpperCase()];
    if (config != null) {
      _currentConfig = config;
    }
  }

  /// Detect country based on device locale
  BaseCountryConfig _detectCountry() {
    try {
      final locale = Platform.localeName;
      final countryCode = locale.split('_').last.toUpperCase();

      if (_countries.containsKey(countryCode)) {
        return _countries[countryCode]!;
      }
    } catch (_) {
      // Fallback if locale detection fails
    }

    // Default to USA if country not detected or not supported
    return _countries['US']!;
  }

  /// Check if a country is supported
  bool isSupported(String countryCode) =>
      _countries.containsKey(countryCode.toUpperCase());

  /// Get emergency number for quick access
  String get emergencyNumber => current.emergencyNumber;

  /// Get all emergency contacts for current country
  List<EmergencyContact> get emergencyContacts => current.emergencyContacts;

  /// Get women helplines for current country
  List<EmergencyContact> get womenHelplines => current.womenHelplines;

  /// Get NGO partners for current country
  List<NGOPartner> get ngoPartners => current.ngoPartners;

  /// Get phone country code (e.g., +91, +1)
  String get phoneCode => current.phoneCode;
}

/// Extension for easy access throughout the app
extension CountryConfigExtension on BaseCountryConfig {
  /// Format phone number with country code
  String formatPhoneNumber(String number) {
    // Remove any existing formatting
    final cleaned = number.replaceAll(RegExp(r'[^\d]'), '');

    // Add country code if not present
    if (!cleaned.startsWith(phoneCode.replaceAll('+', ''))) {
      return '$phoneCode$cleaned';
    }
    return '+$cleaned';
  }

  /// Get appropriate helpline based on situation
  EmergencyContact? getHelplineForType(EmergencyContactType type) {
    try {
      return womenHelplines.firstWhere((h) => h.type == type);
    } catch (_) {
      return womenHelplines.isNotEmpty ? womenHelplines.first : null;
    }
  }

  /// Get NGOs that accept reports
  List<NGOPartner> get reportingNGOs =>
      ngoPartners.where((ngo) => ngo.acceptsReports).toList();
}
