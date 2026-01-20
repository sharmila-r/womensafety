
# Google Play Console - Permission Declarations

Copy and paste these responses into Play Console.

---

## Foreground Service Permission

**Does your app use foreground services?**
> Yes

**Foreground Service Type:** `location`

**Explanation:**
> Kaavala uses foreground service with location to provide continuous live location sharing during emergency SOS situations and Safe Journey tracking. When a user activates SOS or starts a journey, the app needs to continuously share their real-time location with emergency contacts until the emergency is resolved or they reach their destination safely. This is critical for user safety and cannot function in the background without a foreground service.

---

## Background Location (ACCESS_BACKGROUND_LOCATION)

**Why does your app need background location access?**
> Kaavala is a personal safety app that requires background location access to continuously share the user's real-time location with their trusted emergency contacts during active SOS emergencies and Safe Journey tracking sessions. This ensures that even if the user's phone screen is off or they switch to another app during an emergency, their location continues to be shared with people who can help them.

**Core functionality:**
> Emergency SOS alerts and Safe Journey real-time tracking

---

## Camera Permission

**Why does your app need camera access?**
> Kaavala allows users to discreetly record video evidence during unsafe situations. This evidence can be stored securely and shared with authorities if needed. The camera is only accessed when the user explicitly initiates video recording from the Evidence Recording feature.

**Core functionality:**
> Video evidence recording for personal safety documentation

---

## Microphone / Record Audio Permission

**Why does your app need microphone access?**
> Kaavala allows users to discreetly record audio evidence during unsafe situations. This is essential for documenting verbal threats, harassment, or other safety incidents. Audio recordings are stored securely and can be shared with authorities. The microphone is only accessed when the user explicitly initiates audio recording.

**Core functionality:**
> Audio evidence recording for personal safety documentation

---

## SMS Permission (SEND_SMS)

**Why does your app need SMS permission?**
> Kaavala sends automated emergency SMS alerts to the user's pre-configured trusted contacts when they activate the SOS feature. The SMS contains the user's live location and emergency message. This is critical because SMS works even when internet connectivity is unavailable, ensuring emergency alerts reach contacts in all situations.

**Core functionality:**
> Send emergency SOS alerts with location to trusted contacts

---

## Phone Permission (CALL_PHONE)

**Why does your app need phone call permission?**
> Kaavala can automatically initiate emergency phone calls to the user's trusted contacts or emergency services when SOS is activated. Additionally, the Fake Call feature allows users to trigger a simulated incoming call to help them exit uncomfortable situations safely.

**Core functionality:**
> Emergency calls to trusted contacts and Fake Call safety feature

---

## Contacts Permission (READ_CONTACTS)

**Why does your app need contacts access?**
> Kaavala allows users to easily import their trusted emergency contacts from their phone's contact list. This simplifies the setup process and ensures users can quickly configure who should be notified during emergencies.

**Core functionality:**
> Import trusted emergency contacts for SOS alerts

---

## Bluetooth Permissions

**Why does your app need Bluetooth access?**
> Kaavala supports external Bluetooth Low Energy (BLE) panic buttons. Users can connect a discreet BLE button that triggers SOS alerts when pressed, allowing them to send emergency alerts without taking out their phone - useful in dangerous situations where using a phone might escalate the threat.

**Core functionality:**
> Connect BLE panic buttons for discreet SOS activation

---

## Summary Statement (for general declaration)

> Kaavala is a women's safety application designed to help users feel safe in emergency situations. The app requires location permissions to share real-time position with emergency contacts during SOS alerts and journey tracking. Camera and microphone access enables evidence recording. SMS and phone permissions allow sending emergency alerts and making emergency calls. Contact access simplifies adding trusted contacts. Bluetooth enables external panic button support. All sensitive features require explicit user action and are used solely for personal safety purposes.

