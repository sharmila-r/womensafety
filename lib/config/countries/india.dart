import 'base_country.dart';

class IndiaConfig extends BaseCountryConfig {
  @override
  String get countryCode => 'IN';

  @override
  String get countryName => 'India';

  @override
  String get phoneCode => '+91';

  @override
  String get emergencyNumber => '112';

  @override
  String get defaultLanguage => 'en';

  @override
  List<String> get supportedLanguages => ['en', 'hi'];

  @override
  bool get hasBackgroundCheckAPI => true;

  @override
  String? get backgroundCheckProvider => 'AuthBridge'; // Indian verification provider

  @override
  List<EmergencyContact> get emergencyContacts => const [
        EmergencyContact(
          name: 'National Emergency Number',
          number: '112',
          description: 'Single emergency number for Police, Fire, Ambulance',
          type: EmergencyContactType.general,
        ),
        EmergencyContact(
          name: 'Police',
          number: '100',
          description: 'Police emergency helpline',
          type: EmergencyContactType.police,
        ),
        EmergencyContact(
          name: 'Ambulance',
          number: '102',
          description: 'Medical emergency',
          type: EmergencyContactType.ambulance,
        ),
        EmergencyContact(
          name: 'Fire',
          number: '101',
          description: 'Fire emergency',
          type: EmergencyContactType.fire,
        ),
      ];

  @override
  List<EmergencyContact> get womenHelplines => const [
        EmergencyContact(
          name: 'Women Helpline',
          number: '181',
          description: 'National Commission for Women helpline',
          type: EmergencyContactType.womenHelpline,
        ),
        EmergencyContact(
          name: 'Women Helpline (Domestic Abuse)',
          number: '1091',
          description: 'Women in distress helpline',
          type: EmergencyContactType.domesticViolence,
        ),
        EmergencyContact(
          name: 'NCW Helpline',
          number: '7827170170',
          description: 'National Commission for Women WhatsApp',
          type: EmergencyContactType.womenHelpline,
          isTollFree: false,
        ),
        EmergencyContact(
          name: 'Women Helpline (All India)',
          number: '1800112020',
          description: '24/7 toll-free women helpline',
          type: EmergencyContactType.womenHelpline,
        ),
        EmergencyContact(
          name: 'Cyber Crime Helpline',
          number: '1930',
          description: 'Report cyber crimes against women',
          type: EmergencyContactType.general,
        ),
        EmergencyContact(
          name: 'Child Helpline',
          number: '1098',
          description: 'CHILDLINE India for children in distress',
          type: EmergencyContactType.childHelpline,
        ),
        EmergencyContact(
          name: 'Mental Health Helpline',
          number: '08046110007',
          description: 'NIMHANS helpline',
          type: EmergencyContactType.mentalHealth,
          isTollFree: false,
        ),
      ];

  @override
  List<NGOPartner> get ngoPartners => const [
        NGOPartner(
          name: 'SafeCity',
          website: 'https://safecity.in',
          description:
              'Crowdsourced platform to document sexual harassment in public spaces',
          services: [
            'Report harassment',
            'Safety mapping',
            'Community awareness'
          ],
          operatingRegions: ['All India'],
          acceptsReports: true,
        ),
        NGOPartner(
          name: 'Jagori',
          website: 'https://jagori.org',
          phone: '01126692700',
          email: 'jagori@jagori.org',
          description:
              'Women\'s resource and training center working on violence against women',
          services: [
            'Counseling',
            'Legal aid',
            'Shelter',
            'Training'
          ],
          operatingRegions: ['Delhi NCR'],
          acceptsReports: true,
        ),
        NGOPartner(
          name: 'Majlis',
          website: 'https://majlislaw.com',
          phone: '02226610986',
          email: 'majlis@vsnl.com',
          description: 'Legal advocacy for women survivors of violence',
          services: ['Legal aid', 'Court representation', 'Policy advocacy'],
          operatingRegions: ['Maharashtra'],
          acceptsReports: true,
        ),
        NGOPartner(
          name: 'Sakhi',
          website: 'https://sakhikerala.org',
          phone: '04712304024',
          description: 'Women\'s collective in Kerala',
          services: ['Counseling', 'Support groups', 'Awareness programs'],
          operatingRegions: ['Kerala'],
          acceptsReports: true,
        ),
        NGOPartner(
          name: 'Snehi',
          website: 'https://www.snehi.org',
          phone: '04424640050',
          description: 'Suicide prevention and mental health support',
          services: ['Crisis intervention', 'Counseling', 'Mental health'],
          operatingRegions: ['Tamil Nadu'],
          acceptsReports: false,
        ),
        NGOPartner(
          name: 'SWATI',
          phone: '07926577355',
          description: 'Support to women in distress in Gujarat',
          services: ['Short stay home', 'Counseling', 'Rehabilitation'],
          operatingRegions: ['Gujarat'],
          acceptsReports: true,
        ),
      ];
}
