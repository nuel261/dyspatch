# Dyspatch

| Folder | What |
|---|---|
| `app/` | Flutter customer app (Android & iOS) — see `app/FIREBASE_AND_SETUP.md` |
| `backend/` | PHP/MySQL API and admin panel at https://app.dyspatch.com.ng/backend (website: https://dyspatch.com.ng) — see `backend/README.md` |

**Android builds:** every push to `main` that touches `app/` runs *Actions → Build signed Android APK*.
Download the signed `.apk` (and Play Store `.aab`) from the run's **Artifacts**.
Required repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_PROPERTIES`
(optional `GOOGLE_SERVICES_JSON` if the file isn't committed).
