import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/volunteer.dart';
import '../../services/volunteer_service.dart';
import '../../services/bgv_service.dart';
import '../../services/didit_service.dart';
import '../../services/auth_service.dart';
import '../../services/remote_config_service.dart';
import '../../config/country_config.dart';
import 'volunteer_dashboard_screen.dart';
import 'didit_verification_screen.dart';
import '../auth/phone_login_screen.dart';

class VolunteerRegistrationScreen extends StatefulWidget {
  const VolunteerRegistrationScreen({super.key});

  @override
  State<VolunteerRegistrationScreen> createState() =>
      _VolunteerRegistrationScreenState();
}

class _VolunteerRegistrationScreenState
    extends State<VolunteerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();
  final _volunteerService = VolunteerService();
  final _bgvService = BGVService();
  final _countryManager = CountryConfigManager();
  final _authService = AuthService();

  // Step 1: Basic Info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  DateTime? _dateOfBirth;

  // Step 2: ID Verification (India-specific)
  final _aadhaarController = TextEditingController();

  // Step 2: ID Verification (USA-specific)
  final _ssnController = TextEditingController();

  // Step 3: Address
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _fatherNameController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;
  String? _volunteerId;
  bool _consentGiven = false;

  // Didit verification
  bool _diditVerificationComplete = false;
  DiditVerificationResult? _diditResult;

  File? _idDocument;
  File? _selfie;
  final ImagePicker _picker = ImagePicker();

  bool get _isIndia => _countryManager.current.countryCode == 'IN';

  @override
  void initState() {
    super.initState();
    _loadExistingVolunteer();
  }

  Future<void> _loadExistingVolunteer() async {
    setState(() => _isLoading = true);
    try {
      final volunteer = await _volunteerService.getCurrentVolunteer();
      if (volunteer != null && mounted) {
        setState(() {
          _volunteerId = volunteer.id;
          _nameController.text = volunteer.name;
          _phoneController.text = volunteer.phone.replaceAll(RegExp(r'^\+\d+'), '');
          _emailController.text = volunteer.email ?? '';
          _bioController.text = volunteer.bio ?? '';
          _dateOfBirth = volunteer.dateOfBirth;

          // Determine which step to show based on verification level
          switch (volunteer.verificationLevel) {
            case VerificationLevel.unverified:
            case VerificationLevel.phoneVerified:
              _currentStep = 1; // Go to KYC step
              break;
            case VerificationLevel.idVerified:
              _currentStep = 2; // Go to BGV step
              _diditVerificationComplete = true;
              break;
            case VerificationLevel.backgroundChecked:
            case VerificationLevel.trusted:
              // Fully verified, go to dashboard
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const VolunteerDashboardScreen(),
                ),
              );
              return;
          }
        });
      }
    } catch (e) {
      // Not a volunteer yet, start from step 0
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _aadhaarController.dispose();
    _ssnController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _fatherNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Volunteer'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressBar(),

          // Stepper content
          Expanded(
            child: Stepper(
              currentStep: _currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _onStepCancel,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: _isLoading ? null : details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_getStepButtonText()),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                // Step 1: Basic Information
                _buildBasicInfoStep(),

                // Step 2: ID Verification (KYC)
                _buildKycStep(),

                // Step 3: Address & Background Check
                _buildBgvStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final stages = [
      {'title': 'Sign Up', 'status': 'REGISTERED', 'color': Colors.grey},
      {'title': 'Basic KYC', 'status': 'VERIFIED', 'color': Colors.amber},
      {'title': 'Full BGV', 'status': 'ACTIVE', 'color': Colors.green},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: List.generate(stages.length, (index) {
          final stage = stages[index];
          final isActive = index <= _currentStep;
          final isComplete = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? stage['color'] as Color
                              : Colors.grey[300],
                        ),
                        child: Center(
                          child: isComplete
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stage['title'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? Colors.black : Colors.grey,
                        ),
                      ),
                      Text(
                        stage['status'] as String,
                        style: TextStyle(
                          fontSize: 8,
                          color: isActive
                              ? stage['color'] as Color
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < stages.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isComplete ? Colors.green : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Step _buildBasicInfoStep() {
    return Step(
      title: const Text('Basic Information'),
      subtitle: Text(_isIndia ? 'Phone OTP Verification' : 'Basic Profile'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cost indicator
            _buildCostChip('Free', 'Instant'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                if (value.split(' ').length < 2) {
                  return 'Please enter your full name (first and last)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: const Icon(Icons.phone),
                prefixText: '${_countryManager.phoneCode} ',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (value.length < 10) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date of Birth
            InkWell(
              onTap: _pickDateOfBirth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Birth *',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _dateOfBirth != null
                      ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                      : 'Select your date of birth',
                  style: TextStyle(
                    color: _dateOfBirth != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (Optional)',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio (Optional)',
                prefixIcon: Icon(Icons.info),
                border: OutlineInputBorder(),
                hintText: 'Tell users why you want to volunteer...',
              ),
            ),

            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.info_outline,
              color: Colors.blue,
              title: 'After this step',
              description: 'You\'ll be REGISTERED but cannot respond to requests yet. Complete KYC to start helping.',
            ),
          ],
        ),
      ),
    );
  }

  Step _buildKycStep() {
    final useDidit = DiditService.isConfigured;

    return Step(
      title: const Text('Identity Verification'),
      subtitle: Text(useDidit ? 'Powered by Didit' : 'Upload government ID'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cost indicator
          _buildCostChip('Free', 'Instant'),
          const SizedBox(height: 16),

          if (useDidit) ...[
            // Didit verification flow
            const Text(
              'Verify your identity with a quick ID scan and selfie.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // What gets verified
            _buildCheckList([
              'Government ID Verification',
              'Liveness Detection',
              'Face Match',
            ]),
            const SizedBox(height: 20),

            // Verification status card
            if (_diditVerificationComplete && _diditResult != null) ...[
              _buildVerificationStatusCard(),
            ] else ...[
              // Start verification button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startDiditVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.verified_user),
                  label: const Text(
                    'Start Identity Verification',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You\'ll be redirected to complete verification. This takes about 2 minutes.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ] else ...[
            // Fallback: Manual verification flow
            if (_isIndia) ...[
              const Text(
                'We\'ll verify your identity using Aadhaar and face match.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _aadhaarController,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: 'Aadhaar Number *',
                  prefixIcon: Icon(Icons.credit_card),
                  border: OutlineInputBorder(),
                  counterText: '',
                  hintText: '12 digit Aadhaar number',
                ),
              ),
              const SizedBox(height: 16),

              _buildCheckList([
                'Aadhaar Verification',
                'Face Match with Aadhaar photo',
                'Liveness Check (blink detection)',
              ]),
            ] else ...[
              const Text(
                'Please upload a clear photo of your government-issued ID.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              _buildUploadCard(
                title: 'Government ID',
                subtitle: 'Driver\'s License or Passport',
                icon: Icons.badge,
                file: _idDocument,
                onTap: () => _pickImage(true),
              ),
            ],

            const SizedBox(height: 16),

            _buildUploadCard(
              title: 'Selfie',
              subtitle: _isIndia
                  ? 'For face match verification'
                  : 'Clear photo of your face',
              icon: Icons.face,
              file: _selfie,
              onTap: () => _pickImage(false),
            ),
          ],

          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final config = RemoteConfigService.instance;
              final idRadius = config.getIdVerifiedRadius(_countryManager.current.countryCode);
              return _buildInfoCard(
                icon: Icons.verified_user,
                color: Colors.amber,
                title: 'After verification',
                description: 'You\'ll be VERIFIED with full responder access (${idRadius.toInt()}km radius). Complete BGV for trusted badge.',
              );
            },
          ),

          const SizedBox(height: 16),
          _buildSecurityNote(),
        ],
      ),
    );
  }

  Widget _buildVerificationStatusCard() {
    final success = _diditResult?.success ?? false;

    return Card(
      color: success ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    success ? 'Verification Complete' : 'Verification Failed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: success ? Colors.green : Colors.red,
                    ),
                  ),
                  if (success && _diditResult?.extractedName != null) ...[
                    const SizedBox(height: 4),
                    Text('Name: ${_diditResult!.extractedName}'),
                  ],
                  if (success && _diditResult?.livenessPasssed == true) ...[
                    const SizedBox(height: 2),
                    const Text('✓ Liveness verified', style: TextStyle(color: Colors.green)),
                  ],
                  if (!success) ...[
                    const SizedBox(height: 4),
                    Text(
                      _diditResult?.errorMessage ?? 'Please try again',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _startDiditVerification,
                      child: const Text('Retry Verification'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startDiditVerification() async {
    if (_volunteerId == null) {
      _showError('Please complete the previous step first');
      return;
    }

    final result = await Navigator.push<DiditVerificationResult>(
      context,
      MaterialPageRoute(
        builder: (context) => DiditVerificationScreen(
          oderlId: _volunteerId!,
          userEmail: _emailController.text.isEmpty ? null : _emailController.text,
          userPhone: _phoneController.text,
        ),
      ),
    );

    if (result != null && mounted) {
      print('=== DIDIT VERIFICATION RESULT ===');
      print('Success: ${result.success}');
      print('Cancelled: ${result.cancelled}');
      print('Decision: ${result.decision}');
      print('Error: ${result.errorMessage}');
      print('Session ID: ${result.sessionId}');

      setState(() {
        _diditResult = result;
        _diditVerificationComplete = result.success;
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity verification successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (!result.cancelled) {
        _showError(result.errorMessage ?? 'Verification failed. Please try again.');
      }
    }
  }

  Step _buildBgvStep() {
    return Step(
      title: const Text('Background Verification'),
      subtitle: const Text('Full verification (2-5 days)'),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      content: Form(
        key: _addressFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cost indicator
            _buildCostChip(
              _isIndia ? '₹500-800' : '\$32-102',
              '2-5 days',
            ),
            const SizedBox(height: 16),

            // What gets checked
            Card(
              color: Colors.orange.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_user, color: Colors.orange),
                        SizedBox(width: 12),
                        Text(
                          'What we check',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCheckList([
                      'Criminal Court Records',
                      'Address Verification',
                      _isIndia ? 'Police Verification' : 'SSN Trace',
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Father's name (India) or Additional info (USA)
            if (_isIndia) ...[
              TextFormField(
                controller: _fatherNameController,
                decoration: const InputDecoration(
                  labelText: 'Father\'s Name *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required for background check';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ] else ...[
              // SSN for USA
              TextFormField(
                controller: _ssnController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 9,
                decoration: const InputDecoration(
                  labelText: 'Social Security Number *',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                  counterText: '',
                  hintText: 'XXX-XX-XXXX',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required for background check';
                  }
                  if (value.length != 9) {
                    return 'Please enter a valid SSN';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Address fields
            const Text(
              'Current Address',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _addressLine1Controller,
              decoration: const InputDecoration(
                labelText: 'Address Line 1 *',
                prefixIcon: Icon(Icons.home),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your address';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _addressLine2Controller,
              decoration: const InputDecoration(
                labelText: 'Address Line 2',
                prefixIcon: Icon(Icons.home_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'State *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _pincodeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _isIndia ? 'PIN Code *' : 'ZIP Code *',
                prefixIcon: const Icon(Icons.pin_drop),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Consent checkbox
            Card(
              child: CheckboxListTile(
                value: _consentGiven,
                onChanged: (value) {
                  setState(() => _consentGiven = value ?? false);
                },
                title: const Text(
                  'I consent to a background check',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'I understand this is required to become a verified volunteer and agree to the terms.',
                  style: TextStyle(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFFE91E63),
              ),
            ),

            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.check_circle,
              color: Colors.green,
              title: 'After approval',
              description: 'You\'ll be ACTIVE with full responder access (5km radius). Help women in need!',
            ),

            const SizedBox(height: 8),
            Text(
              'Background check is processed by ${_isIndia ? "IDfy" : "Checkr"} and typically takes 2-5 business days.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 16),
            // Skip option
            Builder(
              builder: (context) {
                final config = RemoteConfigService.instance;
                final idRadius = config.getIdVerifiedRadius(_countryManager.current.countryCode);
                return Card(
                  color: Colors.grey.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.skip_next, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'Want to start helping now?',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can skip BGV for now and help within ${idRadius.toInt()}km radius. Complete BGV later for trusted badge.',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _skipBgvAndGoToDashboard,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Skip for Now'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _skipBgvAndGoToDashboard() async {
    final config = RemoteConfigService.instance;
    final idRadius = config.getIdVerifiedRadius(_countryManager.current.countryCode);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Background Verification?'),
        content: Text(
          'You can start helping users within ${idRadius.toInt()}km radius now.\n\n'
          'Complete background verification later to get the trusted badge.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
            ),
            child: const Text('Skip & Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const VolunteerDashboardScreen(),
        ),
      );
    }
  }

  Widget _buildCostChip(String cost, String time) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.payments, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                cost,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckList(List<String> items) {
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(item),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: file != null ? Colors.green : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: file != null
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(file, fit: BoxFit.cover),
                    )
                  : Icon(
                      icon,
                      size: 40,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file != null ? 'Tap to change' : 'Tap to upload',
                    style: TextStyle(
                      color: file != null ? Colors.green : const Color(0xFFE91E63),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (file != null)
              const Icon(Icons.check_circle, color: Colors.green)
            else
              const Icon(Icons.upload, color: Color(0xFFE91E63)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.security, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your documents are encrypted and stored securely. They will only be used for verification purposes.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepButtonText() {
    switch (_currentStep) {
      case 0:
        return 'Continue to KYC';
      case 1:
        return 'Continue to BGV';
      case 2:
        return 'Submit Application';
      default:
        return 'Continue';
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18), // Must be 18+
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _pickImage(bool isIdDocument) async {
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
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        if (isIdDocument) {
          _idDocument = File(image.path);
        } else {
          _selfie = File(image.path);
        }
      });
    }
  }

  void _onStepContinue() async {
    switch (_currentStep) {
      case 0:
        // Validate basic info
        if (!_formKey.currentState!.validate()) return;
        if (_dateOfBirth == null) {
          _showError('Please select your date of birth');
          return;
        }

        // Check age (must be 18+)
        final age = DateTime.now().difference(_dateOfBirth!).inDays ~/ 365;
        if (age < 18) {
          _showError('You must be at least 18 years old to volunteer');
          return;
        }

        // Check if user is logged in, if not prompt for phone verification
        if (!_authService.isLoggedIn) {
          final phoneNumber = '${_countryManager.phoneCode}${_phoneController.text.trim()}';
          final loginSuccess = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PhoneLoginScreen(
                initialPhone: phoneNumber,
                title: 'Verify Your Phone',
                subtitle: 'Please verify your phone number to continue registration',
              ),
            ),
          );

          if (loginSuccess != true) {
            // User cancelled or login failed
            return;
          }
        }

        setState(() => _isLoading = true);
        try {
          _volunteerId = await _volunteerService.registerVolunteer(
            name: _nameController.text,
            phone: _phoneController.text,
            email: _emailController.text.isEmpty ? null : _emailController.text,
            bio: _bioController.text.isEmpty ? null : _bioController.text,
            country: _countryManager.current.countryCode,
            dateOfBirth: _dateOfBirth,
          );
          setState(() => _currentStep = 1);
        } catch (e) {
          _showError(e.toString());
        } finally {
          setState(() => _isLoading = false);
        }
        break;

      case 1:
        // Validate KYC
        final useDidit = DiditService.isConfigured;

        if (useDidit) {
          // Didit verification flow
          if (!_diditVerificationComplete || _diditResult == null) {
            _showError('Please complete identity verification first');
            return;
          }

          if (!_diditResult!.success) {
            _showError('Identity verification failed. Please try again.');
            return;
          }

          setState(() => _isLoading = true);
          try {
            // Update volunteer with Didit verification results
            await _volunteerService.submitIdVerification(
              isAadhaarVerified: false, // Not using Aadhaar with Didit
              faceMatchScore: _diditResult!.faceMatchScore,
              livenessPasssed: _diditResult!.livenessPasssed,
              diditSessionId: _diditResult!.sessionId,
            );

            // Check if BGV step should be skipped
            final skipBgv = RemoteConfigService.instance.bgvSkipApiCalls;
            if (skipBgv) {
              // Skip BGV, go directly to dashboard
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VolunteerDashboardScreen(),
                  ),
                );
              }
            } else {
              setState(() => _currentStep = 2);
            }
          } catch (e) {
            _showError(e.toString());
          } finally {
            setState(() => _isLoading = false);
          }
        } else {
          // Manual verification flow (fallback)
          if (_isIndia) {
            if (_aadhaarController.text.length != 12) {
              _showError('Please enter a valid 12-digit Aadhaar number');
              return;
            }
          } else {
            if (_idDocument == null) {
              _showError('Please upload your government ID');
              return;
            }
          }

          if (_selfie == null) {
            _showError('Please upload a selfie for verification');
            return;
          }

          setState(() => _isLoading = true);
          try {
            // Upload documents
            if (!_isIndia && _idDocument != null) {
              await _volunteerService.uploadIdDocument(_idDocument!);
            }
            await _volunteerService.uploadSelfie(_selfie!);

            // Perform KYC verification
            double? faceMatchScore;
            bool livenessPasssed = false;
            bool aadhaarVerified = false;

            if (_isIndia) {
              // IDfy Basic KYC
              final result = await _bgvService.idfyBasicKyc(
                volunteerId: _volunteerId!,
                aadhaarNumber: _aadhaarController.text,
                selfieBase64: '', // Would convert selfie to base64
                name: _nameController.text,
                dateOfBirth: '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
              );

              if (!result.passed) {
                _showError(result.errorMessage ?? 'KYC verification failed');
                setState(() => _isLoading = false);
                return;
              }

              // Extract KYC results
              aadhaarVerified = result.details['aadhaar']?['status'] == 'id_found';
              faceMatchScore = result.details['face_match_score']?.toDouble();
              livenessPasssed = result.details['is_live'] ?? false;
            }

            await _volunteerService.submitIdVerification(
              isAadhaarVerified: aadhaarVerified,
              faceMatchScore: faceMatchScore,
              livenessPasssed: livenessPasssed,
            );

            // Check if BGV step should be skipped
            final skipBgv = RemoteConfigService.instance.bgvSkipApiCalls;
            if (skipBgv) {
              // Skip BGV, go directly to dashboard
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VolunteerDashboardScreen(),
                  ),
                );
              }
            } else {
              setState(() => _currentStep = 2);
            }
          } catch (e) {
            _showError(e.toString());
          } finally {
            setState(() => _isLoading = false);
          }
        }
        break;

      case 2:
        // Validate BGV form
        if (!_addressFormKey.currentState!.validate()) return;
        if (!_consentGiven) {
          _showError('Please provide consent for background check');
          return;
        }

        setState(() => _isLoading = true);
        try {
          if (_isIndia) {
            // IDfy Full BGV
            await _bgvService.idfyFullBgv(
              volunteerId: _volunteerId!,
              name: _nameController.text,
              email: _emailController.text.isEmpty ? 'noemail@kavalan.app' : _emailController.text,
              phone: _phoneController.text,
              aadhaarNumber: _aadhaarController.text,
              fatherName: _fatherNameController.text,
              dateOfBirth: '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
              addressLine1: '${_addressLine1Controller.text}, ${_addressLine2Controller.text}'.trim(),
              city: _cityController.text,
              state: _stateController.text,
              pincode: _pincodeController.text,
            );
          } else {
            // Checkr BGV
            await _bgvService.checkrBackgroundCheck(
              volunteerId: _volunteerId!,
              firstName: _nameController.text.split(' ').first,
              lastName: _nameController.text.split(' ').last,
              email: _emailController.text,
              dateOfBirth: '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
              ssn: _ssnController.text,
              address: _addressLine1Controller.text,
              city: _cityController.text,
              state: _stateController.text,
              zipcode: _pincodeController.text,
            );
          }

          // Update volunteer service
          await _volunteerService.initiateBackgroundCheck(
            firstName: _nameController.text.split(' ').first,
            lastName: _nameController.text.split(' ').last,
            dateOfBirth: '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
            ssn: _isIndia ? _aadhaarController.text : _ssnController.text,
            address: '${_addressLine1Controller.text}, ${_cityController.text}, ${_stateController.text} ${_pincodeController.text}',
          );

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const VolunteerDashboardScreen(),
              ),
            );
          }
        } catch (e) {
          _showError(e.toString());
        } finally {
          setState(() => _isLoading = false);
        }
        break;
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
