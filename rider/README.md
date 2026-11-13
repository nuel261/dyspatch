# Dyspatch Rider (Flutter)

The rider app for Dyspatch. It uses the same backend, database and admin as the customer app
and the website: `https://app.dyspatch.com.ng/backend/api` (override with `--dart-define=API_HOST=...`).

## What riders can do
- Sign up / log in with phone + OTP (`role: rider`), then add name, vehicle, plate, city and photo
- Verify their ID (NIN, driver's licence, voter's card, BVN) — reviewed in Admin → Verifications
- Go online / offline. While online the app shares GPS in the background through an Android
  foreground service ("You're online" notification) so customers see the rider move
- Receive job offers with a loud alert and a countdown; accept or decline. Who gets offers
  (nearest first / nearest few / everyone nearby) is set in Admin → Settings → Dispatch
- Complete deliveries: pickup code from the sender → start trip → arrived (recipient gets the
  delivery code by SMS) → delivery code + optional proof photo. Navigate, call/SMS, report a problem, SOS
- Earnings: wallet, transactions, bank accounts, withdrawals
- Notifications, dark mode, support

## Push notifications
Job offers are pushed on the `dyspatch_jobs` channel with the `job_alert` sound
(`android/app/src/main/res/raw/job_alert.wav`). Push needs:
1. Firebase console → project **dyspatch-bc9cc** → Add app → Android, package `com.dyspatch.rider`
   → save `google-services.json` as `android/app/google-services.json` (or the `RIDER_GOOGLE_SERVICES_JSON` CI secret).
2. iOS: add app `com.dyspatch.rider`, put `GoogleService-Info.plist` in `ios/Runner/`, and upload an
   APNs key in Firebase → Cloud Messaging.
3. The Firebase service-account key in Admin → Settings → Push notifications (shared with the customer app).

Without the Firebase file the app still builds and works: offers arrive by polling every 4 seconds
while the rider is online, with the same alert sound.

## Build
```
flutter pub get
flutter build apk --release
```
CI: `.github/workflows/rider-apk.yml` builds the APK/AAB on every push to `rider/`.
