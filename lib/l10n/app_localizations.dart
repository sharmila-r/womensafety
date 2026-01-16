import 'package:flutter/material.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

/// App localizations delegate
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('ta'), // Tamil
  ];

  // Get the translations map based on locale
  Map<String, String> get _translations {
    switch (locale.languageCode) {
      case 'ta':
        return tamilTranslations;
      case 'en':
      default:
        return englishTranslations;
    }
  }

  String _translate(String key) => _translations[key] ?? key;

  // ==================== APP GENERAL ====================
  String get appName => _translate('appName');
  String get appTagline => _translate('appTagline');
  String get loading => _translate('loading');
  String get error => _translate('error');
  String get success => _translate('success');
  String get cancel => _translate('cancel');
  String get confirm => _translate('confirm');
  String get save => _translate('save');
  String get delete => _translate('delete');
  String get edit => _translate('edit');
  String get done => _translate('done');
  String get ok => _translate('ok');
  String get yes => _translate('yes');
  String get no => _translate('no');
  String get retry => _translate('retry');
  String get close => _translate('close');

  // ==================== NAVIGATION ====================
  String get home => _translate('home');
  String get contacts => _translate('contacts');
  String get escort => _translate('escort');
  String get report => _translate('report');
  String get settings => _translate('settings');

  // ==================== HOME SCREEN ====================
  String get currentLocation => _translate('currentLocation');
  String get fetchingLocation => _translate('fetchingLocation');
  String get sos => _translate('sos');
  String get sosActive => _translate('sosActive');
  String get longPressToActivate => _translate('longPressToActivate');
  String get deactivateSOS => _translate('deactivateSOS');
  String get shareLocation => _translate('shareLocation');
  String get liveTracking => _translate('liveTracking');
  String get callEmergency => _translate('callEmergency');
  String get recordAudio => _translate('recordAudio');
  String get stopRecording => _translate('stopRecording');
  String get recordVideo => _translate('recordVideo');
  String get fakeCall => _translate('fakeCall');
  String get emergencyContacts => _translate('emergencyContacts');
  String get autoAlertOn => _translate('autoAlertOn');
  String get autoAlertOff => _translate('autoAlertOff');

  // ==================== SOS ====================
  String get confirmSOS => _translate('confirmSOS');
  String get sosConfirmMessage => _translate('sosConfirmMessage');
  String get sendSOS => _translate('sendSOS');
  String get sosAlertSent => _translate('sosAlertSent');
  String get addEmergencyContactsFirst => _translate('addEmergencyContactsFirst');
  String get emergencyCall => _translate('emergencyCall');
  String callEmergencyNumber(String number) =>
      _translate('callEmergencyNumber').replaceAll('{number}', number);
  String callEmergencyCountry(String number, String country) =>
      _translate('callEmergencyCountry')
          .replaceAll('{number}', number)
          .replaceAll('{country}', country);

  // ==================== CONTACTS ====================
  String get trustedContacts => _translate('trustedContacts');
  String get addContact => _translate('addContact');
  String get editContact => _translate('editContact');
  String get deleteContact => _translate('deleteContact');
  String get contactName => _translate('contactName');
  String get phoneNumber => _translate('phoneNumber');
  String get relationship => _translate('relationship');
  String get isEmergencyContact => _translate('isEmergencyContact');
  String get noContactsYet => _translate('noContactsYet');
  String get addContactsMessage => _translate('addContactsMessage');
  String get importFromPhone => _translate('importFromPhone');
  String get contactSaved => _translate('contactSaved');
  String get contactDeleted => _translate('contactDeleted');

  // ==================== RECORDING ====================
  String get audioRecording => _translate('audioRecording');
  String get videoRecording => _translate('videoRecording');
  String get recording => _translate('recording');
  String get recordingSaved => _translate('recordingSaved');
  String get uploadToCloud => _translate('uploadToCloud');
  String get keepLocalOnly => _translate('keepLocalOnly');
  String get uploading => _translate('uploading');
  String get uploadSuccess => _translate('uploadSuccess');
  String get uploadFailed => _translate('uploadFailed');
  String get initializingCamera => _translate('initializingCamera');
  String get tapToRecord => _translate('tapToRecord');
  String get readyToRecord => _translate('readyToRecord');
  String get stopAndSave => _translate('stopAndSave');

  // ==================== FAKE CALL ====================
  String get scheduleFakeCall => _translate('scheduleFakeCall');
  String get selectCaller => _translate('selectCaller');
  String get callIn => _translate('callIn');
  String get fakeCallScheduled => _translate('fakeCallScheduled');
  String get incomingCall => _translate('incomingCall');
  String get answer => _translate('answer');
  String get decline => _translate('decline');
  String get onCall => _translate('onCall');
  String get endCall => _translate('endCall');
  String get speaker => _translate('speaker');
  String get mute => _translate('mute');
  String get keypad => _translate('keypad');

  // ==================== ESCORT ====================
  String get requestEscort => _translate('requestEscort');
  String get becomeVolunteer => _translate('becomeVolunteer');
  String get nearbyVolunteers => _translate('nearbyVolunteers');
  String get escortRequest => _translate('escortRequest');
  String get destination => _translate('destination');
  String get pickupLocation => _translate('pickupLocation');
  String get scheduleTime => _translate('scheduleTime');
  String get submitRequest => _translate('submitRequest');

  // ==================== VOLUNTEER ====================
  String get volunteerRegistration => _translate('volunteerRegistration');
  String get volunteerDashboard => _translate('volunteerDashboard');
  String get verificationStatus => _translate('verificationStatus');
  String get phoneVerified => _translate('phoneVerified');
  String get idVerified => _translate('idVerified');
  String get backgroundChecked => _translate('backgroundChecked');
  String get availableForRequests => _translate('availableForRequests');
  String get sosAlertOptIn => _translate('sosAlertOptIn');
  String get sosAlertOptInDesc => _translate('sosAlertOptInDesc');

  // ==================== REPORT ====================
  String get reportIncident => _translate('reportIncident');
  String get incidentType => _translate('incidentType');
  String get incidentLocation => _translate('incidentLocation');
  String get incidentDescription => _translate('incidentDescription');
  String get attachEvidence => _translate('attachEvidence');
  String get submitReport => _translate('submitReport');
  String get reportSubmitted => _translate('reportSubmitted');
  String get myReports => _translate('myReports');

  // ==================== SETTINGS ====================
  String get language => _translate('language');
  String get english => _translate('english');
  String get tamil => _translate('tamil');
  String get notifications => _translate('notifications');
  String get sosSettings => _translate('sosSettings');
  String get alertNearbyVolunteers => _translate('alertNearbyVolunteers');
  String get alertNearbyVolunteersDesc => _translate('alertNearbyVolunteersDesc');
  String get duressCode => _translate('duressCode');
  String get duressCodeDesc => _translate('duressCodeDesc');
  String get cancelCode => _translate('cancelCode');
  String get cancelCodeDesc => _translate('cancelCodeDesc');
  String get setCode => _translate('setCode');
  String get autoRecordOnSOS => _translate('autoRecordOnSOS');
  String get stationaryAlert => _translate('stationaryAlert');
  String get stationaryAlertDesc => _translate('stationaryAlertDesc');
  String get privacyPolicy => _translate('privacyPolicy');
  String get termsOfService => _translate('termsOfService');
  String get about => _translate('about');
  String get version => _translate('version');
  String get logout => _translate('logout');

  // ==================== SAFETY MESSAGES ====================
  String get stayingSafe => _translate('stayingSafe');
  String get helpIsOnTheWay => _translate('helpIsOnTheWay');
  String get youAreNotAlone => _translate('youAreNotAlone');
  String get emergencyServicesNotified => _translate('emergencyServicesNotified');
  String get contactsNotified => _translate('contactsNotified');
  String get locationShared => _translate('locationShared');

  // ==================== ERRORS ====================
  String get locationPermissionDenied => _translate('locationPermissionDenied');
  String get cameraPermissionDenied => _translate('cameraPermissionDenied');
  String get microphonePermissionDenied => _translate('microphonePermissionDenied');
  String get networkError => _translate('networkError');
  String get somethingWentWrong => _translate('somethingWentWrong');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ta'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
