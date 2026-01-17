import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

/// Authentication service for phone OTP and email authentication
class AuthService {
  final FirebaseService _firebase = FirebaseService.instance;

  // Verification state
  String? _verificationId;
  int? _resendToken;

  /// Get current user
  User? get currentUser => _firebase.auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Get user ID
  String? get userId => currentUser?.uid;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _firebase.auth.authStateChanges();

  /// Send OTP to phone number
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    print('📱 AuthService.sendOTP called');
    print('📱 Phone number: $phoneNumber');
    print('📱 Current user: ${_firebase.auth.currentUser?.uid ?? "none"}');
    print('📱 Firebase app: ${_firebase.auth.app.name}');

    try {
      print('📱 Calling verifyPhoneNumber...');
      await _firebase.auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('✅ Auto-verification completed');
          onAutoVerify(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Verification FAILED');
          print('❌ Error code: ${e.code}');
          print('❌ Error message: ${e.message}');
          print('❌ Error details: ${e.toString()}');
          print('❌ Plugin: ${e.plugin}');

          String message = 'Verification failed: ${e.code}';
          if (e.code == 'invalid-phone-number') {
            message = 'Invalid phone number format';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many requests. Please try again later';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded. Please try again tomorrow';
          } else if (e.code == 'app-not-authorized') {
            message = 'App not authorized. Check Firebase Console SHA-1 fingerprint';
          } else if (e.code == 'missing-client-identifier') {
            message = 'Missing client identifier. Check google-services.json';
          } else if (e.message != null) {
            message = e.message!;
          }
          onError(message);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('✅ Code SENT successfully');
          print('✅ Verification ID: $verificationId');
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏰ Auto-retrieval timeout');
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
      print('📱 verifyPhoneNumber call completed');
    } catch (e, stackTrace) {
      print('💥 Exception in sendOTP: $e');
      print('💥 Stack trace: $stackTrace');
      onError('Failed to send OTP: $e');
    }
  }

  /// Verify OTP code
  Future<UserCredential?> verifyOTP({
    required String otp,
    String? verificationId,
  }) async {
    final verId = verificationId ?? _verificationId;
    if (verId == null) {
      throw Exception('No verification ID. Please request OTP first.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verId,
      smsCode: otp,
    );

    return await _firebase.auth.signInWithCredential(credential);
  }

  /// Sign in with credential (for auto-verification)
  Future<UserCredential?> signInWithCredential(
      PhoneAuthCredential credential) async {
    return await _firebase.auth.signInWithCredential(credential);
  }

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _firebase.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Create account with email and password
  Future<UserCredential?> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    return await _firebase.auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebase.auth.sendPasswordResetEmail(email: email);
  }

  /// Create or update user profile in Firestore
  Future<void> saveUserProfile({
    required String name,
    String? email,
    String? photoUrl,
    required String country,
  }) async {
    if (userId == null) throw Exception('User not logged in');

    await _firebase.firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .set({
      'name': name,
      'phone': currentUser?.phoneNumber,
      'email': email ?? currentUser?.email,
      'photoUrl': photoUrl,
      'country': country,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (userId == null) return null;

    final doc = await _firebase.firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .get();

    return doc.data();
  }

  /// Check if user profile exists
  Future<bool> hasUserProfile() async {
    if (userId == null) return false;

    final doc = await _firebase.firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .get();

    return doc.exists;
  }

  /// Sign out
  Future<void> signOut() async {
    _verificationId = null;
    _resendToken = null;
    await _firebase.auth.signOut();
  }

  /// Delete account
  Future<void> deleteAccount() async {
    if (userId == null) throw Exception('User not logged in');

    // Delete user data from Firestore
    await _firebase.firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .delete();

    // Delete Firebase Auth account
    await currentUser?.delete();
  }
}

/// User profile model
class UserProfile {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String country;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.photoUrl,
    required this.country,
    this.createdAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'],
      email: data['email'],
      photoUrl: data['photoUrl'],
      country: data['country'] ?? 'US',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'photoUrl': photoUrl,
        'country': country,
      };
}
