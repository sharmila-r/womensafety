import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/volunteer_service.dart';
import '../../config/country_config.dart';
import 'volunteer_dashboard_screen.dart';

class VolunteerRegistrationScreen extends StatefulWidget {
  const VolunteerRegistrationScreen({super.key});

  @override
  State<VolunteerRegistrationScreen> createState() =>
      _VolunteerRegistrationScreenState();
}

class _VolunteerRegistrationScreenState
    extends State<VolunteerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _volunteerService = VolunteerService();
  final _countryManager = CountryConfigManager();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;
  String? _volunteerId;

  File? _idDocument;
  File? _selfie;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Volunteer'),
      ),
      body: Stepper(
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
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_currentStep == 2 ? 'Submit' : 'Continue'),
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
          Step(
            title: const Text('Basic Information'),
            subtitle: const Text('Tell us about yourself'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone),
                      prefixText: '${_countryManager.phoneCode} ',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
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
                ],
              ),
            ),
          ),

          // Step 2: ID Verification
          Step(
            title: const Text('ID Verification'),
            subtitle: const Text('Upload your government ID'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please upload a clear photo of your government-issued ID (Driver\'s License, Passport, or National ID).',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // ID Document Upload
                _buildUploadCard(
                  title: 'Government ID',
                  subtitle: 'Front side of your ID',
                  icon: Icons.badge,
                  file: _idDocument,
                  onTap: () => _pickImage(true),
                ),
                const SizedBox(height: 16),

                // Selfie Upload
                _buildUploadCard(
                  title: 'Selfie',
                  subtitle: 'Clear photo of your face',
                  icon: Icons.face,
                  file: _selfie,
                  onTap: () => _pickImage(false),
                ),

                const SizedBox(height: 16),
                Card(
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
                ),
              ],
            ),
          ),

          // Step 3: Background Check Consent
          Step(
            title: const Text('Background Check'),
            subtitle: const Text('Consent to background verification'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.orange.withOpacity(0.1),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user, color: Colors.orange),
                            SizedBox(width: 12),
                            Text(
                              'Why Background Check?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'To ensure the safety of all users, we require volunteers to undergo a background verification. This helps build trust and ensures a safe environment for everyone.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'What we check:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildCheckItem('Criminal record check'),
                _buildCheckItem('Identity verification'),
                _buildCheckItem('Address verification'),
                _buildCheckItem('Reference check (optional)'),

                const SizedBox(height: 16),
                Card(
                  child: CheckboxListTile(
                    value: true,
                    onChanged: (value) {},
                    title: const Text(
                      'I consent to a background check',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'I understand this is required to become a verified volunteer',
                      style: TextStyle(fontSize: 12),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFFE91E63),
                  ),
                ),

                const SizedBox(height: 8),
                const Text(
                  'Background check is processed by our trusted partners and typically takes 2-5 business days.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
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
        if (_formKey.currentState!.validate()) {
          setState(() => _isLoading = true);
          try {
            _volunteerId = await _volunteerService.registerVolunteer(
              name: _nameController.text,
              phone: _phoneController.text,
              email: _emailController.text.isEmpty ? null : _emailController.text,
              bio: _bioController.text.isEmpty ? null : _bioController.text,
              country: _countryManager.current.countryCode,
            );
            setState(() => _currentStep = 1);
          } catch (e) {
            _showError(e.toString());
          } finally {
            setState(() => _isLoading = false);
          }
        }
        break;

      case 1:
        // Validate ID uploads
        if (_idDocument == null || _selfie == null) {
          _showError('Please upload both ID document and selfie');
          return;
        }

        setState(() => _isLoading = true);
        try {
          await _volunteerService.uploadIdDocument(_idDocument!);
          await _volunteerService.uploadSelfie(_selfie!);
          await _volunteerService.submitIdVerification();
          setState(() => _currentStep = 2);
        } catch (e) {
          _showError(e.toString());
        } finally {
          setState(() => _isLoading = false);
        }
        break;

      case 2:
        // Submit for background check
        setState(() => _isLoading = true);
        try {
          // In production, collect more details for background check
          await _volunteerService.initiateBackgroundCheck(
            firstName: _nameController.text.split(' ').first,
            lastName: _nameController.text.split(' ').last,
            dateOfBirth: '', // Would collect from form
            ssn: '', // Would collect securely
            address: '', // Would collect from form
          );

          if (mounted) {
            // Navigate to dashboard
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
