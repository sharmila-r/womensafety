import 'base_country.dart';

class USAConfig extends BaseCountryConfig {
  @override
  String get countryCode => 'US';

  @override
  String get countryName => 'United States';

  @override
  String get phoneCode => '+1';

  @override
  String get emergencyNumber => '911';

  @override
  String get defaultLanguage => 'en';

  @override
  List<String> get supportedLanguages => ['en', 'es'];

  @override
  bool get hasBackgroundCheckAPI => true;

  @override
  String? get backgroundCheckProvider => 'Checkr'; // US background check provider

  @override
  List<EmergencyContact> get emergencyContacts => const [
        EmergencyContact(
          name: 'Emergency Services',
          number: '911',
          description: 'Police, Fire, Ambulance - works nationwide',
          type: EmergencyContactType.general,
        ),
        EmergencyContact(
          name: 'Non-Emergency Police',
          number: '311',
          description: 'Non-emergency police and city services',
          type: EmergencyContactType.police,
          isTollFree: true,
        ),
      ];

  @override
  List<EmergencyContact> get womenHelplines => const [
        EmergencyContact(
          name: 'National Domestic Violence Hotline',
          number: '18007997233',
          description: '24/7 confidential support for domestic violence survivors',
          type: EmergencyContactType.domesticViolence,
        ),
        EmergencyContact(
          name: 'RAINN Sexual Assault Hotline',
          number: '18006564673',
          description:
              'Rape, Abuse & Incest National Network - 24/7 support',
          type: EmergencyContactType.sexualAssault,
        ),
        EmergencyContact(
          name: 'National Sexual Assault Hotline',
          number: '18006564673',
          description: 'Free, confidential, 24/7 support',
          type: EmergencyContactType.sexualAssault,
        ),
        EmergencyContact(
          name: 'Crisis Text Line',
          number: '741741',
          description: 'Text HOME to 741741 for crisis support',
          type: EmergencyContactType.mentalHealth,
        ),
        EmergencyContact(
          name: 'National Human Trafficking Hotline',
          number: '18883737888',
          description: '24/7 support for trafficking survivors',
          type: EmergencyContactType.general,
        ),
        EmergencyContact(
          name: 'Childhelp National Hotline',
          number: '18004224453',
          description: 'Child abuse prevention and support',
          type: EmergencyContactType.childHelpline,
        ),
        EmergencyContact(
          name: 'Suicide & Crisis Lifeline',
          number: '988',
          description: '24/7 suicide and crisis support',
          type: EmergencyContactType.mentalHealth,
        ),
        EmergencyContact(
          name: 'StrongHearts Native Helpline',
          number: '18447627433',
          description: 'Support for Native Americans facing domestic violence',
          type: EmergencyContactType.domesticViolence,
        ),
        EmergencyContact(
          name: 'LGBTQ+ Anti-Violence Project',
          number: '12127141141',
          description: 'Support for LGBTQ+ survivors of violence',
          type: EmergencyContactType.general,
          isTollFree: false,
        ),
      ];

  @override
  List<NGOPartner> get ngoPartners => const [
        NGOPartner(
          name: 'RAINN',
          website: 'https://www.rainn.org',
          phone: '18006564673',
          email: 'info@rainn.org',
          description:
              'Nation\'s largest anti-sexual violence organization',
          services: [
            'Hotline support',
            'Online chat',
            'Local referrals',
            'Policy advocacy'
          ],
          operatingRegions: ['Nationwide'],
          acceptsReports: true,
        ),
        NGOPartner(
          name: 'National Coalition Against Domestic Violence',
          website: 'https://ncadv.org',
          description:
              'Leading voice for domestic violence victims and survivors',
          services: ['Advocacy', 'Education', 'Public policy'],
          operatingRegions: ['Nationwide'],
          acceptsReports: false,
        ),
        NGOPartner(
          name: 'National Network to End Domestic Violence',
          website: 'https://nnedv.org',
          description: 'Social change organization for domestic violence',
          services: [
            'Safety planning',
            'Tech safety',
            'Policy advocacy',
            'Training'
          ],
          operatingRegions: ['Nationwide'],
          acceptsReports: false,
        ),
        NGOPartner(
          name: 'Futures Without Violence',
          website: 'https://www.futureswithoutviolence.org',
          phone: '14156785500',
          description:
              'Programs and policies to end violence against women and children',
          services: ['Training', 'Policy', 'Research', 'Prevention'],
          operatingRegions: ['Nationwide'],
          acceptsReports: false,
        ),
        NGOPartner(
          name: 'Hollaback!',
          website: 'https://www.ihollaback.org',
          email: 'holla@ihollaback.org',
          description:
              'Movement to end harassment in public spaces',
          services: [
            'Bystander intervention training',
            'Report harassment',
            'Community organizing'
          ],
          operatingRegions: ['Nationwide', 'Global'],
          acceptsReports: true,
        ),
        NGOPartner(
          name: 'Safe Horizon',
          website: 'https://www.safehorizon.org',
          phone: '18006214673',
          description:
              'Largest non-profit victim services agency in the US',
          services: [
            'Shelter',
            'Counseling',
            'Legal services',
            'Court advocacy'
          ],
          operatingRegions: ['New York'],
          acceptsReports: true,
        ),
        NGOPartner(
          name: 'National Center for Victims of Crime',
          website: 'https://victimsofcrime.org',
          phone: '18553484673',
          description: 'Resources and advocacy for crime victims',
          services: ['Victim assistance', 'Stalking resource center', 'Training'],
          operatingRegions: ['Nationwide'],
          acceptsReports: false,
        ),
      ];
}
