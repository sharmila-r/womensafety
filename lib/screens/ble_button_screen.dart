import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/ble_button.dart';
import '../services/ble_button_service.dart';

/// Screen for managing BLE SOS buttons
class BleButtonScreen extends StatefulWidget {
  const BleButtonScreen({super.key});

  @override
  State<BleButtonScreen> createState() => _BleButtonScreenState();
}

class _BleButtonScreenState extends State<BleButtonScreen> {
  final _bleService = BleButtonService();

  bool _isScanning = false;
  bool _bluetoothAvailable = false;
  List<ScanResult> _discoveredDevices = [];
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initBle();
  }

  Future<void> _initBle() async {
    await _bleService.initialize();

    _bluetoothAvailable = await _bleService.isBluetoothAvailable();
    setState(() {});

    _scanSubscription = _bleService.scanResults.listen((results) {
      setState(() {
        _discoveredDevices = results;
      });
    });

    _connectionSubscription = _bleService.connectionStates.listen((event) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            event.isConnected
                ? '${event.button.name} connected'
                : '${event.button.name} disconnected',
          ),
          backgroundColor: event.isConnected ? Colors.green : Colors.orange,
        ),
      );
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (!_bluetoothAvailable) {
      await _bleService.requestBluetoothOn();
      _bluetoothAvailable = await _bleService.isBluetoothAvailable();
      if (!_bluetoothAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable Bluetooth'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _discoveredDevices = [];
    });

    await _bleService.startScan(timeout: const Duration(seconds: 15));

    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _pairDevice(ScanResult result) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Pairing...'),
          ],
        ),
      ),
    );

    final button = await _bleService.pairButton(result);
    Navigator.pop(context);

    if (button != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${button.name} paired successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Open configuration
        _showButtonConfig(button);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pair device'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() {});
  }

  void _showButtonConfig(BleButton button) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BleButtonConfigScreen(button: button),
      ),
    ).then((_) => setState(() {}));
  }

  Future<void> _unpairButton(BleButton button) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Button'),
        content: Text('Remove ${button.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _bleService.unpairButton(button.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairedButtons = _bleService.pairedButtons;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Buttons'),
        actions: [
          IconButton(
            onPressed: _startScan,
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.bluetooth_searching),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Card(
              color: const Color(0xFFFCE4EC),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.touch_app,
                        color: Color(0xFFE91E63),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wearable SOS Button',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Connect a Bluetooth button to trigger SOS alerts discreetly without using your phone',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Paired buttons section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Paired Buttons',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${pairedButtons.length} device(s)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (pairedButtons.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bluetooth_disabled,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No buttons paired',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the scan button to find nearby BLE buttons',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...pairedButtons.map((button) => _buildPairedButtonCard(button)),

            const SizedBox(height: 24),

            // Available devices section (when scanning)
            if (_isScanning || _discoveredDevices.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Devices',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isScanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_discoveredDevices.isEmpty && _isScanning)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Scanning for devices...'),
                    ),
                  ),
                )
              else
                ..._discoveredDevices
                    .where((d) => !pairedButtons.any(
                        (b) => b.macAddress == d.device.remoteId.str))
                    .map((result) => _buildDiscoveredDeviceCard(result)),
            ],

            const SizedBox(height: 24),

            // Supported devices info
            const Text(
              'Supported Devices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSupportedDevicesCard(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startScan,
        backgroundColor: const Color(0xFFE91E63),
        icon: const Icon(Icons.bluetooth_searching),
        label: Text(_isScanning ? 'Scanning...' : 'Scan for Buttons'),
      ),
    );
  }

  Widget _buildPairedButtonCard(BleButton button) {
    final isConnected = _bleService.isButtonConnected(button.macAddress);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getButtonIcon(button.type),
                color: isConnected ? Colors.green : Colors.grey,
              ),
            ),
            if (isConnected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          button.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              button.type.displayName,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildActionChip('1x', button.singlePressAction),
                const SizedBox(width: 4),
                _buildActionChip('2x', button.doublePressAction),
                const SizedBox(width: 4),
                _buildActionChip('Hold', button.longPressAction),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'configure',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20),
                  SizedBox(width: 8),
                  Text('Configure'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'unpair',
              child: Row(
                children: [
                  Icon(Icons.link_off, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Unpair', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'configure') {
              _showButtonConfig(button);
            } else if (value == 'unpair') {
              _unpairButton(button);
            }
          },
        ),
        onTap: () => _showButtonConfig(button),
      ),
    );
  }

  Widget _buildActionChip(String label, BleButtonAction action) {
    Color chipColor;
    switch (action) {
      case BleButtonAction.triggerSOS:
        chipColor = Colors.red;
        break;
      case BleButtonAction.shareLocation:
        chipColor = Colors.orange;
        break;
      case BleButtonAction.checkIn:
        chipColor = Colors.green;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: chipColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDiscoveredDeviceCard(ScanResult result) {
    final device = result.device;
    final name = device.platformName.isNotEmpty ? device.platformName : 'Unknown Device';
    final rssi = result.rssi;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE91E63).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.bluetooth,
            color: Color(0xFFE91E63),
          ),
        ),
        title: Text(name),
        subtitle: Text(
          'Signal: ${_getRssiStrength(rssi)} (${rssi}dBm)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: ElevatedButton(
          onPressed: () => _pairDevice(result),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E63),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Pair'),
        ),
      ),
    );
  }

  Widget _buildSupportedDevicesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSupportedDevice('Flic 2 Button', 'Best for custom integration', Icons.radio_button_checked),
            const Divider(),
            _buildSupportedDevice('iTag / Anti-Lost', 'Budget option (~Rs.200)', Icons.sell),
            const Divider(),
            _buildSupportedDevice('Tile / Nut Finder', 'Keychain trackers', Icons.key),
            const Divider(),
            _buildSupportedDevice('Generic BLE Button', 'Any Bluetooth button', Icons.bluetooth),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportedDevice(String name, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE91E63), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getButtonIcon(BleButtonType type) {
    switch (type) {
      case BleButtonType.flic:
        return Icons.radio_button_checked;
      case BleButtonType.itag:
        return Icons.sell;
      case BleButtonType.tile:
      case BleButtonType.nut:
        return Icons.key;
      default:
        return Icons.touch_app;
    }
  }

  String _getRssiStrength(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }
}

/// Screen for configuring a paired button
class BleButtonConfigScreen extends StatefulWidget {
  final BleButton button;

  const BleButtonConfigScreen({super.key, required this.button});

  @override
  State<BleButtonConfigScreen> createState() => _BleButtonConfigScreenState();
}

class _BleButtonConfigScreenState extends State<BleButtonConfigScreen> {
  final _bleService = BleButtonService();
  late BleButton _button;

  @override
  void initState() {
    super.initState();
    _button = widget.button;
  }

  Future<void> _saveChanges() async {
    await _bleService.updateButton(_button);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Button configuration saved'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _bleService.isButtonConnected(_button.macAddress);

    return Scaffold(
      appBar: AppBar(
        title: Text(_button.name),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status card
            Card(
              color: isConnected ? Colors.green[50] : Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: isConnected ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: isConnected ? Colors.green[700] : Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Button name
            const Text(
              'Button Name',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _button.name,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter button name',
              ),
              onChanged: (value) {
                setState(() {
                  _button = _button.copyWith(name: value);
                });
              },
            ),

            const SizedBox(height: 24),

            // Enable/disable toggle
            SwitchListTile(
              title: const Text('Button Enabled'),
              subtitle: const Text('Listen for button presses'),
              value: _button.isEnabled,
              onChanged: (value) {
                setState(() {
                  _button = _button.copyWith(isEnabled: value);
                });
              },
            ),

            const Divider(height: 32),

            // Action configuration
            const Text(
              'Button Actions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure what happens when you press the button',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 16),

            // Single press
            _buildActionSelector(
              'Single Press (1x)',
              'Quick tap',
              _button.singlePressAction,
              (action) => setState(() {
                _button = _button.copyWith(singlePressAction: action);
              }),
            ),

            const SizedBox(height: 12),

            // Double press
            _buildActionSelector(
              'Double Press (2x)',
              'Two quick taps',
              _button.doublePressAction,
              (action) => setState(() {
                _button = _button.copyWith(doublePressAction: action);
              }),
            ),

            const SizedBox(height: 12),

            // Long press
            _buildActionSelector(
              'Long Press (2+ sec)',
              'Press and hold',
              _button.longPressAction,
              (action) => setState(() {
                _button = _button.copyWith(longPressAction: action);
              }),
            ),

            const SizedBox(height: 32),

            // Test button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Press the physical button to test'),
                    ),
                  );
                },
                icon: const Icon(Icons.touch_app),
                label: const Text('Test Button'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Device info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Information',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Type', _button.type.displayName),
                    _buildInfoRow('MAC Address', _button.macAddress),
                    if (_button.lastConnected != null)
                      _buildInfoRow(
                        'Last Connected',
                        _formatDateTime(_button.lastConnected!),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSelector(
    String title,
    String subtitle,
    BleButtonAction currentAction,
    ValueChanged<BleButtonAction> onChanged,
  ) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: DropdownButton<BleButtonAction>(
          value: currentAction,
          underline: const SizedBox(),
          items: BleButtonAction.values.map((action) {
            return DropdownMenuItem(
              value: action,
              child: Text(
                action.displayName,
                style: TextStyle(
                  color: action == BleButtonAction.triggerSOS
                      ? Colors.red
                      : null,
                  fontWeight: action == BleButtonAction.triggerSOS
                      ? FontWeight.bold
                      : null,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
