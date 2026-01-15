/// Base class for country-specific configuration
abstract class BaseCountryConfig {
  /// Country code (e.g., 'IN', 'US')
  String get countryCode;

  /// Country name
  String get countryName;

  /// Phone country code (e.g., '+91', '+1')
  String get phoneCode;

  /// Primary emergency number
  String get emergencyNumber;

  /// List of all emergency contacts
  List<EmergencyContact> get emergencyContacts;

  /// List of women-specific helplines
  List<EmergencyContact> get womenHelplines;

  /// List of partner NGOs
  List<NGOPartner> get ngoPartners;

  /// Default language code
  String get defaultLanguage;

  /// Supported languages
  List<String> get supportedLanguages;

  /// Whether background check API is available in this country
  bool get hasBackgroundCheckAPI;

  /// Background check provider name (if available)
  String? get backgroundCheckProvider;

  /// Get all emergency numbers as a flat list
  List<String> getAllEmergencyNumbers() {
    final numbers = <String>[emergencyNumber];
    numbers.addAll(emergencyContacts.map((e) => e.number));
    numbers.addAll(womenHelplines.map((e) => e.number));
    return numbers.toSet().toList();
  }
}

/// Emergency contact model
class EmergencyContact {
  final String name;
  final String number;
  final String? description;
  final EmergencyContactType type;
  final bool isTollFree;

  const EmergencyContact({
    required this.name,
    required this.number,
    this.description,
    required this.type,
    this.isTollFree = true,
  });
}

/// Types of emergency contacts
enum EmergencyContactType {
  police,
  ambulance,
  fire,
  womenHelpline,
  domesticViolence,
  sexualAssault,
  childHelpline,
  mentalHealth,
  general,
}

/// NGO Partner model
class NGOPartner {
  final String name;
  final String? website;
  final String? phone;
  final String? email;
  final String description;
  final List<String> services;
  final List<String> operatingRegions;
  final bool acceptsReports;

  const NGOPartner({
    required this.name,
    this.website,
    this.phone,
    this.email,
    required this.description,
    required this.services,
    this.operatingRegions = const [],
    this.acceptsReports = false,
  });
}
