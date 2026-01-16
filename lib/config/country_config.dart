import 'dart:io';
import 'countries/base_country.dart';
import 'countries/india.dart';
import 'countries/usa.dart';
import '../services/location_service.dart';

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

  /// Whether location-based detection has been attempted
  bool _locationDetectionAttempted = false;

  /// Detected country code from GPS
  String? _detectedCountryCode;

  /// Get current country configuration
  BaseCountryConfig get current {
    _currentConfig ??= _detectCountryFromLocale();
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
      _detectedCountryCode = countryCode.toUpperCase();
    }
  }

  /// Initialize country from GPS location (call this early in app startup)
  Future<void> initializeFromLocation() async {
    if (_locationDetectionAttempted) return;
    _locationDetectionAttempted = true;

    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        await detectCountryFromCoordinates(position.latitude, position.longitude);
      }
    } catch (e) {
      print('Error detecting country from location: $e');
      // Fall back to locale-based detection
    }
  }

  /// Detect country from GPS coordinates using reverse geocoding
  Future<bool> detectCountryFromCoordinates(double latitude, double longitude) async {
    try {
      final countryCode = await LocationService.getCountryCodeFromCoordinates(
        latitude,
        longitude,
      );

      if (countryCode != null && _countries.containsKey(countryCode)) {
        _currentConfig = _countries[countryCode];
        _detectedCountryCode = countryCode;
        print('Country detected from GPS: $countryCode');
        return true;
      } else if (countryCode != null) {
        print('Country $countryCode not supported, using default');
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
    }
    return false;
  }

  /// Get the detected country code
  String? get detectedCountryCode => _detectedCountryCode;

  /// Detect country based on device locale (fallback)
  BaseCountryConfig _detectCountryFromLocale() {
    try {
      final locale = Platform.localeName;
      final countryCode = locale.split('_').last.toUpperCase();

      if (_countries.containsKey(countryCode)) {
        _detectedCountryCode = countryCode;
        return _countries[countryCode]!;
      }
    } catch (_) {
      // Fallback if locale detection fails
    }

    // Default to USA if country not detected or not supported
    _detectedCountryCode = 'US';
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
