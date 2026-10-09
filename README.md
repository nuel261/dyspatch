# Dyspatch

| Folder | What |
|---|---|
| `app/` | Flutter customer app (Android & iOS) — see `app/FIREBASE_AND_SETUP.md` |
| `backend/` | PHP/MySQL API, admin panel and public tracking for https://dyspatch.bitprofil.com — see `backend/README.md` |

**Android builds:** every push to `main` that touches `app/` runs *Actions → Build signed Android APK*.
Download the signed `.apk` (and Play Store `.aab`) from the run's **Artifacts**.
Required repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_PROPERTIES`
(optional `GOOGLE_SERVICES_JSON` if the file isn't committed).
