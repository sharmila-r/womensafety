import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/push_notification_service.dart';

/// Phone OTP login screen
class PhoneLoginScreen extends StatefulWidget {
  final String? initialPhone;
  final String? title;
  final String? subtitle;

  const PhoneLoginScreen({
    super.key,
    this.initialPhone,
    this.title,
    this.subtitle,
  });

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

// Test phone number for App Store review demo mode
const String _demoPhoneNumber = '+919876543210';

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final AuthService _authService = AuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  String? _error;
  bool _showDemoOption = false; // Show demo mode option on error with test number

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    var cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Add country code if not present
    if (!cleaned.startsWith('+')) {
      // Default to India (+91) if no country code
      if (cleaned.length == 10) {
        cleaned = '+91$cleaned';
      } else {
        cleaned = '+$cleaned';
      }
    }
    return cleaned;
  }

  Future<void> _sendOtp() async {
    final phone = _formatPhoneNumber(_phoneController.text.trim());

    if (phone.length < 10) {
      setState(() => _error = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _authService.sendOTP(
      phoneNumber: phone,
      onCodeSent: (verificationId) {
        setState(() {
          _isLoading = false;
          _codeSent = true;
          _verificationId = verificationId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent! Please check your messages.'),
            backgroundColor: Colors.green,
          ),
        );
      },
      onError: (error) {
        final phone = _formatPhoneNumber(_phoneController.text.trim());
        setState(() {
          _isLoading = false;
          _error = error;
          // Show demo option if using test number and there's an error
          _showDemoOption = (phone == _demoPhoneNumber);
        });
      },
      onAutoVerify: (credential) async {
        // Auto-verification on Android
        await _signInWithCredential(credential);
      },
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      setState(() => _error = 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final credential = await _authService.verifyOTP(
        otp: otp,
        verificationId: _verificationId,
      );

      if (credential != null && mounted) {
        // Save FCM token after successful login
        await PushNotificationService().saveTokenAfterLogin();
        // Navigate to home after successful login
        Navigator.pushReplacementNamed(
          context,
          defaultTargetPlatform == TargetPlatform.android ? '/permission-setup' : '/home',
        );
      }
    } catch (e) {
      final phone = _formatPhoneNumber(_phoneController.text.trim());
      setState(() {
        _isLoading = false;
        _error = 'Invalid OTP. Please try again.';
        // Show demo option if using test number
        _showDemoOption = (phone == _demoPhoneNumber);
      });
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        // Save FCM token after successful login
        await PushNotificationService().saveTokenAfterLogin();
        // Navigate to home after successful login
        Navigator.pushReplacementNamed(
          context,
          defaultTargetPlatform == TargetPlatform.android ? '/permission-setup' : '/home',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Sign in failed: $e';
      });
    }
  }

  /// Continue in demo mode (for App Store review when Firebase auth fails)
  void _continueInDemoMode() {
    Navigator.pushReplacementNamed(
          context,
          defaultTargetPlatform == TargetPlatform.android ? '/permission-setup' : '/home',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Verify Phone'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    size: 40,
                    color: Color(0xFFE91E63),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Center(
                child: Text(
                  _codeSent ? 'Enter OTP' : 'Verify Your Phone',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Center(
                child: Text(
                  widget.subtitle ??
                      (_codeSent
                          ? 'Enter the 6-digit code sent to ${_phoneController.text}'
                          : 'We\'ll send you a verification code'),
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),

              // Demo mode option for App Store review
              if (_showDemoOption)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Network issues detected. You can continue in demo mode to preview the app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.blue),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _continueInDemoMode,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Continue in Demo Mode'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (!_codeSent) ...[
                // Phone number input
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+91 98765 43210',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Send OTP button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Send OTP',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ] else ...[
                // OTP input
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    labelText: 'Enter OTP',
                    hintText: '------',
                    counterText: '',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Verify OTP button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify OTP',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Resend OTP button
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _codeSent = false;
                              _otpController.clear();
                              _error = null;
                            });
                          },
                    child: const Text('Change phone number'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
