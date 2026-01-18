import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/escort_screen.dart';
import 'screens/report_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/phone_login_screen.dart';
import 'screens/volunteer/sos_response_screen.dart';
import 'services/firebase_service.dart';
import 'services/push_notification_service.dart';
import 'services/remote_config_service.dart';
import 'services/auth_service.dart';
import 'l10n/app_localizations.dart';

/// Background message handler - must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await FirebaseService.instance.initialize();

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize push notifications
    await PushNotificationService().initialize();

    // Set navigator key for notification navigation
    PushNotificationService.setNavigatorKey(navigatorKey);

    // Initialize Remote Config (for API keys and feature flags)
    await RemoteConfigService.instance.initialize();
  } catch (e) {
    print('Firebase initialization error: $e');
    // Continue without Firebase for testing
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const WomenSafetyApp());
}

/// Global navigator key for navigation from anywhere (e.g., callbacks, services)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class WomenSafetyApp extends StatelessWidget {
  const WomenSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Kaavala',
            debugShowCheckedModeBanner: false,
            // Localization
            locale: provider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFE91E63),
                primary: const Color(0xFFE91E63),
                secondary: const Color(0xFF9C27B0),
                surface: Colors.white,
                background: const Color(0xFFFCE4EC),
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                backgroundColor: Color(0xFFE91E63),
                foregroundColor: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            home: const SplashScreen(),
            routes: {
              '/home': (context) => const MainNavigationScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/login': (context) => const PhoneLoginScreen(
                title: 'Sign In',
                subtitle: 'Sign in to access all features',
              ),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/sos-response') {
                final data = settings.arguments as Map<String, dynamic>?;
                if (data != null) {
                  return MaterialPageRoute(
                    builder: (context) => SOSResponseScreen(
                      alertId: data['alertId'] ?? '',
                      senderName: data['senderName'] ?? 'Someone',
                      senderPhone: data['senderPhone'] ?? '',
                      latitude: double.tryParse(data['latitude']?.toString() ?? '0') ?? 0,
                      longitude: double.tryParse(data['longitude']?.toString() ?? '0') ?? 0,
                      address: data['address'] ?? 'Unknown location',
                      message: data['message'],
                    ),
                  );
                }
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

/// Splash screen to check onboarding status
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Brief splash

    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    if (!mounted) return;

    if (!onboardingComplete) {
      // First time user - show onboarding
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else if (!_authService.isLoggedIn) {
      // Onboarding done but not logged in - show login
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // Logged in - save FCM token and go to home
      await PushNotificationService().saveTokenAfterLogin();
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE91E63), Color(0xFFFCE4EC)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'Kaavala',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your Safety, Our Priority',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ContactsScreen(),
    const EscortScreen(),
    const ReportScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFE91E63),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.contacts_outlined),
              activeIcon: Icon(Icons.contacts),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_walk_outlined),
              activeIcon: Icon(Icons.directions_walk),
              label: 'Escort',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.report_outlined),
              activeIcon: Icon(Icons.report),
              label: 'Report',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
