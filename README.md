# Kaavala - Women's Safety App

A comprehensive women's safety application built with Flutter, featuring SOS alerts, real-time location sharing, volunteer escort system, and harassment reporting.

## Features

### Emergency SOS
- One-tap SOS button with pulse animation
- Sends alerts to trusted contacts with live location
- Automatic audio/video recording during emergencies
- Offline SMS fallback when no internet
- Duress code support for covert alerts
- BLE panic button integration (Flic, iTag, Tile)

### Location Services
- Real-time location sharing with trusted contacts
- Safe journey tracking with ETA
- Background location monitoring
- Stationary detection alerts

### Volunteer Escort System
- Request verified volunteers for escort
- 3-stage volunteer verification (Phone → ID/KYC → Background Check)
- Live volunteer tracking on map during escort
- In-app chat between user and volunteer
- Rating and review system
- Browse nearby verified volunteers

### Harassment Reporting
- Submit incident reports with photos
- Location-tagged reports
- Anonymous reporting option
- Admin review and forwarding to authorities
- Public danger heatmap visualization

### Additional Features
- Fake incoming call generator
- Audio/video evidence recording
- Country-specific emergency numbers (India, USA)
- Multi-language support (English, Tamil)
- NGO partner integration

## Tech Stack

- **Frontend:** Flutter/Dart
- **Backend:** Firebase (Auth, Firestore, Storage, Functions)
- **Maps:** Google Maps Flutter
- **Notifications:** Firebase Cloud Messaging
- **Verification:** IDfy (India), Checkr (USA)

## Screenshots

*Coming soon*

## Setup

1. Clone the repository
2. Run `flutter pub get`
3. Configure Firebase:
   - Add `google-services.json` (Android)
   - Add `GoogleService-Info.plist` (iOS)
4. Add Google Maps API key to `AndroidManifest.xml` and `Info.plist`
5. Deploy Firebase Functions: `cd functions && npm install && firebase deploy --only functions`
6. Run the app: `flutter run`

## Configuration

### Firebase Remote Config Keys
- `google_maps_api_key` - Google Maps API key
- `idfy_api_key` - IDfy API key for India KYC
- `checkr_api_key` - Checkr API key for USA background checks
- `bgv_skip_api_calls` - Skip BGV for testing
- `id_verified_radius_*` - Service radius for ID-verified volunteers
- `bgv_verified_radius_*` - Service radius for BGV-verified volunteers

### Environment
- Minimum SDK: Android 21+ / iOS 12+
- Flutter: 3.9.2+
- Dart: 3.0+

## Project Structure

```
lib/
├── config/           # Country configs, environment
├── models/           # Data models
├── providers/        # State management
├── screens/          # UI screens
│   ├── admin/        # Admin dashboard
│   ├── auth/         # Login screens
│   └── volunteer/    # Volunteer screens
├── services/         # Business logic
└── main.dart         # Entry point

functions/            # Firebase Cloud Functions
```

## Documentation

- [Implemented Features](IMPLEMENTED.md) - Detailed feature documentation
- [TODO](TODO.md) - Planned features and improvements

## License

Proprietary - All rights reserved

## Contact

For support or inquiries, please contact the development team.
