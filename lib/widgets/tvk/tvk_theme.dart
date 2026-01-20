import 'package:flutter/material.dart';

/// TVK Kavalan theme colors and utilities
/// Teal theme for volunteer event dashboard (distinct from pink women safety theme)
class TVKColors {
  // Primary colors
  static const Color primary = Color(0xFF00796B);
  static const Color primaryDark = Color(0xFF004D40);
  static const Color primaryLight = Color(0xFF48A999);

  // Background colors
  static const Color background = Color(0xFFE0F2F1);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // Zone status colors
  static const Color zoneSafe = Color(0xFF4CAF50);
  static const Color zoneWarning = Color(0xFFFF9800);
  static const Color zoneDanger = Color(0xFFF44336);
  static const Color zoneCritical = Color(0xFF9C27B0);

  // Role colors
  static const Color roleCoordinator = Color(0xFF9C27B0);
  static const Color roleZoneCaptain = Color(0xFFFFC000);
  static const Color roleMedical = Color(0xFF4CAF50);
  static const Color roleSecurity = Color(0xFF2196F3);
  static const Color roleGeneral = Color(0xFF607D8B);

  // Alert severity colors
  static const Color alertLow = Color(0xFF2196F3);
  static const Color alertMedium = Color(0xFFFF9800);
  static const Color alertHigh = Color(0xFFF44336);
  static const Color alertCritical = Color(0xFF9C27B0);

  // Status colors
  static const Color statusActive = Color(0xFF4CAF50);
  static const Color statusOnBreak = Color(0xFFFF9800);
  static const Color statusResponding = Color(0xFF2196F3);
  static const Color statusOffline = Color(0xFF9E9E9E);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Colors.white;
}

/// TVK theme data for wrapping screens
class TVKTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TVKColors.primary,
        primary: TVKColors.primary,
        secondary: TVKColors.primaryLight,
        surface: TVKColors.surface,
      ),
      scaffoldBackgroundColor: TVKColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: TVKColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: TVKColors.cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TVKColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TVKColors.primary,
          side: const BorderSide(color: TVKColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TVKColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: TVKColors.primary,
        unselectedItemColor: TVKColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: TVKColors.background,
        selectedColor: TVKColors.primary,
        labelStyle: const TextStyle(color: TVKColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TVKColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Get color for zone status
  static Color getZoneStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'safe':
        return TVKColors.zoneSafe;
      case 'warning':
        return TVKColors.zoneWarning;
      case 'danger':
        return TVKColors.zoneDanger;
      case 'critical':
        return TVKColors.zoneCritical;
      default:
        return TVKColors.zoneSafe;
    }
  }

  /// Get color for volunteer role
  static Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'coordinator':
        return TVKColors.roleCoordinator;
      case 'zone_captain':
        return TVKColors.roleZoneCaptain;
      case 'medical':
        return TVKColors.roleMedical;
      case 'security':
        return TVKColors.roleSecurity;
      default:
        return TVKColors.roleGeneral;
    }
  }

  /// Get color for alert severity
  static Color getAlertSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return TVKColors.alertLow;
      case 'medium':
        return TVKColors.alertMedium;
      case 'high':
        return TVKColors.alertHigh;
      case 'critical':
        return TVKColors.alertCritical;
      default:
        return TVKColors.alertMedium;
    }
  }

  /// Get color for volunteer status
  static Color getVolunteerStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return TVKColors.statusActive;
      case 'on_break':
        return TVKColors.statusOnBreak;
      case 'responding':
        return TVKColors.statusResponding;
      case 'offline':
        return TVKColors.statusOffline;
      default:
        return TVKColors.statusOffline;
    }
  }

  /// Get display name for role
  static String getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'coordinator':
        return 'Coordinator';
      case 'zone_captain':
        return 'Zone Captain';
      case 'medical':
        return 'Medical';
      case 'security':
        return 'Security';
      case 'general':
        return 'Volunteer';
      default:
        return role;
    }
  }

  /// Get icon for role
  static IconData getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'coordinator':
        return Icons.admin_panel_settings;
      case 'zone_captain':
        return Icons.military_tech;
      case 'medical':
        return Icons.medical_services;
      case 'security':
        return Icons.shield;
      default:
        return Icons.person;
    }
  }
}
