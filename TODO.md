# SafeHer - Development Roadmap

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        SafeHer App                              │
├─────────────────────────────────────────────────────────────────┤
│  Firebase Auth (Phone OTP)  │  Firestore DB  │  Cloud Storage   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Users      │  │  Volunteers  │  │  Reports             │  │
│  │  - contacts  │  │  - profile   │  │  - local storage     │  │
│  │  - settings  │  │  - ID docs   │  │  - admin dashboard   │  │
│  │  - location  │  │  - bg check  │  │  - NGO partners      │  │
│  └──────────────┘  │  - rating    │  │  - public heatmap    │  │
│                    │  - available │  │  - authority API     │  │
│                    └──────────────┘  └──────────────────────────┘
├─────────────────────────────────────────────────────────────────┤
│  Country Configs: India (112, 181, 1091) │ USA (911, hotlines) │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1 - Foundation

### Country Configuration
- [ ] Create `lib/config/countries/base_country.dart` - Base class for country config
- [ ] Create `lib/config/countries/india.dart` - India emergency numbers & helplines
  - Emergency: 112
  - Women Helpline: 181
  - Women Police: 1091
  - NCW Helpline: 7827-170-170
  - Local NGOs: SafeCity, Sakhi, etc.
- [ ] Create `lib/config/countries/usa.dart` - USA emergency numbers & helplines
  - Emergency: 911
  - National DV Hotline: 1-800-799-7233
  - RAINN: 1-800-656-4673
  - Local resources by state
- [ ] Create `lib/config/country_config.dart` - Country detection & selection
- [ ] Add country selector in settings screen

### Firebase Setup
- [ ] Create Firebase project in Firebase Console
- [ ] Add Android configuration (`google-services.json`)
- [ ] Add iOS configuration (`GoogleService-Info.plist`)
- [ ] Add Firebase dependencies to `pubspec.yaml`
  - firebase_core
  - firebase_auth
  - cloud_firestore
  - firebase_storage
- [ ] Initialize Firebase in `main.dart`
- [ ] Set up Firestore security rules
- [ ] Set up Firebase Storage rules

### User Authentication
- [ ] Implement phone OTP authentication
- [ ] Add email/password as backup auth method
- [ ] Create user profile screen
- [ ] Store user profile in Firestore
- [ ] Handle auth state persistence

---

## Phase 2 - Core Features

### Cloud Contacts Sync
- [ ] Create Firestore collection structure for contacts
- [ ] Migrate `TrustedContact` model to support Firestore
- [ ] Update `AppProvider` to sync with Firestore
- [ ] Add offline support with local cache
- [ ] Implement real-time sync listeners

### Background Location Tracking
- [ ] Configure background location permissions (Android & iOS)
- [ ] Implement `flutter_background_service` for continuous tracking
- [ ] Create location history collection in Firestore
- [ ] Add battery optimization settings
- [ ] Implement geofencing for safe zones
- [ ] Create safety timeline view

### Report Submission to Firebase
- [ ] Update `HarassmentReport` model for Firestore
- [ ] Upload report images to Firebase Storage
- [ ] Store reports in Firestore with encryption
- [ ] Add report status tracking (pending, reviewed, forwarded)
- [ ] Implement offline report queue

---

## Phase 3 - Volunteer System

### Volunteer Registration
- [ ] Create volunteer registration flow
- [ ] Design volunteer profile model
  - Personal info (name, phone, photo)
  - Verification status
  - Availability schedule
  - Service radius
  - Rating & reviews
- [ ] Create volunteer dashboard screen
- [ ] Add volunteer mode toggle in app

### ID Verification
- [ ] Research verification providers (Onfido, Checkr, Jumio)
- [ ] Integrate ID document upload
- [ ] Implement selfie verification
- [ ] Store verification status in Firestore
- [ ] Create verification status badges

### Background Check Integration
- [ ] Partner with background check provider
- [ ] Implement background check API integration
- [ ] Handle check status updates (pending, cleared, flagged)
- [ ] Create admin approval workflow
- [ ] Add periodic re-verification

### Escort Matching Algorithm
- [ ] Calculate volunteer proximity to request location
- [ ] Factor in volunteer ratings
- [ ] Check volunteer availability
- [ ] Implement request notification system
- [ ] Create accept/decline flow for volunteers
- [ ] Add real-time escort tracking
- [ ] Implement post-escort rating system

---

## Phase 4 - Reporting Pipeline

### Admin Dashboard (Web)
- [ ] Create Flutter Web or React admin dashboard
- [ ] Implement admin authentication
- [ ] Display pending reports queue
- [ ] Add report review interface
- [ ] Create forwarding workflow
- [ ] Add analytics & statistics
- [ ] Implement user/volunteer management

### NGO Partner Integration
- [ ] Research partner NGOs in India & USA
  - India: SafeCity, Sakhi, Jagori, etc.
  - USA: RAINN, NCADV, local organizations
- [ ] Design API for NGO data sharing
- [ ] Implement secure data transfer
- [ ] Create partner portal for report access
- [ ] Add consent management for data sharing

### Public Heatmap
- [ ] Design heatmap data aggregation (anonymized)
- [ ] Create heatmap collection in Firestore
- [ ] Implement map overlay with incident density
- [ ] Add time-based filtering (last week, month, year)
- [ ] Create public web view for heatmap
- [ ] Ensure complete anonymization of data

### Authority API Integration
- [ ] Research local authority APIs (varies by region)
- [ ] India: Investigate NCRB integration options
- [ ] USA: Research local PD reporting APIs
- [ ] Implement manual forwarding as fallback
- [ ] Add report reference number tracking

---

## Firebase Collections Structure

```
firestore/
├── users/
│   ├── {userId}/
│   │   ├── profile (name, phone, email, country, createdAt)
│   │   ├── settings (autoAlert, stationaryMinutes, language)
│   │   └── contacts/ (subcollection)
│   │       └── {contactId}/ (name, phone, isEmergency)
│
├── volunteers/
│   ├── {volunteerId}/
│   │   ├── profile (name, phone, photo, bio)
│   │   ├── verification/
│   │   │   ├── idDocUrl
│   │   │   ├── idVerifiedAt
│   │   │   ├── bgCheckStatus (pending, cleared, flagged)
│   │   │   ├── bgCheckDate
│   │   │   └── verificationLevel (basic, full, trusted)
│   │   ├── availability/
│   │   │   ├── isAvailable
│   │   │   ├── schedule (day/time slots)
│   │   │   ├── serviceRadius (km)
│   │   │   └── currentLocation (geo)
│   │   └── stats/
│   │       ├── totalEscorts
│   │       ├── averageRating
│   │       └── ratingCount
│
├── reports/
│   ├── {reportId}/
│   │   ├── userId
│   │   ├── type (verbal, physical, stalking, cyber, etc.)
│   │   ├── description
│   │   ├── location (geo)
│   │   ├── address
│   │   ├── imageUrls []
│   │   ├── reportedAt
│   │   ├── status (pending, reviewed, forwarded, resolved)
│   │   ├── reviewedBy (adminId)
│   │   ├── reviewedAt
│   │   ├── forwardedTo (ngo, authority, heatmap)
│   │   └── isAnonymous
│
├── escortRequests/
│   ├── {requestId}/
│   │   ├── userId
│   │   ├── eventName
│   │   ├── eventLocation (geo)
│   │   ├── eventDateTime
│   │   ├── notes
│   │   ├── status (pending, confirmed, in_progress, completed, cancelled)
│   │   ├── assignedVolunteerId
│   │   ├── assignedAt
│   │   ├── completedAt
│   │   ├── userRating
│   │   └── userFeedback
│
├── heatmapData/
│   └── {geohash}/
│       ├── incidentCount
│       ├── lastUpdated
│       └── types {} (counts by harassment type)
│
└── locationHistory/
    └── {userId}/
        └── {timestamp}/
            ├── location (geo)
            ├── address
            └── accuracy
```

---

## Technical Decisions

### Database: Firebase
- **Why:** Easy setup, free tier sufficient for MVP, real-time sync, built-in auth
- **Collections:** users, volunteers, reports, escortRequests, heatmapData, locationHistory

### Volunteer Verification: Full Background Check
- **Level 1:** Phone OTP verification
- **Level 2:** Government ID upload + selfie verification (Onfido/Jumio)
- **Level 3:** Criminal background check (Checkr or regional provider)
- **Badge System:** Unverified → ID Verified → Background Cleared → Trusted (NGO vouched)

### Report Submission: Multi-Channel
1. **Firebase Storage:** All reports stored securely
2. **Admin Dashboard:** Manual review and triage
3. **NGO Partners:** Forwarded with user consent
4. **Public Heatmap:** Anonymized aggregate data
5. **Authorities:** API where available, manual forwarding otherwise

### Country Support: India & USA
- Separate config files for emergency numbers, helplines, NGOs
- Language support: English (default), Hindi (India)
- Region-specific features based on available APIs

---

## Dependencies to Add

```yaml
# Firebase
firebase_core: ^3.8.1
firebase_auth: ^5.3.4
cloud_firestore: ^5.6.0
firebase_storage: ^12.4.0

# Background Location
flutter_background_service: ^5.0.10
workmanager: ^0.5.2

# Maps & Heatmap
google_maps_flutter: ^2.10.0
flutter_map_heatmap: ^0.0.4

# Verification (TBD based on provider)
# onfido_sdk_flutter: ^x.x.x
```

---

## Milestones

| Phase | Target | Status |
|-------|--------|--------|
| Phase 1 | Foundation (Config + Firebase + Auth) | Not Started |
| Phase 2 | Core Features (Cloud Sync + Location + Reports) | Not Started |
| Phase 3 | Volunteer System (Registration + Verification + Matching) | Not Started |
| Phase 4 | Reporting Pipeline (Dashboard + NGO + Heatmap) | Not Started |

---

## Notes

- All sensitive data must be encrypted at rest
- GDPR/privacy compliance required for EU users (future)
- Consider adding panic button widget for home screen
- Audio recording feature for evidence (future)
- Integration with wearables (future)
