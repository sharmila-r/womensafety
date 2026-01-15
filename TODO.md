# SafeHer - Development TODO

> Last Updated: January 2025

## Legend
- ✅ Completed
- 🔄 In Progress
- ⏳ Pending
- 🔮 Future Enhancement

---

## Phase 1 - Foundation ✅

### Country Configuration ✅
- [x] Create base country config class
- [x] Create India configuration (112, 181, 1091)
- [x] Create USA configuration (911, hotlines)
- [x] Country detection & selection

### Firebase Setup ✅
- [x] Create Firebase project
- [x] Add Android configuration
- [x] Add iOS configuration
- [x] Add Firebase dependencies
- [x] Initialize Firebase in main.dart
- [x] Set up Firestore security rules
- [x] Set up Storage rules

### User Authentication ✅
- [x] Phone OTP authentication
- [x] Auth state persistence
- [x] User profile in Firestore

---

## Phase 2 - Core Features ✅

### Cloud Contacts Sync ✅
- [x] Firestore collection for contacts
- [x] Migrate TrustedContact model
- [x] Real-time sync
- [x] Offline support

### Background Location Tracking ✅
- [x] Background location permissions
- [x] flutter_background_service implementation
- [x] Location history in Firestore
- [x] Stationary detection
- [ ] ⏳ Geofencing for safe zones
- [ ] ⏳ Safety timeline view

### Report Submission ✅
- [x] Firestore report storage
- [x] Image upload to Storage
- [x] Report status tracking
- [ ] ⏳ Offline report queue with auto-sync

---

## Phase 3 - Volunteer System ✅

### Volunteer Registration ✅
- [x] 3-stage registration flow
- [x] Volunteer profile model
- [x] Volunteer dashboard screen
- [x] Service radius based on verification

### ID Verification (KYC) ✅
- [x] IDfy integration (India)
- [x] Checkr integration (USA)
- [x] Aadhaar verification
- [x] Face match
- [x] Liveness detection
- [x] Document upload

### Background Check ✅
- [x] Criminal court records check
- [x] Address verification
- [x] Police verification
- [x] Webhook handlers for results
- [ ] ⏳ Periodic re-verification automation

### Escort Matching
- [x] Volunteer proximity calculation
- [x] Availability checking
- [ ] ⏳ Push notification for requests
- [ ] ⏳ Real-time escort tracking map
- [x] Post-escort rating system

---

## Phase 4 - Reporting Pipeline ✅

### Admin Dashboard ✅
- [x] Statistics tab
- [x] Reports review tab
- [x] Volunteers management tab
- [x] Audit logs tab
- [ ] ⏳ Flutter Web version for desktop access

### NGO Partner Integration ✅
- [x] NGO registration system
- [x] NGO verification workflow
- [x] Volunteer vouching
- [x] Alert routing to NGOs
- [x] Report forwarding
- [ ] ⏳ Partner portal web app

### Public Heatmap ✅
- [x] Anonymized data aggregation
- [x] Google Maps visualization
- [x] Risk level classification
- [x] City-wide statistics
- [ ] ⏳ Public web view for heatmap
- [ ] ⏳ Time-based filtering (week/month/year)

### Authority Integration
- [ ] ⏳ Research local authority APIs
- [ ] ⏳ India NCRB integration
- [ ] ⏳ USA local PD APIs
- [x] Manual forwarding (implemented)
- [ ] ⏳ Report reference number tracking

---

## Pending Features

### High Priority ⏳

#### Push Notifications
- [ ] Firebase Cloud Messaging setup
- [ ] SOS alert notifications to contacts
- [ ] Escort request notifications to volunteers
- [ ] Alert notifications to NGOs
- [ ] Report status update notifications

#### Real-time Escort Tracking
- [ ] Live location sharing during escort
- [ ] Map view for user and volunteer
- [ ] ETA calculation
- [ ] Route visualization

#### Geofencing
- [ ] Define safe zones (home, work, etc.)
- [ ] Alert when entering/leaving zones
- [ ] Automatic check-in notifications

### Medium Priority ⏳

#### UI/UX Improvements
- [ ] Onboarding screens
- [ ] Dark mode support
- [ ] Language localization (Hindi for India)
- [ ] Accessibility improvements

#### Safety Timeline
- [ ] Visual timeline of location history
- [ ] Activity log view
- [ ] Export location history

#### Offline Enhancements
- [ ] Offline report queue with auto-sync
- [ ] Offline contact access
- [ ] Cached map tiles

### Low Priority / Future 🔮

#### Wearable Integration
- [ ] Apple Watch app
- [ ] Wear OS app
- [ ] Panic button on wearables

#### Audio Recording
- [ ] Background audio recording for evidence
- [ ] Secure storage
- [ ] Transcription

#### AI Features
- [ ] Voice-activated SOS
- [ ] Anomaly detection in location patterns
- [ ] Smart danger alerts

#### Additional Integrations
- [ ] Uber/Lyft integration for safe rides
- [ ] Public transport safety integration
- [ ] Hospital/clinic locator

---

## Technical Debt

### Code Quality
- [ ] Add unit tests for services
- [ ] Add integration tests
- [ ] Widget tests for screens
- [ ] Fix deprecation warnings (withOpacity)

### Performance
- [ ] Optimize Firestore queries with indexes
- [ ] Implement pagination for lists
- [ ] Image compression before upload
- [ ] Cache optimization

### Security
- [ ] Encrypt sensitive data at rest
- [ ] API key management (environment variables)
- [ ] Rate limiting
- [ ] Input validation improvements

---

## Environment Setup Required

### API Keys Needed
```
# IDfy (India KYC/BGV)
IDFY_API_KEY=
IDFY_ACCOUNT_ID=

# Checkr (USA Background Check)
CHECKR_API_KEY=

# Google Maps
GOOGLE_MAPS_API_KEY=

# Firebase (already configured)
# - google-services.json (Android)
# - GoogleService-Info.plist (iOS)
```

### Firebase Console Tasks
- [ ] Enable Phone Authentication
- [ ] Create Firestore indexes for queries
- [ ] Set up Cloud Functions for webhooks
- [ ] Configure FCM for push notifications

---

## Deployment Checklist

### Android
- [ ] Update app signing keys
- [ ] Configure ProGuard rules
- [ ] Test release build
- [ ] Prepare Play Store listing
- [ ] Privacy policy URL

### iOS
- [ ] Update provisioning profiles
- [ ] Configure capabilities (push, background location)
- [ ] Test TestFlight build
- [ ] Prepare App Store listing
- [ ] App privacy details

### Backend
- [ ] Set up production Firebase project
- [ ] Configure webhook endpoints
- [ ] Set up monitoring/alerts
- [ ] Database backup strategy

---

## Notes

- All volunteer data must be encrypted at rest
- GDPR compliance needed for EU expansion
- Consider panic button widget for home screen
- Background check costs: India ₹500-800, USA $32-102
- Annual re-verification required for volunteers
