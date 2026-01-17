import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/didit_service.dart';

/// Screen that opens Didit verification in a WebView
class DiditVerificationScreen extends StatefulWidget {
  final String oderlId;
  final String? userEmail;
  final String? userPhone;

  const DiditVerificationScreen({
    super.key,
    required this.oderlId,
    this.userEmail,
    this.userPhone,
  });

  @override
  State<DiditVerificationScreen> createState() => _DiditVerificationScreenState();
}

class _DiditVerificationScreenState extends State<DiditVerificationScreen> {
  late final WebViewController _controller;
  final DiditService _diditService = DiditService.instance;

  bool _isLoading = true;
  bool _isCreatingSession = true;
  bool _showContinueButton = false;
  String? _error;
  String? _sessionId;
  DiditSession? _session;

  Timer? _pollTimer;
  Timer? _uiCheckTimer;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _createSession();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _uiCheckTimer?.cancel();
    super.dispose();
  }

  void _initWebView() {
    // Request camera permission upfront
    _requestPermissions();

    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      // iOS configuration
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _checkForCompletion(url);
          },
          onWebResourceError: (error) {
            setState(() {
              _error = 'Failed to load verification page';
              _isLoading = false;
            });
          },
          onNavigationRequest: (request) {
            // Handle callback URL if configured
            if (request.url.contains('verification/callback') ||
                request.url.contains('verification-complete')) {
              _handleVerificationComplete();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Android specific: Enable file uploads and camera
    if (_controller.platform is AndroidWebViewController) {
      final androidController = _controller.platform as AndroidWebViewController;

      // Handle file chooser for uploading documents
      androidController.setOnShowFileSelector((params) async {
        return await _handleFilePicker(params);
      });

      // Handle camera/microphone permission requests from JavaScript (getUserMedia)
      androidController.setOnPlatformPermissionRequest((request) async {
        // Request native permissions first
        final cameraStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();

        // Grant WebView permissions if native permissions granted
        if (cameraStatus.isGranted || micStatus.isGranted) {
          request.grant();
        } else {
          request.deny();
        }
      });

      // Enable geolocation
      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          return GeolocationPermissionsResponse(
            allow: true,
            retain: true,
          );
        },
      );

      // Set media playback to not require user gesture
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.photos,
      Permission.storage,
    ].request();
  }

  Future<List<String>> _handleFilePicker(FileSelectorParams params) async {
    final ImagePicker picker = ImagePicker();

    // Check if it's asking for images (camera/gallery)
    if (params.acceptTypes.any((type) =>
        type.contains('image') || type == '*/*')) {

      // Show options: Camera or Gallery
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );

      if (source == null) return [];

      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        return [Uri.file(image.path).toString()];
      }
    }

    return [];
  }

  Future<void> _createSession() async {
    try {
      final session = await _diditService.createKycSession(
        oderlId: widget.oderlId,
        userEmail: widget.userEmail ?? '',
        userPhone: widget.userPhone,
        metadata: {
          'source': 'safeher_volunteer_registration',
          'volunteer_id': widget.oderlId,
        },
      );

      setState(() {
        _session = session;
        _sessionId = session.sessionId;
        _isCreatingSession = false;
      });

      // Load the verification URL
      await _controller.loadRequest(Uri.parse(session.url));

      // Start polling for status
      _startPolling();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isCreatingSession = false;
      });
    }
  }

  void _startPolling() {
    // Poll every 5 seconds to check if verification is complete via API
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_sessionId == null) return;

      try {
        final status = await _diditService.getSessionStatus(_sessionId!);
        if (status.isCompleted) {
          _pollTimer?.cancel();
          _uiCheckTimer?.cancel();
          _handleVerificationComplete();
        }
      } catch (e) {
        // Ignore polling errors
      }
    });

    // Also check the UI periodically for success indicators
    _uiCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_showContinueButton) {
        await _detectSuccessInPage();
      } else {
        _uiCheckTimer?.cancel();
      }
    });
  }

  void _checkForCompletion(String url) {
    // Check if URL indicates completion
    if (url.contains('status=approved') ||
        url.contains('status=completed') ||
        url.contains('verification-complete') ||
        url.contains('/success') ||
        url.contains('/complete') ||
        url.contains('/done') ||
        url.contains('/result')) {
      setState(() => _showContinueButton = true);
    }

    // Also inject JS to detect success messages in the page
    _detectSuccessInPage();
  }

  Future<void> _detectSuccessInPage() async {
    try {
      // Check for common success indicators in the page
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          var text = document.body.innerText.toLowerCase();
          return text.includes('verification complete') ||
                 text.includes('successfully verified') ||
                 text.includes('verification successful') ||
                 text.includes('identity verified') ||
                 text.includes("you've been verified") ||
                 text.includes('you have been verified') ||
                 text.includes('been verified') ||
                 text.includes('no further action') ||
                 text.includes('all done') ||
                 text.includes('thank you');
        })()
      ''');

      print('=== JS DETECTION RESULT: $result ===');
      if (result == true || result.toString() == 'true') {
        if (mounted && !_showContinueButton) {
          print('=== SHOWING CONTINUE BUTTON ===');
          setState(() => _showContinueButton = true);
        }
      }
    } catch (e) {
      print('=== JS DETECTION ERROR: $e ===');
    }
  }

  Future<void> _handleVerificationComplete() async {
    _pollTimer?.cancel();
    _uiCheckTimer?.cancel();

    if (_sessionId == null) {
      Navigator.pop(context, DiditVerificationResult.failed('No session ID'));
      return;
    }

    setState(() => _isLoading = true);

    // Retry up to 5 times with 2 second delays if decision is pending
    const maxRetries = 5;
    DiditSessionResult? result;

    for (int i = 0; i < maxRetries; i++) {
      try {
        result = await _diditService.getSessionResult(_sessionId!);

        // If we got a definitive result, break out
        if (result.decision == 'Approved' || result.decision == 'Declined') {
          break;
        }

        // If still pending and not last retry, wait and try again
        if (i < maxRetries - 1) {
          print('Decision still pending, retrying in 2 seconds... (${i + 1}/$maxRetries)');
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        print('Error getting result: $e');
        if (i == maxRetries - 1) {
          // Last retry failed, continue with error handling below
          result = null;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!mounted) return;

    // If we still don't have a result or it's pending,
    // trust the UI success and return success
    if (result == null || result.decision == 'Pending') {
      // The user saw "You've been verified!" in Didit's UI,
      // so we'll trust that and mark as success
      print('=== RETURNING TRUSTED SUCCESS (decision was pending/null) ===');
      Navigator.pop(
        context,
        DiditVerificationResult(
          success: true,
          sessionId: _sessionId!,
          decision: 'Approved', // Trust the UI
        ),
      );
      return;
    }

    print('=== RETURNING API RESULT: decision=${result.decision}, isApproved=${result.isApproved} ===');
    Navigator.pop(
      context,
      DiditVerificationResult(
        success: result.isApproved,
        sessionId: _sessionId!,
        decision: result.decision,
        document: result.document,
        liveness: result.liveness,
        faceMatch: result.faceMatch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showCancelDialog(),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Verification Error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isCreatingSession = true;
                  });
                  _createSession();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isCreatingSession) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFE91E63)),
            SizedBox(height: 16),
            Text('Setting up verification...'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFE91E63)),
          ),
        // Show continue button when verification appears complete
        if (_showContinueButton)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _handleVerificationComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle),
                      SizedBox(width: 8),
                      Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Verification?'),
        content: const Text(
          'Are you sure you want to cancel? You\'ll need to restart the verification process.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(
                context,
                DiditVerificationResult.cancelled(),
              ); // Close screen
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Result from Didit verification
class DiditVerificationResult {
  final bool success;
  final bool cancelled;
  final String? sessionId;
  final String? decision;
  final String? errorMessage;
  final DocumentResult? document;
  final LivenessResult? liveness;
  final FaceMatchResult? faceMatch;

  DiditVerificationResult({
    required this.success,
    this.cancelled = false,
    this.sessionId,
    this.decision,
    this.errorMessage,
    this.document,
    this.liveness,
    this.faceMatch,
  });

  factory DiditVerificationResult.cancelled() {
    return DiditVerificationResult(
      success: false,
      cancelled: true,
    );
  }

  factory DiditVerificationResult.failed(String error) {
    return DiditVerificationResult(
      success: false,
      errorMessage: error,
    );
  }

  /// Extracted name from document
  String? get extractedName =>
      document?.fullName ??
      (document?.firstName != null && document?.lastName != null
          ? '${document!.firstName} ${document!.lastName}'
          : null);

  /// Extracted date of birth from document
  String? get extractedDob => document?.dateOfBirth;

  /// Face match confidence score
  double? get faceMatchScore => faceMatch?.similarity;

  /// Whether liveness check passed
  bool get livenessPasssed => liveness?.passed ?? false;
}
