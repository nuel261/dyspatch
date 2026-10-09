<?php
/** Every business rule and third-party credential lives here — no redeploy needed. */
require __DIR__ . '/_init.php';
$admin = require_admin(['super']);

// [key, label, type, hint] — types: text, int, float, naira (stored as kobo), select:a|b, secret, textarea, bool, email
$groups = [
    'general' => ['General', 'settings', [
        ['app_name', 'App name', 'text'], ['support_phone', 'Support phone', 'text'], ['support_email', 'Support email', 'email'],
        ['admin_alert_email', 'Admin alert emails', 'text', 'Comma-separated. Receives SOS, top-up, withdrawal and verification alerts.'],
    ]],
    'pricing' => ['Pricing & commission', 'receipt', [
        ['pricing_model', 'Pricing model', 'select:min_fare=Minimum fare + distance|distance_only=Distance only', 'Open decision #2 — switch any time.'],
        ['base_fare_kobo', 'Base fare (₦)', 'naira'], ['per_km_kobo', 'Per km (₦)', 'naira'], ['min_fare_kobo', 'Minimum fare (₦)', 'naira', 'Used by the minimum-fare model.'],
        ['commission_pct', 'Platform commission %', 'float', 'Global default; zones can override.'],
        ['mult_small', 'Small package ×', 'float'], ['mult_medium', 'Medium package ×', 'float'], ['mult_large', 'Large package ×', 'float'], ['mult_express', 'Express ×', 'float'],
        ['road_factor', 'Road factor', 'float', 'Straight-line → road distance multiplier when no routing API answers.'], ['avg_speed_kmh', 'Average speed (km/h)', 'int', 'For ETA estimates.'],
    ]],
    'dispatch' => ['Dispatch & tracking', 'bike', [
        ['matching_radius_km', 'Matching radius (km)', 'float', 'Riders within this distance of pickup are offered the job.'],
        ['accept_window_seconds', 'Accept window (seconds)', 'int', 'Then the job is re-offered to the next rider.'],
        ['max_offer_rounds', 'Max offer rounds', 'int'],
        ['tracking_link_expiry_hours', 'Tracking link expiry after completion (hours)', 'int'],
    ]],
    'otp' => ['OTP & security', 'shield', [
        ['otp_length', 'OTP length', 'int'], ['otp_expiry_minutes', 'OTP expiry (minutes)', 'int'], ['otp_max_attempts', 'Lock after failed attempts', 'int'], ['otp_resend_seconds', 'Resend cooldown (seconds)', 'int'],
    ]],
    'wallet' => ['Wallet & withdrawals', 'wallet', [
        ['topup_bank_name', 'Top-up bank name', 'text'], ['topup_account_name', 'Top-up account name', 'text'], ['topup_account_number', 'Top-up account number', 'text'],
        ['withdrawal_min_kobo', 'Minimum withdrawal (₦)', 'naira'], ['withdrawal_cutoff_hour', 'Same-day cutoff hour (WAT, 0–23)', 'int'],
        ['withdrawal_fee_type', 'Withdrawal fee type', 'select:flat=Flat|percent=Percent|tiered=Tiered|none=No fee', 'Open decision #3.'],
        ['withdrawal_fee_value', 'Fee value', 'float', 'Kobo for flat (5000 = ₦50) or % for percent.'],
        ['withdrawal_fee_tiers', 'Fee tiers (JSON)', 'textarea', 'Amounts in kobo: [{"upto":500000,"fee":2500},{"upto":null,"fee":10000}]'],
        ['withdrawal_provider', 'Payout method', 'select:manual=Manual bank transfer|paystack=Paystack disbursement|flutterwave=Flutterwave disbursement', 'Fallback path while disbursement approval is pending.'],
    ]],
    'payments' => ['Payments', 'down', [
        ['payment_provider', 'Card top-up provider', 'select:paystack=Paystack|flutterwave=Flutterwave'],
        ['paystack_public_key', 'Paystack public key', 'text'], ['paystack_secret_key', 'Paystack secret key', 'secret'],
        ['flutterwave_secret_key', 'Flutterwave secret key', 'secret'], ['flutterwave_webhook_hash', 'Flutterwave webhook hash', 'secret'],
    ]],
    'email' => ['Email', 'bell', [
        ['email_enabled', 'Send emails', 'bool'],
        ['smtp_host', 'SMTP host', 'text', 'e.g. mail.bitprofil.com or smtp.gmail.com. Leave empty to use PHP mail().'],
        ['smtp_port', 'SMTP port', 'int'], ['smtp_encryption', 'Encryption', 'select:tls=STARTTLS (587)|ssl=SSL (465)|none=None'],
        ['smtp_username', 'SMTP username', 'text'], ['smtp_password', 'SMTP password', 'secret'],
        ['mail_from_email', 'From email', 'email'], ['mail_from_name', 'From name', 'text'],
    ]],
    'push' => ['Push notifications', 'bell', [
        ['push_enabled', 'Send push notifications', 'bool'],
        ['firebase_project_id', 'Firebase project ID', 'text', 'Also used to verify Google sign-in tokens from the app.'],
        ['fcm_service_account', 'Service account JSON', 'secretarea', 'Firebase console → Project settings → Service accounts → Generate new private key. Paste the whole file.'],
    ]],
    'sms' => ['SMS (Termii)', 'phone', [
        ['sms_driver', 'SMS driver', 'select:log=Log only (testing — codes returned by API)|termii=Termii'],
        ['termii_api_key', 'Termii API key', 'secret'], ['termii_sender_id', 'Sender ID', 'text'], ['termii_channel', 'Channel', 'select:dnd=DND|generic=Generic|whatsapp=WhatsApp'],
    ]],
    'kyc' => ['ID verification', 'filecheck', [
        ['kyc_provider', 'Provider', 'select:manual=Manual review|prembly=Prembly|smile=Smile Identity', 'Open decision #5 — swap without code changes.'],
        ['prembly_app_id', 'Prembly app ID', 'text'], ['prembly_api_key', 'Prembly API key', 'secret'],
        ['smile_partner_id', 'Smile partner ID', 'text'], ['smile_api_key', 'Smile API key', 'secret'],
    ]],
    'maps' => ['Maps', 'map', [
        ['google_maps_key', 'Google Maps API key', 'secret', 'Optional. Enables Google Places search & Distance Matrix; OpenStreetMap is used otherwise.'],
    ]],
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $g = $_POST['group'] ?? '';
    try {
        if (($_POST['action'] ?? '') === 'test_email') {
            $to = trim((string) ($_POST['to'] ?? '')) ?: $admin['email'];
            $ok = Mailer::send($to, 'Dyspatch test email', Mailer::template('Email is working', '<p>This test was sent from Admin → Settings. Delivery, payment and verification emails will look like this.</p>', 'Open admin', app_url('admin/')));
            flash($ok ? "Test email sent to $to." : 'Sending failed. Check the SMTP details — the error is in storage/logs/mail-' . date('Y-m-d') . '.log', $ok ? 'ok' : 'err');
            redirect('settings.php#email');
        }
        if (($_POST['action'] ?? '') === 'test_push') {
            $phone = normalize_phone((string) ($_POST['phone'] ?? ''));
            $u = DB::row('SELECT id FROM users WHERE phone = ?', [$phone]) ?: null;
            $r = $u ? null : DB::row('SELECT id FROM riders WHERE phone = ?', [$phone]);
            if (!$u && !$r) throw new ApiException('No customer or rider with that phone');
            $n = Push::toOwner($u ? 'user' : 'rider', (int) ($u['id'] ?? $r['id']), 'Test notification', 'Push notifications from Dyspatch are working 🎉', ['type' => 'test']);
            flash($n ? "Delivered to $n device(s)." : 'No delivery. The user may not have opened the app since installing, or the service account is wrong (see storage/logs/push-*.log).', $n ? 'ok' : 'err');
            redirect('settings.php#push');
        }
        if (!isset($groups[$g])) throw new ApiException('Unknown group');
        foreach ($groups[$g][2] as $f) {
            [$key, $label, $type] = $f;
            if ($type === 'bool') { Settings::set($key, isset($_POST[$key]) ? '1' : '0'); continue; }
            if (!array_key_exists($key, $_POST)) continue;
            $v = trim((string) $_POST[$key]);
            if (($type === 'secret' || $type === 'secretarea') && $v === '') continue; // keep existing
            if ($type === 'secret' && $v === '__clear__') $v = '';
            if ($type === 'naira') $v = (string) to_kobo($v);
            if ($type === 'int') $v = (string) (int) $v;
            if ($type === 'float') $v = (string) (float) $v;
            if ($key === 'fcm_service_account' && $v !== '') {
                $j = json_decode($v, true);
                if (!is_array($j) || empty($j['private_key']) || empty($j['client_email'])) throw new ApiException('That is not a valid Firebase service account JSON.');
                if (!empty($j['project_id'])) Settings::set('firebase_project_id', $j['project_id']);
                @unlink(BASE_PATH . '/storage/cache/fcm_token.json');
            }
            if ($key === 'withdrawal_fee_tiers' && $v !== '' && !is_array(json_decode($v, true))) throw new ApiException('Fee tiers must be valid JSON.');
            Settings::set($key, $v);
        }
        if (!empty($_FILES['fcm_file']['tmp_name']) && $g === 'push') {
            $raw = (string) file_get_contents($_FILES['fcm_file']['tmp_name']);
            $j = json_decode($raw, true);
            if (!is_array($j) || empty($j['private_key'])) throw new ApiException('Upload the service account .json file from Firebase.');
            Settings::set('fcm_service_account', $raw);
            if (!empty($j['project_id'])) Settings::set('firebase_project_id', $j['project_id']);
            @unlink(BASE_PATH . '/storage/cache/fcm_token.json');
        }
        audit((int) $admin['id'], 'settings.update', 'settings', null, $g);
        flash($groups[$g][0] . ' saved.');
    } catch (ApiException $e) {
        flash($e->getMessage(), 'err');
    }
    redirect('settings.php#' . $g);
}

$s = Settings::all();
function field(array $f, array $s): string
{
    [$key, $label, $type] = $f;
    $hint = $f[3] ?? '';
    $v = $s[$key] ?? '';
    $h = $hint ? '<span class="hint">' . e($hint) . '</span>' : '';
    if ($type === 'bool') return '<label class="switch full"><input type="checkbox" name="' . $key . '" value="1" ' . ($v === '1' ? 'checked' : '') . '> ' . e($label) . '</label>';
    if (str_starts_with($type, 'select:')) {
        $opts = '';
        foreach (explode('|', substr($type, 7)) as $o) { [$ov, $ol] = explode('=', $o, 2); $opts .= '<option value="' . e($ov) . '" ' . ($v === $ov ? 'selected' : '') . '>' . e($ol) . '</option>'; }
        return '<label class="f">' . e($label) . '<select class="input" name="' . $key . '">' . $opts . '</select>' . $h . '</label>';
    }
    if ($type === 'secret') {
        $mask = $v !== '' ? '•••••••• ' . e(substr($v, -4)) : 'Not set';
        return '<label class="f">' . e($label) . ' <span class="muted small" style="font-weight:500">' . $mask . '</span><input class="input" type="password" name="' . $key . '" autocomplete="new-password" placeholder="' . ($v !== '' ? 'Leave empty to keep current' : 'Paste key') . '">' . $h . '</label>';
    }
    if ($type === 'secretarea') {
        $j = $v !== '' ? json_decode($v, true) : null;
        $st = $j ? '<span class="pill-ok">✓ ' . e($j['client_email'] ?? 'configured') . '</span>' : '<span class="muted">Not set</span>';
        return '<label class="f full">' . e($label) . ' <span class="small" style="font-weight:500">' . $st . '</span><textarea class="input mono" name="' . $key . '" rows="4" placeholder="{ &quot;type&quot;: &quot;service_account&quot;, … }  — leave empty to keep current"></textarea>' . $h . '</label>'
            . '<label class="f full">…or upload the .json file<input class="input" type="file" name="fcm_file" accept=".json,application/json"></label>';
    }
    if ($type === 'textarea') return '<label class="f full">' . e($label) . '<textarea class="input mono" name="' . $key . '" rows="3">' . e($v) . '</textarea>' . $h . '</label>';
    if ($type === 'naira') $v = $v === '' ? '' : (string) ((int) $v / 100);
    return '<label class="f">' . e($label) . '<input class="input" name="' . $key . '" value="' . e($v) . '" ' . ($type === 'email' ? 'type="email"' : '') . '>' . $h . '</label>';
}

layout_start('Settings', 'settings', 'Business rules and integrations. Changes apply immediately — no redeploy.');
?>
<div class="chips" style="position:sticky;top:0;z-index:5;background:var(--bg);padding:6px 0">
  <?php foreach ($groups as $k => [$label]): ?><a class="chip" href="#<?= $k ?>"><?= e($label) ?></a><?php endforeach; ?>
</div>
<?php foreach ($groups as $k => [$label, $ico, $fields]): ?>
<form method="post" enctype="multipart/form-data" class="card" id="<?= $k ?>" style="scroll-margin-top:60px"><?= csrf_field() ?><input type="hidden" name="group" value="<?= $k ?>">
  <div class="card-h"><h2><?= e($label) ?></h2>
    <?php if ($k === 'push'): ?><?= Push::enabled() ? badge('active', 'Active') : badge('none', 'Not configured') ?><?php endif; ?>
    <?php if ($k === 'email'): ?><?= Mailer::enabled() ? badge('active', Settings::get('smtp_host') ? 'SMTP' : 'PHP mail()') : badge('none', 'Disabled') ?><?php endif; ?>
    <?php if ($k === 'sms'): ?><?= Sms::isLive() ? badge('active', 'Live') : badge('pending', 'Test mode') ?><?php endif; ?>
    <button class="btn sm">Save</button></div>
  <div class="card-b form-grid">
    <?php foreach ($fields as $f) echo field($f, $s); ?>
    <?php if ($k === 'payments'): ?><div class="full callout">Webhook URLs — Paystack: <b class="mono"><?= e(app_url('api/webhooks/paystack')) ?></b><br>Flutterwave: <b class="mono"><?= e(app_url('api/webhooks/flutterwave')) ?></b></div><?php endif; ?>
    <?php if ($k === 'sms' && !Sms::isLive()): ?><div class="full flash warn"><?= icon('alert') ?><span>Test mode: OTP codes are written to the log and returned in the API response as <span class="mono">debug_code</span>. Switch to Termii before launch.</span></div><?php endif; ?>
  </div>
</form>
<?php if ($k === 'email'): ?>
<form method="post" class="card"><?= csrf_field() ?><input type="hidden" name="action" value="test_email">
  <div class="card-b row"><b style="flex:1">Send a test email</b><input class="input" name="to" type="email" value="<?= e($admin['email']) ?>" style="max-width:280px"><button class="btn ghost sm">Send test</button></div></form>
<?php endif; ?>
<?php if ($k === 'push'): ?>
<form method="post" class="card"><?= csrf_field() ?><input type="hidden" name="action" value="test_push">
  <div class="card-b row"><b style="flex:1">Send a test push</b><input class="input" name="phone" placeholder="Customer or rider phone" style="max-width:280px"><button class="btn ghost sm">Send test</button></div></form>
<?php endif; ?>
<?php endforeach; ?>
<?php layout_end();
