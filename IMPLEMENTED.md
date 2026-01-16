# SafeHer - Implemented Features

> Last Updated: January 2025

## Overview

SafeHer (Kavalan) is a women's safety app with SOS alerts, location sharing, volunteer escort system, and harassment reporting. This document details all implemented features.

---

## Phase 1 - Foundation ✅

### Country Configuration
- **Base country config** (`lib/config/country_config.dart`)
  - Abstract base class for country-specific settings
  - Emergency numbers, helplines, NGO contacts
  - Phone code and locale settings

- **India Configuration** (`lib/config/countries/india.dart`)
  - Emergency: 112
  - Women Helpline: 181
  - Women Police: 1091
  - NCW Helpline: 7827-170-170
  - Aadhaar-based verification support

- **USA Configuration** (`lib/config/countries/usa.dart`)
  - Emergency: 911
  - National DV Hotline: 1-800-799-7233
  - RAINN: 1-800-656-4673
  - SSN-based verification support

### Firebase Setup ✅
- Firebase Core initialization
- Firebase Auth with Phone OTP
- Cloud Firestore for data storage
- Firebase Storage for file uploads
- Security rules configured

### User Authentication ✅
- **Phone OTP Authentication** (`lib/services/firebase_service.dart`)
  - Send OTP to phone number
  - Verify OTP code
  - Auto-retrieval on Android
  - Re-send functionality
- Auth state persistence
- User profile storage in Firestore

---

## Phase 2 - Core Features ✅

### Cloud Contacts Sync ✅
- Firestore collection for trusted contacts
- Real-time sync with local storage
- Offline support with SharedPreferences fallback

### Background Location Tracking ✅
- **Background Service** (`lib/services/background_location_service.dart`)
  - Continuous location tracking
  - Configurable update interval
  - Foreground notification (Android)
  - Battery-efficient implementation
- **Features:**
  - Real-time location updates
  - Distance tracking
  - Stationary detection alerts
  - Location history storage
  - SOS trigger from background

### Harassment Report Submission ✅
- **Report Model** (`lib/models/harassment_report.dart`)
  - Harassment type categorization
  - Location with address
  - Photo evidence support
  - Status tracking
- Firebase Storage for images
- Offline report queue

---

## Phase 3 - Volunteer System ✅

### Volunteer Registration ✅
- **3-Stage Progressive Verification Flow** (`lib/screens/volunteer/volunteer_registration_screen.dart`)

  | Stage | Status | Capabilities | Cost | Time |
  |-------|--------|--------------|------|------|
  | 1. Sign Up | REGISTERED | View only | Free | Instant |
  | 2. Basic KYC | VERIFIED | 500m radius | ₹50-100 / $5-15 | Instant |
  | 3. Full BGV | ACTIVE | 5km radius | ₹500-800 / $32-102 | 2-5 days |

- **Volunteer Model** (`lib/models/volunteer.dart`)
  - Personal info (name, phone, DOB, photo, bio)
  - KYC fields (aadhaarVerified, faceMatchScore, livenessPasssed)
  - Verification level tracking
  - Availability settings
  - Service radius based on verification
  - Rating and escort statistics

### ID Verification (KYC) ✅
- **BGV Service** (`lib/services/bgv_service.dart`)
- **India (IDfy Integration):**
  - Aadhaar verification via API
  - Face match with Aadhaar photo
  - Liveness detection (blink check)
  - API: `https://eve.idfy.com/v3/tasks/async/`
- **USA (Checkr Integration):**
  - Government ID upload
  - Selfie verification
  - SSN verification

### Background Check Integration ✅
- **India (IDfy):**
  - Criminal court records (District, High Court, Supreme Court)
  - Address verification (digital or physical)
  - Police verification
  - API: `https://bgv.idfy.com/profiles`
- **USA (Checkr):**
  - SSN trace
  - National criminal records
  - Sex offender registry
- **Webhook handlers** for async results
- **OnGrid** as alternative India provider

### Volunteer Service ✅
- **Service** (`lib/services/volunteer_service.dart`)
  - Registration with DOB
  - ID document upload
  - Selfie upload
  - KYC submission with results
  - Background check initiation
  - Availability management
  - Location updates
  - Escort request handling
  - Rating system

---

## Phase 4 - Reporting Pipeline ✅

### Admin Dashboard ✅
- **Dashboard Screen** (`lib/screens/admin/admin_dashboard_screen.dart`)
  - Tab-based navigation
  - Admin authentication check

- **Statistics Tab** (`lib/screens/admin/stats_tab.dart`)
  - Total reports, pending, verified counts
  - Volunteer statistics
  - Active/pending volunteer counts

- **Reports Tab** (`lib/screens/admin/reports_tab.dart`)
  - Filter by status (pending, under review, verified, rejected, forwarded)
  - Report detail view
  - Status update actions
  - Forward to authorities (Police, NGO, Helpline)

- **Volunteers Tab** (`lib/screens/admin/volunteers_tab.dart`)
  - Filter by verification level
  - Volunteer detail view
  - Approve/Reject actions
  - NGO vouching

- **Audit Logs Tab** (`lib/screens/admin/audit_logs_tab.dart`)
  - Action history tracking
  - Admin action logging

### Admin Service ✅
- **Service** (`lib/services/admin_service.dart`)
  - Report status management
  - Volunteer verification management
  - Dashboard statistics
  - Audit log creation
  - Report forwarding

### NGO Partner Integration ✅
- **NGO Service** (`lib/services/ngo_service.dart`)
- **NGO Partner Model:**
  - Registration details
  - Contact person info
  - Focus areas
  - Service radius
  - Capabilities (alerts, vouching, reports)

- **Features:**
  - NGO registration and verification
  - Volunteer vouching (grants TRUSTED status)
  - Alert routing to nearby NGOs
  - Report forwarding
  - Alert acknowledgment and response tracking

- **Admin Functions:**
  - Pending applications review
  - NGO verification/rejection
  - Capability assignment
  - Suspension management

### Public Heatmap ✅
- **Heatmap Service** (`lib/services/heatmap_service.dart`)
  - Grid-based clustering (~100m cells)
  - Minimum 3 reports for privacy
  - Recency-weighted intensity scoring
  - Severity classification (low/medium/high)

- **Heatmap Screen** (`lib/screens/danger_heatmap_screen.dart`)
  - Google Maps visualization
  - Circle overlays for danger zones
  - Risk level legend
  - Adjustable radius slider
  - Quick statistics banner
  - Cluster detail modal with safety tips
  - City-wide statistics dialog

---

## Phase 5 - Push Notifications ✅

### Firebase Cloud Messaging ✅
- **Push Notification Service** (`lib/services/push_notification_service.dart`)
  - FCM initialization and token management
  - Permission handling (iOS/Android)
  - Token storage in Firestore
  - Foreground message handling
  - Background message handling
  - Local notification display

- **Notification Channels (Android):**
  - `sos_alerts` - High priority SOS alerts
  - `escort_requests` - Escort volunteer notifications
  - `general` - General app notifications

- **Features:**
  - Critical alerts for SOS (bypasses DND on iOS)
  - Full-screen intent for emergency notifications
  - Custom notification colors and icons
  - Token refresh handling

### Cloud Functions ✅
- **Notification Queue Processor** (`functions/index.js`)
  - Firestore trigger for notification queue
  - Batch processing for multiple tokens
  - Invalid token cleanup
  - Delivery status tracking

- **SOS Alert Function:**
  - Callable function for SOS alerts
  - Sends to all trusted contacts
  - Includes location and maps URL
  - Critical priority on both platforms

- **Escort Request Function:**
  - Notifies nearby volunteers
  - Includes event and location details

- **BGV Webhook Handler:**
  - Receives verification results
  - Updates volunteer status
  - Notifies volunteer of result

- **Cleanup Function:**
  - Scheduled daily cleanup
  - Removes old notifications (7+ days)

---

## Phase 6 - Wearable BLE Button Support ✅

### BLE Panic Button Integration ✅
- **BLE Button Service** (`lib/services/ble_button_service.dart`)
  - Generic BLE device scanning and pairing
  - Auto-detection of button types (Flic, iTag, Tile, Nut, generic)
  - Button press detection (single, double, long press)
  - Auto-reconnection on disconnect
  - Token-based device persistence

- **Button Model** (`lib/models/ble_button.dart`)
  - Configurable actions per press type
  - Supported devices: Flic 2, iTag, Tile, Nut Finder, generic BLE

- **BLE Button Screen** (`lib/screens/ble_button_screen.dart`)
  - Device scanning UI
  - Pairing flow
  - Button configuration (customize press actions)
  - Connection status monitoring

- **Supported Actions:**
  - Check-in (I'm safe)
  - Share location
  - Trigger full SOS alert
  - Call emergency services
  - Start recording (future)

- **Default Configuration:**
  - Single press → Check-in
  - Double press → Share location
  - Long press (2+ sec) → Trigger SOS

---

## Technical Implementation

### Firebase Collections
```
firestore/
├── users/                    # User profiles and settings
├── userTokens/               # FCM tokens for push notifications
├── volunteers/               # Volunteer profiles with KYC data
├── harassmentReports/        # Incident reports
├── escortRequests/           # Escort service requests
├── volunteerRatings/         # Volunteer feedback
├── ngoPartners/              # NGO partner organizations
├── ngoAlerts/                # Alerts sent to NGOs
├── sosAlerts/                # SOS alert history
├── notificationQueue/        # Pending notifications for Cloud Functions
└── auditLogs/                # Admin action history
```

### Dependencies Added
```yaml
# Firebase
firebase_core: ^3.8.1
firebase_auth: ^5.3.4
cloud_firestore: ^5.6.0
firebase_storage: ^12.4.0
firebase_messaging: ^15.1.6

# Local Notifications
flutter_local_notifications: ^18.0.1

# Bluetooth Low Energy
flutter_blue_plus: ^1.35.2

# Background Services
flutter_background_service: ^5.0.10

# HTTP Client (for BGV APIs)
http: ^1.2.2

# Maps
google_maps_flutter: ^2.10.0
```

### Cloud Functions
```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  }
}
```

### Key Files
| File | Purpose |
|------|---------|
| `lib/config/country_config.dart` | Country-specific configurations |
| `lib/services/firebase_service.dart` | Firebase Auth wrapper |
| `lib/services/push_notification_service.dart` | FCM push notifications |
| `lib/services/ble_button_service.dart` | BLE panic button support |
| `lib/services/volunteer_service.dart` | Volunteer operations |
| `lib/services/bgv_service.dart` | Background verification APIs |
| `lib/services/admin_service.dart` | Admin operations |
| `lib/services/heatmap_service.dart` | Danger zone clustering |
| `lib/services/ngo_service.dart` | NGO partner management |
| `lib/services/background_location_service.dart` | Background tracking |
| `lib/models/volunteer.dart` | Volunteer data model |
| `lib/models/ble_button.dart` | BLE button model |
| `lib/screens/volunteer/volunteer_registration_screen.dart` | 3-stage registration |
| `lib/screens/admin/admin_dashboard_screen.dart` | Admin dashboard |
| `lib/screens/danger_heatmap_screen.dart` | Heatmap visualization |
| `lib/screens/ble_button_screen.dart` | BLE button pairing/config |
| `functions/index.js` | Cloud Functions for notifications |

---

## Verification Levels

| Level | Badge | Service Radius | Requirements |
|-------|-------|----------------|--------------|
| `unverified` | - | 0 | Just registered |
| `phoneVerified` | Registered | 0 | Phone OTP verified |
| `idVerified` | Verified | 500m | KYC complete (Aadhaar/ID + Face Match) |
| `backgroundChecked` | Active | 5km | Full BGV cleared |
| `trusted` | Trusted | 5km | Vouched by verified NGO |

---

## API Integrations

### IDfy (India)
- **Eve API** (KYC): `https://eve.idfy.com/v3/tasks/async/`
  - `/verify_with_source/ind_aadhaar`
  - `/face_match`
  - `/liveness`
- **BGV API**: `https://bgv.idfy.com/profiles`

### Checkr (USA)
- **Base URL**: `https://api.checkr.com/v1/`
  - `/candidates` - Create candidate
  - `/invitations` - Background check invitation

### OnGrid (India Alternative)
- **Base URL**: `https://api.ongrid.in/v1/`
  - `/verification/initiate`
