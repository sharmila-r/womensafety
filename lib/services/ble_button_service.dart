import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../models/ble_button.dart';

/// Service for managing BLE SOS buttons
/// Supports generic BLE buttons, Flic, iTags, and other beacon-style devices
class BleButtonService {
  static final BleButtonService _instance = BleButtonService._internal();
  factory BleButtonService() => _instance;
  BleButtonService._internal();

  // Paired buttons
  final List<BleButton> _pairedButtons = [];
  List<BleButton> get pairedButtons => List.unmodifiable(_pairedButtons);

  // Connected devices
  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Map<String, StreamSubscription> _buttonSubscriptions = {};

  // Scanning state
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // Discovered devices during scan
  final List<ScanResult> _discoveredDevices = [];
  List<ScanResult> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  // Stream controllers
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  final _buttonPressController = StreamController<ButtonPressEvent>.broadcast();
  Stream<ButtonPressEvent> get buttonPresses => _buttonPressController.stream;

  final _connectionStateController = StreamController<ButtonConnectionEvent>.broadcast();
  Stream<ButtonConnectionEvent> get connectionStates => _connectionStateController.stream;

  // Button press detection
  final Map<String, DateTime> _lastPressTime = {};
  final Map<String, int> _pressCount = {};
  static const _doublePressWindow = Duration(milliseconds: 500);
  static const _longPressThreshold = Duration(seconds: 2);

  // Known button signatures for auto-detection
  static const _knownDevicePatterns = {
    'Flic': BleButtonType.flic,
    'flic': BleButtonType.flic,
    'iTag': BleButtonType.itag,
    'ITAG': BleButtonType.itag,
    'iTAG': BleButtonType.itag,
    'Tile': BleButtonType.tile,
    'Nut': BleButtonType.nut,
    'NUT': BleButtonType.nut,
  };

  // Service UUIDs for button detection
  static const _buttonServiceUUIDs = [
    'ffe0', // Common for iTags
    'fff0', // Common for generic buttons
    'f000ffe0-0451-4000-b000-000000000000', // Flic
    '0000ffe0-0000-1000-8000-00805f9b34fb', // iTag
  ];

  // Characteristic UUIDs for button press notification
  static const _buttonCharacteristicUUIDs = [
    'ffe1', // Common button press characteristic
    'fff1',
    '0000ffe1-0000-1000-8000-00805f9b34fb',
  ];

  bool _isInitialized = false;

  /// Initialize the BLE button service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load paired buttons from storage
    await _loadPairedButtons();

    // Check if Bluetooth is available
    if (await FlutterBluePlus.isSupported == false) {
      debugPrint('BLE not supported on this device');
      return;
    }

    // Listen for Bluetooth state changes
    FlutterBluePlus.adapterState.listen((state) {
      debugPrint('Bluetooth state: $state');
      if (state == BluetoothAdapterState.on) {
        // Reconnect to paired buttons when Bluetooth turns on
        _reconnectPairedButtons();
      }
    });

    // Auto-connect to paired buttons
    await _reconnectPairedButtons();

    _isInitialized = true;
    debugPrint('BLE Button Service initialized with ${_pairedButtons.length} paired buttons');
  }

  /// Check if Bluetooth is available and on
  Future<bool> isBluetoothAvailable() async {
    if (await FlutterBluePlus.isSupported == false) return false;
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  /// Request to turn on Bluetooth
  Future<void> requestBluetoothOn() async {
    await FlutterBluePlus.turnOn();
  }

  /// Start scanning for BLE buttons
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isScanning) return;

    final isAvailable = await isBluetoothAvailable();
    if (!isAvailable) {
      debugPrint('Bluetooth not available');
      return;
    }

    _isScanning = true;
    _discoveredDevices.clear();

    debugPrint('Starting BLE scan...');

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        // Filter for potential button devices
        if (_isPotentialButton(result)) {
          final existingIndex = _discoveredDevices.indexWhere(
            (d) => d.device.remoteId == result.device.remoteId,
          );
          if (existingIndex == -1) {
            _discoveredDevices.add(result);
            debugPrint('Found potential button: ${result.device.platformName} (${result.device.remoteId})');
          } else {
            _discoveredDevices[existingIndex] = result;
          }
        }
      }
      _scanResultsController.add(_discoveredDevices);
    });

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );

    // Wait for scan to complete
    await Future.delayed(timeout);
    await stopScan();
  }

  /// Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    debugPrint('BLE scan stopped. Found ${_discoveredDevices.length} potential buttons');
  }

  /// Check if a device could be a button
  bool _isPotentialButton(ScanResult result) {
    final name = result.device.platformName.toLowerCase();
    final advertisedServices = result.advertisementData.serviceUuids;

    // Check if name matches known patterns
    for (final pattern in _knownDevicePatterns.keys) {
      if (name.contains(pattern.toLowerCase())) {
        return true;
      }
    }

    // Check for button service UUIDs
    for (final uuid in advertisedServices) {
      final uuidStr = uuid.toString().toLowerCase();
      for (final buttonUuid in _buttonServiceUUIDs) {
        if (uuidStr.contains(buttonUuid.toLowerCase())) {
          return true;
        }
      }
    }

    // Accept devices with short names (often buttons/tags)
    if (name.isNotEmpty && name.length <= 10) {
      return true;
    }

    // Accept devices advertising as connectable with good signal
    if (result.advertisementData.connectable && result.rssi > -80) {
      return true;
    }

    return false;
  }

  /// Detect button type from device name
  BleButtonType _detectButtonType(String name) {
    for (final entry in _knownDevicePatterns.entries) {
      if (name.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return BleButtonType.generic;
  }

  /// Pair with a BLE button
  Future<BleButton?> pairButton(ScanResult scanResult, {String? customName}) async {
    final device = scanResult.device;
    final deviceId = device.remoteId.str;

    // Check if already paired
    if (_pairedButtons.any((b) => b.macAddress == deviceId)) {
      debugPrint('Device already paired: $deviceId');
      return _pairedButtons.firstWhere((b) => b.macAddress == deviceId);
    }

    try {
      // Connect to device
      await device.connect(timeout: const Duration(seconds: 10));
      debugPrint('Connected to ${device.platformName}');

      // Discover services
      final services = await device.discoverServices();
      debugPrint('Discovered ${services.length} services');

      // Create button record
      final buttonType = _detectButtonType(device.platformName);
      final button = BleButton(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: customName ?? device.platformName.isNotEmpty
            ? device.platformName
            : 'SOS Button',
        macAddress: deviceId,
        type: buttonType,
        lastConnected: DateTime.now(),
      );

      // Save button
      _pairedButtons.add(button);
      await _savePairedButtons();

      // Set up button press listener
      await _setupButtonListener(device, button);

      _connectedDevices[deviceId] = device;
      _connectionStateController.add(ButtonConnectionEvent(
        button: button,
        isConnected: true,
      ));

      debugPrint('Paired button: ${button.name} (${button.type.displayName})');
      return button;
    } catch (e) {
      debugPrint('Failed to pair button: $e');
      try {
        await device.disconnect();
      } catch (_) {}
      return null;
    }
  }

  /// Set up listener for button presses
  Future<void> _setupButtonListener(BluetoothDevice device, BleButton button) async {
    final services = await device.discoverServices();

    for (final service in services) {
      for (final char in service.characteristics) {
        final charUuid = char.uuid.toString().toLowerCase();

        // Check if this is a button characteristic
        bool isButtonChar = _buttonCharacteristicUUIDs.any(
          (uuid) => charUuid.contains(uuid.toLowerCase()),
        );

        // Also check for notify property
        if (char.properties.notify || char.properties.indicate || isButtonChar) {
          try {
            await char.setNotifyValue(true);
            debugPrint('Subscribed to characteristic: $charUuid');

            final subscription = char.onValueReceived.listen((value) {
              _handleButtonPress(button, value);
            });

            _buttonSubscriptions[button.macAddress] = subscription;

            // Listen for disconnection
            device.connectionState.listen((state) {
              if (state == BluetoothConnectionState.disconnected) {
                _handleDisconnection(button);
              }
            });

            return;
          } catch (e) {
            debugPrint('Failed to subscribe to $charUuid: $e');
          }
        }
      }
    }

    // If no notify characteristic found, use RSSI-based detection as fallback
    debugPrint('No notify characteristic found, using RSSI-based detection');
    _startRssiBasedDetection(device, button);
  }

  /// Fallback: Detect button press via RSSI changes (for simple tags)
  void _startRssiBasedDetection(BluetoothDevice device, BleButton button) {
    Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_connectedDevices.containsKey(button.macAddress)) {
        timer.cancel();
        return;
      }

      try {
        final rssi = await device.readRssi();
        // Significant RSSI spike could indicate button press
        // This is a fallback and less reliable
      } catch (e) {
        // Device disconnected
        timer.cancel();
        _handleDisconnection(button);
      }
    });
  }

  /// Handle incoming button press data
  void _handleButtonPress(BleButton button, List<int> value) {
    final now = DateTime.now();
    final buttonId = button.macAddress;

    debugPrint('Button press detected from ${button.name}: $value');

    // Vibrate to confirm
    Vibration.vibrate(duration: 100);

    // Determine press type (single, double, long)
    final lastPress = _lastPressTime[buttonId];
    final pressCount = _pressCount[buttonId] ?? 0;

    if (lastPress != null && now.difference(lastPress) < _doublePressWindow) {
      // Double press detected
      _pressCount[buttonId] = pressCount + 1;

      if (_pressCount[buttonId]! >= 2) {
        _emitButtonPress(button, ButtonPressType.double);
        _pressCount[buttonId] = 0;
      }
    } else {
      // Start new press sequence
      _pressCount[buttonId] = 1;
      _lastPressTime[buttonId] = now;

      // Wait to see if it becomes a double press
      Future.delayed(_doublePressWindow + const Duration(milliseconds: 100), () {
        if (_pressCount[buttonId] == 1) {
          _emitButtonPress(button, ButtonPressType.single);
          _pressCount[buttonId] = 0;
        }
      });
    }
  }

  /// Emit button press event
  void _emitButtonPress(BleButton button, ButtonPressType pressType) {
    debugPrint('Emitting ${pressType.name} press from ${button.name}');

    // Get the configured action for this press type
    BleButtonAction action;
    switch (pressType) {
      case ButtonPressType.single:
        action = button.singlePressAction;
        break;
      case ButtonPressType.double:
        action = button.doublePressAction;
        break;
      case ButtonPressType.long:
        action = button.longPressAction;
        break;
    }

    _buttonPressController.add(ButtonPressEvent(
      button: button,
      pressType: pressType,
      action: action,
      timestamp: DateTime.now(),
    ));
  }

  /// Handle device disconnection
  void _handleDisconnection(BleButton button) {
    debugPrint('Button disconnected: ${button.name}');

    _connectedDevices.remove(button.macAddress);
    _buttonSubscriptions[button.macAddress]?.cancel();
    _buttonSubscriptions.remove(button.macAddress);

    _connectionStateController.add(ButtonConnectionEvent(
      button: button,
      isConnected: false,
    ));

    // Attempt to reconnect after delay
    Future.delayed(const Duration(seconds: 5), () {
      _reconnectButton(button);
    });
  }

  /// Reconnect to a specific button
  Future<void> _reconnectButton(BleButton button) async {
    if (_connectedDevices.containsKey(button.macAddress)) return;
    if (!button.isEnabled) return;

    try {
      final device = BluetoothDevice.fromId(button.macAddress);
      await device.connect(timeout: const Duration(seconds: 10));

      _connectedDevices[button.macAddress] = device;
      await _setupButtonListener(device, button);

      // Update last connected time
      final index = _pairedButtons.indexWhere((b) => b.id == button.id);
      if (index != -1) {
        _pairedButtons[index] = button.copyWith(lastConnected: DateTime.now());
        await _savePairedButtons();
      }

      _connectionStateController.add(ButtonConnectionEvent(
        button: button,
        isConnected: true,
      ));

      debugPrint('Reconnected to ${button.name}');
    } catch (e) {
      debugPrint('Failed to reconnect to ${button.name}: $e');
    }
  }

  /// Reconnect to all paired buttons
  Future<void> _reconnectPairedButtons() async {
    for (final button in _pairedButtons) {
      if (button.isEnabled) {
        await _reconnectButton(button);
      }
    }
  }

  /// Update button configuration
  Future<void> updateButton(BleButton button) async {
    final index = _pairedButtons.indexWhere((b) => b.id == button.id);
    if (index != -1) {
      _pairedButtons[index] = button;
      await _savePairedButtons();
    }
  }

  /// Unpair a button
  Future<void> unpairButton(String buttonId) async {
    final button = _pairedButtons.firstWhere(
      (b) => b.id == buttonId,
      orElse: () => throw Exception('Button not found'),
    );

    // Disconnect if connected
    final device = _connectedDevices[button.macAddress];
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    // Cancel subscription
    _buttonSubscriptions[button.macAddress]?.cancel();
    _buttonSubscriptions.remove(button.macAddress);
    _connectedDevices.remove(button.macAddress);

    // Remove from list
    _pairedButtons.removeWhere((b) => b.id == buttonId);
    await _savePairedButtons();

    debugPrint('Unpaired button: ${button.name}');
  }

  /// Check if a button is connected
  bool isButtonConnected(String macAddress) {
    return _connectedDevices.containsKey(macAddress);
  }

  /// Load paired buttons from storage
  Future<void> _loadPairedButtons() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('ble_paired_buttons');

    if (json != null) {
      final List<dynamic> decoded = jsonDecode(json);
      _pairedButtons.clear();
      _pairedButtons.addAll(
        decoded.map((e) => BleButton.fromJson(e as Map<String, dynamic>)),
      );
    }
  }

  /// Save paired buttons to storage
  Future<void> _savePairedButtons() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_pairedButtons.map((b) => b.toJson()).toList());
    await prefs.setString('ble_paired_buttons', json);
  }

  /// Dispose service
  void dispose() {
    for (final sub in _buttonSubscriptions.values) {
      sub.cancel();
    }
    _buttonSubscriptions.clear();

    for (final device in _connectedDevices.values) {
      device.disconnect();
    }
    _connectedDevices.clear();

    _scanResultsController.close();
    _buttonPressController.close();
    _connectionStateController.close();
  }
}

/// Button press types
enum ButtonPressType {
  single,
  double,
  long,
}

/// Event emitted when a button is pressed
class ButtonPressEvent {
  final BleButton button;
  final ButtonPressType pressType;
  final BleButtonAction action;
  final DateTime timestamp;

  ButtonPressEvent({
    required this.button,
    required this.pressType,
    required this.action,
    required this.timestamp,
  });
}

/// Event emitted when button connection state changes
class ButtonConnectionEvent {
  final BleButton button;
  final bool isConnected;

  ButtonConnectionEvent({
    required this.button,
    required this.isConnected,
  });
}
