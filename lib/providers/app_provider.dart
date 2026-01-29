import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../models/trusted_contact.dart';
import '../models/harassment_report.dart';
import '../models/escort_request.dart';
import '../models/ble_button.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';
import '../services/push_notification_service.dart';
import '../services/firebase_service.dart';
import '../services/ble_button_service.dart';
import '../services/connectivity_service.dart';
import '../services/evidence_recording_service.dart';
import '../services/volunteer_service.dart';
import '../config/country_config.dart';

class AppProvider extends ChangeNotifier {
  List<TrustedContact> _trustedContacts = [];
  List<HarassmentReport> _reports = [];
  List<EscortRequest> _escortRequests = [];
  Position? _currentPosition;
  String _currentAddress = '';
  bool _isLocationSharing = false;
  bool _isSOSActive = false;
  int _stationaryAlertMinutes = 30;
  bool _autoAlertEnabled = false;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _stationaryTimer;
  Position? _lastKnownPosition;

  // Localization
  Locale _locale = const Locale('en');

  // BLE Button Service
  final BleButtonService _bleButtonService = BleButtonService();
  StreamSubscription<ButtonPressEvent>? _buttonPressSubscription;

  // Connectivity Service (for offline SMS fallback)
  final ConnectivityService _connectivityService = ConnectivityService();

  // Evidence Recording Service
  final EvidenceRecordingService _recordingService = EvidenceRecordingService();
  bool _isRecording = false;

  // Volunteer Service
  final VolunteerService _volunteerService = VolunteerService();

  // SOS Settings
  bool _alertNearbyVolunteers = true;
  String? _duressCode; // Fake cancel PIN that sends silent SOS
  String? _realCancelCode; // Real cancel PIN

  // Getters
  List<TrustedContact> get trustedContacts => _trustedContacts;
  List<TrustedContact> get emergencyContacts =>
      _trustedContacts.where((c) => c.isEmergencyContact).toList();
  List<HarassmentReport> get reports => _reports;
  List<EscortRequest> get escortRequests => _escortRequests;
  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  bool get isLocationSharing => _isLocationSharing;
  bool get isSOSActive => _isSOSActive;
  int get stationaryAlertMinutes => _stationaryAlertMinutes;
  bool get autoAlertEnabled => _autoAlertEnabled;

  // Country config getters (auto-detected from GPS)
  String get emergencyNumber => CountryConfigManager().emergencyNumber;
  String get detectedCountryCode => CountryConfigManager().detectedCountryCode ?? 'US';
  String get countryName => CountryConfigManager().current.countryName;

  // Connectivity getters
  bool get isOnline => _connectivityService.isOnline;
  bool get isOffline => _connectivityService.isOffline;

  // Recording getters
  bool get isRecording => _isRecording;
  EvidenceRecordingService get recordingService => _recordingService;

  // Volunteer and SOS settings getters
  bool get alertNearbyVolunteers => _alertNearbyVolunteers;
  bool get hasDuressCode => _duressCode != null && _duressCode!.isNotEmpty;
  bool get hasRealCancelCode => _realCancelCode != null && _realCancelCode!.isNotEmpty;
  VolunteerService get volunteerService => _volunteerService;

  // Localization getters
  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  AppProvider() {
    _loadData();
    _initLocation();
    _initBleButtons();
    _initServices();
  }

  /// Initialize connectivity and recording services
  Future<void> _initServices() async {
    await _connectivityService.initialize();
    await _recordingService.initialize();
  }

  /// Initialize BLE button service and listen for button presses
  Future<void> _initBleButtons() async {
    await _bleButtonService.initialize();

    // Listen for button presses
    _buttonPressSubscription = _bleButtonService.buttonPresses.listen(
      _handleButtonPress,
    );
  }

  /// Handle button press events from BLE buttons
  Future<void> _handleButtonPress(ButtonPressEvent event) async {
    debugPrint('BLE Button pressed: ${event.button.name} - ${event.pressType.name} - ${event.action.name}');

    // Vibrate to confirm button press received
    await Vibration.vibrate(duration: 200, amplitude: 255);

    switch (event.action) {
      case BleButtonAction.none:
        // Do nothing
        break;

      case BleButtonAction.checkIn:
        await _sendCheckIn();
        break;

      case BleButtonAction.shareLocation:
        await shareCurrentLocation();
        break;

      case BleButtonAction.triggerSOS:
        await triggerSOS(customMessage: 'SOS triggered via panic button');
        break;

      case BleButtonAction.callEmergency:
        await SmsService.callEmergencyNumber();
        break;

      case BleButtonAction.startRecording:
        await toggleAudioRecording();
        break;
    }
  }

  /// Send a check-in message to contacts
  Future<void> _sendCheckIn() async {
    await updateCurrentLocation();

    if (_trustedContacts.isEmpty) {
      debugPrint('No contacts to send check-in to');
      return;
    }

    final phones = _trustedContacts.map((c) => c.phone).toList();

    // Send SMS check-in
    await SmsService.shareLocation(
      phoneNumbers: phones,
      latitude: _currentPosition?.latitude ?? 0,
      longitude: _currentPosition?.longitude ?? 0,
      address: _currentAddress,
      isCheckIn: true,
    );

    // Also send push notification
    try {
      final currentUser = FirebaseService.instance.currentUser;
      final userName = currentUser?.displayName ?? 'Someone';

      await PushNotificationService().sendSOSAlertToContacts(
        senderName: userName,
        senderPhone: currentUser?.phoneNumber ?? '',
        latitude: _currentPosition?.latitude ?? 0,
        longitude: _currentPosition?.longitude ?? 0,
        address: _currentAddress,
        contactPhones: phones,
        message: '$userName checked in: I\'m safe at $_currentAddress',
      );
    } catch (e) {
      debugPrint('Failed to send check-in notification: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load trusted contacts
      final contactsJson = prefs.getString('trustedContacts');
      if (contactsJson != null) {
        final List<dynamic> decoded = jsonDecode(contactsJson);
        _trustedContacts =
            decoded.map((e) => TrustedContact.fromJson(e)).toList();
      }

      // Load reports
      final reportsJson = prefs.getString('reports');
      if (reportsJson != null) {
        final List<dynamic> decoded = jsonDecode(reportsJson);
        _reports = decoded.map((e) => HarassmentReport.fromJson(e)).toList();
      }

      // Load settings
      _stationaryAlertMinutes = prefs.getInt('stationaryAlertMinutes') ?? 30;
      _autoAlertEnabled = prefs.getBool('autoAlertEnabled') ?? false;
      _alertNearbyVolunteers = prefs.getBool('alertNearbyVolunteers') ?? true;
      _duressCode = prefs.getString('duressCode');
      _realCancelCode = prefs.getString('realCancelCode');

      // Load locale
      final savedLocale = prefs.getString('locale');
      if (savedLocale != null) {
        _locale = Locale(savedLocale);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('AppProvider load error: $e');
    }
  }

  // ==================== LOCALIZATION ====================

  /// Set the app locale (language)
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    notifyListeners();
  }

  /// Set locale by language code
  Future<void> setLanguage(String languageCode) async {
    await setLocale(Locale(languageCode));
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_trustedContacts.map((c) => c.toJson()).toList());
    await prefs.setString('trustedContacts', json);
  }

  Future<void> _saveReports() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_reports.map((r) => r.toJson()).toList());
    await prefs.setString('reports', json);
  }

  Future<void> _initLocation() async {
    await updateCurrentLocation();

    // Auto-detect country from GPS for correct emergency numbers
    if (_currentPosition != null) {
      await CountryConfigManager().detectCountryFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      notifyListeners();
    }
  }

  Future<void> updateCurrentLocation() async {
    _currentPosition = await LocationService.getCurrentLocation();
    if (_currentPosition != null) {
      _currentAddress = await LocationService.getAddressFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }
    notifyListeners();
  }

  // Trusted Contacts Management
  Future<void> addTrustedContact(TrustedContact contact) async {
    _trustedContacts.add(contact);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> removeTrustedContact(String id) async {
    _trustedContacts.removeWhere((c) => c.id == id);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> updateTrustedContact(TrustedContact contact) async {
    final index = _trustedContacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      _trustedContacts[index] = contact;
      await _saveContacts();
      notifyListeners();
    }
  }

  // SOS Feature with offline SMS fallback and volunteer alerts
  Future<SOSResult> triggerSOS({
    String? customMessage,
    bool autoRecord = false,
    bool silent = false, // For duress code - no UI feedback
  }) async {
    _isSOSActive = true;
    if (!silent) notifyListeners();

    await updateCurrentLocation();

    SOSResult result = SOSResult();

    if (_currentPosition == null) {
      debugPrint('SOS: No location available');
      return result;
    }

    final currentUser = FirebaseService.instance.currentUser;
    final userName = currentUser?.displayName ?? 'Someone';
    final userPhone = currentUser?.phoneNumber ?? '';

    // Send to emergency contacts if any
    if (emergencyContacts.isNotEmpty) {
      final phones = emergencyContacts.map((c) => c.phone).toList();

      // Use connectivity service for automatic offline fallback
      result = await _connectivityService.sendSOSWithFallback(
        senderName: userName,
        senderPhone: userPhone,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _currentAddress,
        contactPhones: phones,
        message: customMessage,
      );

      debugPrint('SOS to contacts: ${result.statusMessage}');
    }

    // Alert nearby volunteers if enabled (independent of emergency contacts)
    if (_alertNearbyVolunteers) {
      try {
        final volunteerResult = await _volunteerService.alertNearbyVolunteers(
          senderName: userName,
          senderPhone: userPhone,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          address: _currentAddress,
          message: customMessage,
        );
        debugPrint('Volunteer Alert: ${volunteerResult.statusMessage}');

        // Update result with volunteer info
        if (volunteerResult.success) {
          result.volunteersAlerted = volunteerResult.volunteersAlerted;
        }
      } catch (e) {
        debugPrint('Failed to alert volunteers: $e');
      }
    }

    // Auto-start audio recording if enabled
    if (autoRecord && !_isRecording) {
      await startAudioRecording();
    }

    // For silent SOS (duress code), don't show as active
    if (silent) {
      _isSOSActive = false;
    }

    return result;
  }

  // ==================== DURESS CODE ====================

  /// Set up duress code (fake cancel PIN that sends silent SOS)
  Future<void> setDuressCode(String code) async {
    _duressCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('duressCode', code);
    notifyListeners();
  }

  /// Set up real cancel code
  Future<void> setRealCancelCode(String code) async {
    _realCancelCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('realCancelCode', code);
    notifyListeners();
  }

  /// Clear duress and cancel codes
  Future<void> clearSecurityCodes() async {
    _duressCode = null;
    _realCancelCode = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('duressCode');
    await prefs.remove('realCancelCode');
    notifyListeners();
  }

  /// Verify cancel code - returns true if real cancel, triggers silent SOS if duress
  Future<bool> verifyCancelCode(String code) async {
    // Check if it's the duress code (fake cancel)
    if (_duressCode != null && code == _duressCode) {
      // Trigger silent SOS - looks like cancel but actually sends SOS
      await triggerSOS(
        customMessage: 'DURESS ALERT: User entered duress code. They may be in danger and being forced to cancel.',
        silent: true,
        autoRecord: true, // Auto-record in duress situations
      );
      debugPrint('Duress code entered - silent SOS triggered');
      return true; // Return true so it looks like a real cancel
    }

    // Check if it's the real cancel code
    if (_realCancelCode != null && code == _realCancelCode) {
      return true; // Real cancel
    }

    // If no codes are set, any code works (or implement other logic)
    if (_realCancelCode == null) {
      return true;
    }

    return false; // Wrong code
  }

  // ==================== SOS SETTINGS ====================

  /// Enable/disable nearby volunteer alerts
  Future<void> setAlertNearbyVolunteers(bool enabled) async {
    _alertNearbyVolunteers = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alertNearbyVolunteers', enabled);
    notifyListeners();
  }

  // ==================== AUDIO/VIDEO RECORDING ====================

  /// Start audio recording
  Future<bool> startAudioRecording() async {
    final success = await _recordingService.startAudioRecording();
    if (success) {
      _isRecording = true;
      notifyListeners();
    }
    return success;
  }

  /// Stop audio recording
  Future<EvidenceRecording?> stopAudioRecording() async {
    final recording = await _recordingService.stopAudioRecording();
    _isRecording = false;
    notifyListeners();
    return recording;
  }

  /// Toggle audio recording
  Future<void> toggleAudioRecording() async {
    if (_isRecording) {
      await stopAudioRecording();
      await Vibration.vibrate(duration: 100, amplitude: 128);
    } else {
      final success = await startAudioRecording();
      if (success) {
        await Vibration.vibrate(duration: 300, amplitude: 255);
      }
    }
  }

  /// Start video recording
  Future<bool> startVideoRecording() async {
    final success = await _recordingService.startVideoRecording();
    if (success) {
      _isRecording = true;
      notifyListeners();
    }
    return success;
  }

  /// Stop video recording
  Future<EvidenceRecording?> stopVideoRecording() async {
    final recording = await _recordingService.stopVideoRecording();
    _isRecording = false;
    notifyListeners();
    return recording;
  }

  void deactivateSOS() {
    _isSOSActive = false;
    notifyListeners();
  }

  // Location Sharing
  void startLocationSharing() {
    _isLocationSharing = true;
    _locationSubscription = LocationService.getLocationStream().listen(
      (Position position) async {
        _currentPosition = position;
        _currentAddress = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        notifyListeners();
      },
    );
    notifyListeners();
  }

  void stopLocationSharing() {
    _isLocationSharing = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    notifyListeners();
  }

  Future<void> shareCurrentLocation() async {
    await updateCurrentLocation();
    if (_currentPosition != null && _trustedContacts.isNotEmpty) {
      final phones = _trustedContacts.map((c) => c.phone).toList();
      await SmsService.shareLocation(
        phoneNumbers: phones,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _currentAddress,
      );
    }
  }

  // Harassment Reports
  Future<void> addReport(HarassmentReport report) async {
    _reports.insert(0, report);
    await _saveReports();
    notifyListeners();
  }

  // Escort Requests
  void addEscortRequest(EscortRequest request) {
    _escortRequests.insert(0, request);
    notifyListeners();
  }

  // Auto-alert for stationary phone
  void setStationaryAlertMinutes(int minutes) async {
    _stationaryAlertMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('stationaryAlertMinutes', minutes);
    notifyListeners();
  }

  void setAutoAlertEnabled(bool enabled) async {
    _autoAlertEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoAlertEnabled', enabled);

    if (enabled) {
      _startStationaryMonitoring();
    } else {
      _stopStationaryMonitoring();
    }
    notifyListeners();
  }

  void _startStationaryMonitoring() {
    _lastKnownPosition = _currentPosition;
    _stationaryTimer?.cancel();
    _stationaryTimer = Timer.periodic(
      Duration(minutes: _stationaryAlertMinutes),
      (timer) async {
        await updateCurrentLocation();
        if (_currentPosition != null && _lastKnownPosition != null) {
          final distance = LocationService.calculateDistance(
            _lastKnownPosition!.latitude,
            _lastKnownPosition!.longitude,
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );

          // If moved less than 50 meters in the alert period
          if (distance < 50) {
            await triggerSOS();
          }
        }
        _lastKnownPosition = _currentPosition;
      },
    );
  }

  void _stopStationaryMonitoring() {
    _stationaryTimer?.cancel();
    _stationaryTimer = null;
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _stationaryTimer?.cancel();
    _buttonPressSubscription?.cancel();
    super.dispose();
  }
}
