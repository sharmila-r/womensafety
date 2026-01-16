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

  // BLE Button Service
  final BleButtonService _bleButtonService = BleButtonService();
  StreamSubscription<ButtonPressEvent>? _buttonPressSubscription;

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

  AppProvider() {
    _loadData();
    _initLocation();
    _initBleButtons();
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
        // TODO: Implement audio recording
        debugPrint('Audio recording not yet implemented');
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

    notifyListeners();
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

  // SOS Feature
  Future<void> triggerSOS({String? customMessage}) async {
    _isSOSActive = true;
    notifyListeners();

    await updateCurrentLocation();

    if (_currentPosition != null && emergencyContacts.isNotEmpty) {
      final phones = emergencyContacts.map((c) => c.phone).toList();

      // Send SMS (fallback for contacts without app)
      await SmsService.sendEmergencySMS(
        phoneNumbers: phones,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _currentAddress,
      );

      // Send push notifications to contacts who have the app
      try {
        final currentUser = FirebaseService.instance.currentUser;
        final userName = currentUser?.displayName ?? 'Someone';
        final userPhone = currentUser?.phoneNumber ?? '';

        await PushNotificationService().sendSOSAlertToContacts(
          senderName: userName,
          senderPhone: userPhone,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          address: _currentAddress,
          contactPhones: phones,
          message: customMessage,
        );
      } catch (e) {
        // Push notification failed, but SMS was already sent
        debugPrint('Push notification failed: $e');
      }
    }
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
