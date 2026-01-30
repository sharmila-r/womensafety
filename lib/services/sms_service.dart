import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/country_config.dart';

class SmsService {
  /// Send SMS by opening the SMS app with pre-filled message
  /// Note: Push notifications are the primary alert method, SMS is backup
  static Future<bool> sendSMS({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    try {
      final String recipients = phoneNumbers.join(',');
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: recipients,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error opening SMS app: $e');
      return false;
    }
  }

  /// Send Emergency SOS SMS
  static Future<bool> sendEmergencySMS({
    required List<String> phoneNumbers,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final String mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final String message = '''
EMERGENCY SOS ALERT

I need immediate help!

My Location:
$address

Google Maps:
$mapsUrl

Time: ${DateTime.now().toString().substring(0, 19)}

Please respond immediately or contact emergency services!
''';

    return await sendSMS(phoneNumbers: phoneNumbers, message: message);
  }

  /// Share location via SMS
  static Future<bool> shareLocation({
    required List<String> phoneNumbers,
    required double latitude,
    required double longitude,
    required String address,
    bool isCheckIn = false,
  }) async {
    final String mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    final String message;
    if (isCheckIn) {
      message = '''
Check-In: I'm Safe

I'm checking in to let you know I'm okay.

Current Location:
$address

Google Maps:
$mapsUrl

Time: ${DateTime.now().toString().substring(0, 19)}
''';
    } else {
      message = '''
Live Location Shared

I'm sharing my current location with you.

Address: $address

Google Maps: $mapsUrl

Shared at: ${DateTime.now().toString().substring(0, 19)}
''';
    }

    return await sendSMS(phoneNumbers: phoneNumbers, message: message);
  }

  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  static Future<void> callEmergencyNumber() async {
    final emergencyNumber = CountryConfigManager().emergencyNumber;
    await makePhoneCall(emergencyNumber);
  }
}
