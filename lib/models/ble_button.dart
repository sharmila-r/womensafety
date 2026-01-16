/// BLE Button Model for SOS panic buttons
class BleButton {
  final String id;
  final String name;
  final String macAddress;
  final BleButtonType type;
  final BleButtonAction singlePressAction;
  final BleButtonAction doublePressAction;
  final BleButtonAction longPressAction;
  final DateTime? lastConnected;
  final int? batteryLevel;
  final bool isEnabled;

  BleButton({
    required this.id,
    required this.name,
    required this.macAddress,
    this.type = BleButtonType.generic,
    this.singlePressAction = BleButtonAction.checkIn,
    this.doublePressAction = BleButtonAction.shareLocation,
    this.longPressAction = BleButtonAction.triggerSOS,
    this.lastConnected,
    this.batteryLevel,
    this.isEnabled = true,
  });

  factory BleButton.fromJson(Map<String, dynamic> json) {
    return BleButton(
      id: json['id'] as String,
      name: json['name'] as String,
      macAddress: json['macAddress'] as String,
      type: BleButtonType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BleButtonType.generic,
      ),
      singlePressAction: BleButtonAction.values.firstWhere(
        (e) => e.name == json['singlePressAction'],
        orElse: () => BleButtonAction.checkIn,
      ),
      doublePressAction: BleButtonAction.values.firstWhere(
        (e) => e.name == json['doublePressAction'],
        orElse: () => BleButtonAction.shareLocation,
      ),
      longPressAction: BleButtonAction.values.firstWhere(
        (e) => e.name == json['longPressAction'],
        orElse: () => BleButtonAction.triggerSOS,
      ),
      lastConnected: json['lastConnected'] != null
          ? DateTime.parse(json['lastConnected'] as String)
          : null,
      batteryLevel: json['batteryLevel'] as int?,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'macAddress': macAddress,
      'type': type.name,
      'singlePressAction': singlePressAction.name,
      'doublePressAction': doublePressAction.name,
      'longPressAction': longPressAction.name,
      'lastConnected': lastConnected?.toIso8601String(),
      'batteryLevel': batteryLevel,
      'isEnabled': isEnabled,
    };
  }

  BleButton copyWith({
    String? id,
    String? name,
    String? macAddress,
    BleButtonType? type,
    BleButtonAction? singlePressAction,
    BleButtonAction? doublePressAction,
    BleButtonAction? longPressAction,
    DateTime? lastConnected,
    int? batteryLevel,
    bool? isEnabled,
  }) {
    return BleButton(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      type: type ?? this.type,
      singlePressAction: singlePressAction ?? this.singlePressAction,
      doublePressAction: doublePressAction ?? this.doublePressAction,
      longPressAction: longPressAction ?? this.longPressAction,
      lastConnected: lastConnected ?? this.lastConnected,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// Types of BLE buttons supported
enum BleButtonType {
  generic,    // Any BLE button/beacon
  flic,       // Flic 2 button
  itag,       // iTag finder/button
  tile,       // Tile tracker
  nut,        // Nut finder
  custom,     // Custom BLE device
}

/// Actions that can be triggered by button presses
enum BleButtonAction {
  none,           // Do nothing
  checkIn,        // Send "I'm safe" notification
  shareLocation,  // Share current location with contacts
  triggerSOS,     // Full SOS alert
  callEmergency,  // Call emergency number
  startRecording, // Start audio/video recording
}

/// Extension for button type display names and icons
extension BleButtonTypeExtension on BleButtonType {
  String get displayName {
    switch (this) {
      case BleButtonType.generic:
        return 'Generic BLE Button';
      case BleButtonType.flic:
        return 'Flic Button';
      case BleButtonType.itag:
        return 'iTag';
      case BleButtonType.tile:
        return 'Tile';
      case BleButtonType.nut:
        return 'Nut Finder';
      case BleButtonType.custom:
        return 'Custom Device';
    }
  }
}

/// Extension for action display names
extension BleButtonActionExtension on BleButtonAction {
  String get displayName {
    switch (this) {
      case BleButtonAction.none:
        return 'Do Nothing';
      case BleButtonAction.checkIn:
        return 'Check-in (I\'m Safe)';
      case BleButtonAction.shareLocation:
        return 'Share Location';
      case BleButtonAction.triggerSOS:
        return 'Trigger SOS Alert';
      case BleButtonAction.callEmergency:
        return 'Call Emergency';
      case BleButtonAction.startRecording:
        return 'Start Recording';
    }
  }

  String get description {
    switch (this) {
      case BleButtonAction.none:
        return 'Button press will be ignored';
      case BleButtonAction.checkIn:
        return 'Send a quick "I\'m safe" message to contacts';
      case BleButtonAction.shareLocation:
        return 'Share your current location with trusted contacts';
      case BleButtonAction.triggerSOS:
        return 'Send emergency SOS alert with location';
      case BleButtonAction.callEmergency:
        return 'Automatically call emergency services';
      case BleButtonAction.startRecording:
        return 'Start recording audio evidence';
    }
  }
}
