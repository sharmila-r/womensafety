import 'dart:async';
import 'package:flutter/material.dart';
import '../services/fake_call_service.dart';
import '../main.dart' show navigatorKey;

/// Fake incoming call screen that mimics a real phone call
class FakeCallScreen extends StatefulWidget {
  final FakeCallConfig config;

  const FakeCallScreen({super.key, required this.config});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with SingleTickerProviderStateMixin {
  bool _isAnswered = false;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    FakeCallService().endCall();
    super.dispose();
  }

  void _answerCall() {
    setState(() => _isAnswered = true);
    FakeCallService().answerCall();

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _callDuration += const Duration(seconds: 1);
      });
    });
  }

  void _endCall() {
    FakeCallService().endCall();
    Navigator.pop(context);
  }

  void _declineCall() {
    FakeCallService().declineCall();
    Navigator.pop(context);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Caller info
            Column(
              children: [
                // Caller avatar
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isAnswered ? 1.0 : _pulseAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[800],
                          border: Border.all(
                            color: _isAnswered ? Colors.green : Colors.white,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Caller name
                Text(
                  widget.config.callerName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Caller number or call status
                Text(
                  _isAnswered
                      ? _formatDuration(_callDuration)
                      : widget.config.callerNumber,
                  style: TextStyle(
                    fontSize: 18,
                    color: _isAnswered ? Colors.green : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),

                // Call status
                Text(
                  _isAnswered ? 'On Call' : 'Incoming Call...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),

            const Spacer(flex: 3),

            // Call actions
            if (_isAnswered)
              _buildInCallControls()
            else
              _buildIncomingCallControls(),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCallControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Decline button
          Column(
            children: [
              GestureDetector(
                onTap: _declineCall,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Decline',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),

          // Answer button
          Column(
            children: [
              GestureDetector(
                onTap: _answerCall,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                  child: const Icon(
                    Icons.call,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Answer',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInCallControls() {
    return Column(
      children: [
        // In-call action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCallAction(Icons.volume_up, 'Speaker', () {}),
            _buildCallAction(Icons.mic_off, 'Mute', () {}),
            _buildCallAction(Icons.dialpad, 'Keypad', () {}),
          ],
        ),
        const SizedBox(height: 32),

        // End call button
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Widget to schedule a fake call
class FakeCallScheduler extends StatefulWidget {
  const FakeCallScheduler({super.key});

  @override
  State<FakeCallScheduler> createState() => _FakeCallSchedulerState();
}

class _FakeCallSchedulerState extends State<FakeCallScheduler> {
  final FakeCallService _service = FakeCallService();
  int _selectedDelay = 5;
  FakeCallConfig? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _selectedPreset = FakeCallService.presets.first;
  }

  void _scheduleFakeCall() {
    if (_selectedPreset == null) return;

    _service.scheduleFakeCall(delaySeconds: _selectedDelay);

    // Set up callback to show fake call screen
    // Using global navigatorKey to handle navigation after widget disposal
    _service.onCallStart = (config) {
      // Use global navigator key - works even after this widget is disposed
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => FakeCallScreen(config: config),
        ),
      );
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fake call scheduled in $_selectedDelay seconds'),
        action: SnackBarAction(
          label: 'Cancel',
          onPressed: () => _service.cancelScheduledCall(),
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schedule Fake Call',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select who should "call" you and when',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Caller preset selection
          const Text(
            'Caller',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FakeCallService.presets.map((preset) {
              final isSelected = _selectedPreset?.callerName == preset.callerName;
              return ChoiceChip(
                label: Text(preset.callerName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedPreset = preset);
                },
                selectedColor: const Color(0xFFE91E63),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Delay selection
          const Text(
            'Call in...',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [5, 10, 15, 30, 60].map((seconds) {
              final isSelected = _selectedDelay == seconds;
              final label = seconds < 60 ? '${seconds}s' : '1 min';
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedDelay = seconds);
                },
                selectedColor: const Color(0xFFE91E63),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Schedule button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _scheduleFakeCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Schedule Fake Call',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
