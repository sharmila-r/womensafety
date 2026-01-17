import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firebase service for managing Firebase instances
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();

  FirebaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Firebase instances
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;

  FirebaseAuth get auth {
    if (_auth == null) throw Exception('Firebase not initialized');
    return _auth!;
  }

  FirebaseFirestore get firestore {
    if (_firestore == null) throw Exception('Firebase not initialized');
    return _firestore!;
  }

  FirebaseStorage get storage {
    if (_storage == null) throw Exception('Firebase not initialized');
    return _storage!;
  }

  /// Initialize Firebase
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      print('🔥 Starting Firebase initialization...');
      final app = await Firebase.initializeApp();
      print('🔥 Firebase app initialized: ${app.name}');
      print('🔥 Firebase options:');
      print('   - Project ID: ${app.options.projectId}');
      print('   - App ID: ${app.options.appId}');
      print('   - API Key: ${app.options.apiKey.substring(0, 10)}...');

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;
      _initialized = true;

      print('🔥 FirebaseAuth instance: $_auth');
      print('🔥 Current user: ${_auth?.currentUser?.uid ?? "none"}');

      // Enable offline persistence for Firestore
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      print('✅ Firebase initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Firebase initialization failed: $e');
      print('❌ Stack trace: $stackTrace');
      // App can still work with local storage if Firebase fails
      _initialized = false;
    }
  }

  /// Get current user
  User? get currentUser => _auth?.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Sign out
  Future<void> signOut() async {
    await _auth?.signOut();
  }
}

/// Firestore collection references
class FirestoreCollections {
  static const String users = 'users';
  static const String contacts = 'contacts';
  static const String volunteers = 'volunteers';
  static const String reports = 'reports';
  static const String escortRequests = 'escortRequests';
  static const String heatmapData = 'heatmapData';
  static const String locationHistory = 'locationHistory';
}

/// Storage paths
class StoragePaths {
  static String userProfileImage(String userId) => 'users/$userId/profile.jpg';
  static String volunteerIdDoc(String odId) => 'volunteers/$odId/id_document.jpg';
  static String volunteerSelfie(String odId) => 'volunteers/$odId/selfie.jpg';
  static String reportImage(String reportId, int index) =>
      'reports/$reportId/image_$index.jpg';
}
