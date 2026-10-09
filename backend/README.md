# Dyspatch backend (PHP + MySQL)

Live at **https://dyspatch.bitprofil.com** — REST API, admin panel and public parcel tracking.

| Path | What |
|---|---|
| `/api/…` | REST API used by the customer app (and the rider app) |
| `/admin/` | Admin dashboard — same design language as dyspatch.com.ng |
| `/track?id=BEN-48213` | Public tracking page (works with item codes like `BEN-48213-02`) |
| `/t/{token}` | Shareable live-tracking link |

## Install on cPanel (≈10 minutes)
1. **Upload**: put the contents of this folder in the document root of `dyspatch.bitprofil.com`.
2. **Database**: cPanel → MySQL® Databases → create a database + user, grant ALL privileges.
3. **Installer**: open `https://dyspatch.bitprofil.com/install.php`, enter the DB details and your
   admin email/password. It creates the tables, seeds settings/zones and writes `config/config.php`.
4. **Delete `install.php`** from the server.
5. **Cron** (cPanel → Cron Jobs, every minute):
   `* * * * * php /home/USER/public_html/cron/run.php >/dev/null 2>&1`
   It runs the rider matching engine (45-second accept window), takes stale riders offline, alerts
   ops about orders nobody accepted, and cleans up.
6. **PHP**: 8.1+ with `pdo_mysql`, `curl`, `openssl`, `mbstring`, `fileinfo`. Folders `storage/`
   and `config/` must be writable. Enable HTTPS (AutoSSL).
7. Sign in at `/admin/` → **Settings** and fill in:
   - **Email** (SMTP host/user/password) → *Send test email*
   - **Push notifications** (Firebase service-account JSON for project `dyspatch-bc9cc`) → *Send test push*
   - **SMS (Termii)** — switch the driver from *Log only* to *Termii* before launch
   - Payments (Paystack/Flutterwave keys, webhook URLs shown there), ID verification provider,
     top-up bank account, pricing, commission, dispatch radius/timeouts, withdrawal fees.

## Business rules (all editable in Settings, nothing hard-coded)
- Money is stored in **kobo** everywhere.
- OTP: 4 digits, 30-minute expiry, locks after 3 wrong attempts.
- Matching: riders within 5 km of pickup; 45 s to accept before re-offer.
- Withdrawals: ₦500 minimum; requests before 17:00 WAT are due same day, later → next business day;
  fee is flat / percent / tiered; payout via Paystack, Flutterwave or manual (fallback).
- Zones: Benin City live; Lekki, VI, Ikeja, Lagos Island gated — launch from Admin → Zones.
- Pricing: minimum-fare or distance-only model, global or per zone; package and express multipliers.
- Providers sit behind interfaces (`includes/Providers.php`): payments, SMS, KYC, plus email
  (`Mailer.php`, native SMTP) and push (`Push.php`, FCM HTTP v1).

## Parcel tracking
Every order has a Track ID (`BEN-48213`) and every parcel inside it gets its own code
(`BEN-48213-01`, `-02`…). Admins can update each parcel's status, add tracking notes, assign or
reassign riders, regenerate the delivery code and print 100×150 mm labels with QR codes.
Customers get push + email at each step: rider assigned → picked up → in transit → arrived → delivered.

## Main API endpoints
Auth: `POST /auth/otp/request`, `POST /auth/otp/verify`, `POST /auth/google`, `POST /auth/logout`
Profile: `GET|PUT /me`, `POST /me/password`, `POST /me/2fa/request|verify`, `POST /devices`
Orders: `POST /orders/quote`, `POST /orders`, `GET /orders`, `GET /orders/{trackId}`,
`GET /orders/{trackId}/rider-location`, `POST /orders/{trackId}/share-link|sos|cancel|regenerate-code|rate`
Public: `GET /track/{code}`, `GET /shared/{token}`, `GET /places/search`, `GET /config`, `GET /banks`
Wallet: `GET /wallet`, `GET /wallet/transactions`, `POST /wallet/topups`, `POST /wallet/topups/{ref}/sent`,
`POST /wallet/topups/card`, `POST /wallet/withdraw`, `GET|POST|DELETE /bank-accounts`
Rider app: `/rider/me`, `/rider/kyc`, `/rider/online`, `/rider/location`, `/rider/offers`,
`/rider/offers/{id}/accept|decline`, `/rider/orders/{id}/pickup|en-route|arrived|deliver|fail`, `/rider/sos`
Webhooks: `POST /webhooks/paystack`, `POST /webhooks/flutterwave`

All responses: `{"success": true|false, "message": "...", "data": ...}`.
