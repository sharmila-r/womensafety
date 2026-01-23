import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fallback screen shown when demo data fails to load during App Review
class ReviewModeScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onContinueDemo;

  const ReviewModeScreen({
    super.key,
    required this.onRetry,
    required this.onContinueDemo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 50,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Kaavala Demo Mode',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                "We're having trouble loading live demo data due to network conditions.\n\nYou can retry, or continue with sample content to review the app experience.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Retry button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Continue with sample content
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onContinueDemo,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continue with Sample Content'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE91E63),
                    side: const BorderSide(color: Color(0xFFE91E63)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Sample features preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Features you can preview:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FeatureItem(icon: Icons.sos, text: 'SOS Emergency Alert'),
                    _FeatureItem(icon: Icons.location_on, text: 'Live Location Sharing'),
                    _FeatureItem(icon: Icons.people, text: 'Emergency Contacts'),
                    _FeatureItem(icon: Icons.settings, text: 'App Settings'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Legal links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse('https://getkaavala.com/privacy-policy')),
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                  Text(' • ', style: TextStyle(color: Colors.grey[400])),
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse('https://getkaavala.com/terms')),
                    child: Text(
                      'Terms of Service',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE91E63)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }
}
