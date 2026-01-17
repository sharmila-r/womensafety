import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../config/dev_keys.dart';

/// Service to manage Firebase Remote Config
/// Used to store API keys and feature flags that can be updated without app release
class RemoteConfigService {
  static RemoteConfigService? _instance;
  static RemoteConfigService get instance => _instance ??= RemoteConfigService._();

  RemoteConfigService._();

  FirebaseRemoteConfig? _remoteConfig;
  bool _initialized = false;

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Initialize Remote Config with defaults and fetch latest values
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values (fallback if remote fetch fails)
      await _remoteConfig!.setDefaults(_defaultValues);

      // Configure settings
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1), // Cache for 1 hour
      ));

      // Fetch and activate remote values
      await _remoteConfig!.fetchAndActivate();

      _initialized = true;
      print('Remote Config initialized successfully');
    } catch (e) {
      // If remote config fails, we'll use default values
      print('Remote Config initialization failed: $e');
      _initialized = false;
    }
  }

  /// Default values (used if remote fetch fails or for new keys)
  Map<String, dynamic> get _defaultValues => {
    // Didit
    'didit_api_key': DevKeys.diditApiKey,
    'didit_app_id': DevKeys.diditAppId,
    'didit_kyc_workflow_id': DevKeys.diditKycWorkflowId,
    'didit_liveness_workflow_id': DevKeys.diditLivenessWorkflowId,

    // Gridlines
    'gridlines_api_key': DevKeys.gridlinesApiKey,

    // Surepass
    'surepass_api_key': DevKeys.surepassApiKey,

    // Feature flags
    'kyc_provider': 'didit', // 'didit', 'idfy', 'manual'
    'enable_bgv': true,
    'enable_volunteer_registration': true,
    'min_face_match_score': 0.7,

    // BGV settings
    'bgv_required_for_online': false, // false = ID verified can go online, true = BGV required
    'bgv_skip_api_calls': true, // true = skip real BGV API calls (for testing)

    // Country-specific service radius
    // ID Verified volunteers (after KYC, before BGV)
    'volunteer_radius_id_verified_in': 5.0,  // India: 5km
    'volunteer_radius_id_verified_us': 5.0,  // USA: 5 miles
    'volunteer_radius_id_verified_default': 5.0,  // Default: 5km

    // BGV Verified volunteers (after background check)
    'volunteer_radius_bgv_verified_in': 10.0,  // India: 10km
    'volunteer_radius_bgv_verified_us': 10.0,  // USA: 10 miles
    'volunteer_radius_bgv_verified_default': 10.0,  // Default: 10km
  };

  // ==================== SAFE GETTERS (return defaults if not initialized) ====================

  String _getString(String key, String defaultValue) {
    if (!_initialized || _remoteConfig == null) return defaultValue;
    return _remoteConfig!.getString(key);
  }

  bool _getBool(String key, bool defaultValue) {
    if (!_initialized || _remoteConfig == null) return defaultValue;
    return _remoteConfig!.getBool(key);
  }

  double _getDouble(String key, double defaultValue) {
    if (!_initialized || _remoteConfig == null) return defaultValue;
    return _remoteConfig!.getDouble(key);
  }

  // ==================== DIDIT CONFIG ====================

  String get diditApiKey => _getString('didit_api_key', DevKeys.diditApiKey);
  String get diditAppId => _getString('didit_app_id', DevKeys.diditAppId);
  String get diditKycWorkflowId => _getString('didit_kyc_workflow_id', DevKeys.diditKycWorkflowId);
  String get diditLivenessWorkflowId => _getString('didit_liveness_workflow_id', DevKeys.diditLivenessWorkflowId);

  bool get isDiditConfigured =>
      diditApiKey.isNotEmpty && diditAppId.isNotEmpty && diditKycWorkflowId.isNotEmpty;

  // ==================== GRIDLINES CONFIG ====================

  String get gridlinesApiKey => _getString('gridlines_api_key', DevKeys.gridlinesApiKey);
  bool get isGridlinesConfigured => gridlinesApiKey.isNotEmpty;

  // ==================== SUREPASS CONFIG ====================

  String get surepassApiKey => _getString('surepass_api_key', DevKeys.surepassApiKey);
  bool get isSurepassConfigured => surepassApiKey.isNotEmpty;

  // ==================== FEATURE FLAGS ====================

  /// Which KYC provider to use: 'didit', 'idfy', 'gridlines', 'manual'
  String get kycProvider => _getString('kyc_provider', 'didit');

  /// Whether background verification is enabled
  bool get enableBgv => _getBool('enable_bgv', true);

  /// Whether volunteer registration is enabled
  bool get enableVolunteerRegistration => _getBool('enable_volunteer_registration', true);

  /// Minimum face match score to pass verification (0.0 - 1.0)
  double get minFaceMatchScore => _getDouble('min_face_match_score', 0.7);

  /// Whether BGV is required to go online
  /// false = ID verified volunteers can go online
  /// true = Only BGV verified volunteers can go online
  bool get bgvRequiredForOnline => _getBool('bgv_required_for_online', false);

  /// Whether to skip real BGV API calls (for testing)
  /// true = Return mock success without calling real API
  /// false = Call real BGV API (IDfy/Checkr)
  bool get bgvSkipApiCalls => _getBool('bgv_skip_api_calls', true);

  // ==================== COUNTRY-SPECIFIC SERVICE RADIUS ====================

  /// Get service radius for ID-verified volunteers by country code
  double getIdVerifiedRadius(String countryCode) {
    final key = 'volunteer_radius_id_verified_${countryCode.toLowerCase()}';
    final value = _getDouble(key, 0.0);
    if (value > 0) return value;
    return _getDouble('volunteer_radius_id_verified_default', 2.0);
  }

  /// Get service radius for BGV-verified volunteers by country code
  double getBgvVerifiedRadius(String countryCode) {
    final key = 'volunteer_radius_bgv_verified_${countryCode.toLowerCase()}';
    final value = _getDouble(key, 0.0);
    if (value > 0) return value;
    return _getDouble('volunteer_radius_bgv_verified_default', 5.0);
  }

  // ==================== UTILITIES ====================

  /// Force refresh config from server (ignores cache)
  Future<void> forceRefresh() async {
    if (!_initialized || _remoteConfig == null) return;

    try {
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // Bypass cache
      ));
      await _remoteConfig!.fetchAndActivate();
    } catch (e) {
      print('Remote Config refresh failed: $e');
    }
  }

  /// Get any string value by key
  String getString(String key) => _getString(key, '');

  /// Get any bool value by key
  bool getBool(String key) => _getBool(key, false);

  /// Get any int value by key
  int getInt(String key) {
    if (!_initialized || _remoteConfig == null) return 0;
    return _remoteConfig!.getInt(key);
  }

  /// Get any double value by key
  double getDouble(String key) => _getDouble(key, 0.0);
}
