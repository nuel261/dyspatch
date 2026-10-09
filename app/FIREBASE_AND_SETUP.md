# Dyspatch app — setup

The app talks to the backend at **https://dyspatch.bitprofil.com/api**
(change it in `lib/core/api/api_config.dart`, or build with `--dart-define=API_HOST=https://…`).

## 1. Firebase (new project: `dyspatch-bc9cc`)

The old Firebase config (`dyspatch-a84ea`) was removed. A new Firebase project **Dyspatch**
(`dyspatch-bc9cc`) was created with two apps registered:

| Platform | ID |
|---|---|
| Android | package `com.dyspatch.delivery` |
| iOS | bundle ID `com.dyspatch.delivery` (changed from `com.example.dyspatchApp`) |

Add the two config files (the Android build fails until `google-services.json` is present):

1. Firebase console → Dyspatch → ⚙ Project settings → **Your apps**
2. **Dyspatch Android** → download `google-services.json` → put it in `android/app/`
3. **Dyspatch iOS** → download `GoogleService-Info.plist` → open `ios/Runner.xcworkspace` in Xcode
   and drag it into the **Runner** folder (tick "Copy items if needed" and the Runner target)

(Or run `dart pub global activate flutterfire_cli && flutterfire configure --project=dyspatch-bc9cc`,
which downloads both files for you.)

### Google sign-in
1. Firebase → Authentication → Sign-in method → enable **Google**.
2. Android: add your SHA-1 and SHA-256 (`cd android && ./gradlew signingReport`, debug + release/Play
   App Signing keys) under Project settings → Dyspatch Android → **Add fingerprint**, then download
   `google-services.json` again.
3. iOS: download `GoogleService-Info.plist` again, copy its `REVERSED_CLIENT_ID` value and replace
   `com.googleusercontent.apps.REPLACE_WITH_REVERSED_CLIENT_ID` in `ios/Runner/Info.plist`.

### Push notifications
- **Android**: works once `google-services.json` is in place.
- **iOS**: in the Apple Developer portal create an **APNs Auth Key (.p8)**, then Firebase → Project
  settings → Cloud Messaging → Apple app configuration → upload it (Key ID + Team ID). In Xcode →
  Runner → Signing & Capabilities, make sure **Push Notifications** and **Background Modes → Remote
  notifications** are on (the entitlements file and Info.plist entries are already added).
- **Server side**: Firebase → Project settings → Service accounts → **Generate new private key**, then
  paste/upload that JSON in the admin panel → Settings → Push notifications. Use "Send a test push"
  there to confirm.

## 2. Build

```bash
flutter pub get
flutter run                      # debug
flutter build appbundle          # Play Store
flutter build ipa                # App Store (after setting your Team in Xcode)
```
Android release signing still uses the debug key in `android/app/build.gradle.kts` — configure an
upload keystore before publishing to the Play Store.

## 3. What changed in the app
- Real backend for everything: phone OTP sign-in (4-digit, 30-min expiry, locks after 3 tries),
  Google sign-in, profile & photo, deliveries, quotes, wallet, top-ups, transfers, bank accounts,
  notifications, saved places, 2FA, password, business verification, logout.
- Create delivery: live address search, "use my current location", recipient validation, live price
  (standard/express), wallet or cash payment, top-up shortcut when the balance is short.
- Tracking: any Track ID or parcel code, live rider position every 5s, road route, ETA, timeline,
  parcels, pickup and delivery codes, share link, call/SMS rider, SOS, cancel. Guests can track too.
- Push notifications (FCM) for every delivery and wallet event, with taps opening the right delivery.
- Removed all mock data; fixed back buttons that popped the whole app from bottom-nav tabs,
  onboarding that never finished, and the 6-digit OTP that accepted any code.
- Android: targetSdk 35, notification permission, removed unused background-location permission.
  iOS: bundle ID, push entitlement, camera/photo permission texts.
