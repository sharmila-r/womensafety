import '../services/remote_config_service.dart';
import 'dev_keys.dart';

/// Environment configuration for API keys and secrets
///
/// Priority order for API keys:
/// 1. --dart-define flags (CI/CD builds)
/// 2. Firebase Remote Config (production - can update without app release)
/// 3. DevKeys (local development fallback)
///
/// Example build command:
/// flutter build apk --dart-define=DIDIT_API_KEY=your_key --dart-define=DIDIT_APP_ID=your_id
class EnvConfig {
  // Lazy getter for RemoteConfigService - only access when needed
  static RemoteConfigService get _remoteConfig => RemoteConfigService.instance;

  // ==================== DIDIT CONFIG ====================

  static const String _diditApiKeyEnv = String.fromEnvironment('DIDIT_API_KEY');
  static String get diditApiKey {
    if (_diditApiKeyEnv.isNotEmpty) return _diditApiKeyEnv;
    if (_remoteConfig.isInitialized) {
      final remoteValue = _remoteConfig.diditApiKey;
      if (remoteValue.isNotEmpty) return remoteValue;
    }
    return DevKeys.diditApiKey;
  }

  static const String _diditAppIdEnv = String.fromEnvironment('DIDIT_APP_ID');
  static String get diditAppId {
    if (_diditAppIdEnv.isNotEmpty) return _diditAppIdEnv;
    if (_remoteConfig.isInitialized) {
      final remoteValue = _remoteConfig.diditAppId;
      if (remoteValue.isNotEmpty) return remoteValue;
    }
    return DevKeys.diditAppId;
  }

  static const String _diditKycWorkflowIdEnv =
      String.fromEnvironment('DIDIT_KYC_WORKFLOW_ID');
  static String get diditKycWorkflowId {
    if (_diditKycWorkflowIdEnv.isNotEmpty) return _diditKycWorkflowIdEnv;
    if (_remoteConfig.isInitialized) {
      final remoteValue = _remoteConfig.diditKycWorkflowId;
      if (remoteValue.isNotEmpty) return remoteValue;
    }
    return DevKeys.diditKycWorkflowId;
  }

  static const String _diditLivenessWorkflowIdEnv =
      String.fromEnvironment('DIDIT_LIVENESS_WORKFLOW_ID');
  static String get diditLivenessWorkflowId {
    if (_diditLivenessWorkflowIdEnv.isNotEmpty) return _diditLivenessWorkflowIdEnv;
    if (_remoteConfig.isInitialized) {
      final remoteValue = _remoteConfig.diditLivenessWorkflowId;
      if (remoteValue.isNotEmpty) return remoteValue;
    }
    return DevKeys.diditLivenessWorkflowId;
  }

  // ==================== GRIDLINES CONFIG ====================

  static const String _gridlinesApiKeyEnv =
      String.fromEnvironment('GRIDLINES_API_KEY');
  static String get gridlinesApiKey {
    if (_gridlinesApiKeyEnv.isNotEmpty) return _gridlinesApiKeyEnv;
    if (_remoteConfig.isInitialized) {
      final remoteValue = _remoteConfig.gridlinesApiKey;
      if (remoteValue.isNotEmpty) return remoteValue;
    }
    return DevKeys.gridlinesApiKey;
  }

  // ==================== SUREPASS CONFIG ====================

  static const String _surepassApiKeyEnv =
      String.fromEnvironment('SUREPASS_API_KEY');
  static String get surepassApiKey {
    if (_surepassApiKeyEnv.isNotEmpty) return _surepassApiKeyEnv;
    if (_remoteConfig.isInitialized) {
      final remoteValue = _remoteConfig.surepassApiKey;
      if (remoteValue.isNotEmpty) return remoteValue;
    }
    return DevKeys.surepassApiKey;
  }

  // ==================== OTHER CONFIG ====================

  static const String webhookBaseUrl = String.fromEnvironment(
    'WEBHOOK_BASE_URL',
    defaultValue: '',
  );

  // ==================== FEATURE FLAGS ====================

  /// Which KYC provider to use
  static String get kycProvider {
    if (_remoteConfig.isInitialized) return _remoteConfig.kycProvider;
    return 'didit';
  }

  /// Whether BGV is enabled
  static bool get enableBgv {
    if (_remoteConfig.isInitialized) return _remoteConfig.enableBgv;
    return true;
  }

  /// Whether volunteer registration is enabled
  static bool get enableVolunteerRegistration {
    if (_remoteConfig.isInitialized) return _remoteConfig.enableVolunteerRegistration;
    return true;
  }

  /// Minimum face match score
  static double get minFaceMatchScore {
    if (_remoteConfig.isInitialized) return _remoteConfig.minFaceMatchScore;
    return 0.7;
  }

  // ==================== HELPERS ====================

  /// Check if Didit is configured
  static bool get isDiditConfigured =>
      diditApiKey.isNotEmpty &&
      diditAppId.isNotEmpty &&
      diditKycWorkflowId.isNotEmpty;

  /// Check if any KYC provider is configured
  static bool get hasKycProvider =>
      isDiditConfigured || gridlinesApiKey.isNotEmpty;
}
