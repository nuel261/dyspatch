<?php
declare(strict_types=1);
/**
 * Dyspatch REST API — https://dyspatch.bitprofil.com/api
 * JSON in/out. Auth: "Authorization: Bearer <token>" from /auth/otp/verify or /auth/google.
 * Errors: {"success":false,"message":"...","errors":{...}} with an HTTP status.
 */
require dirname(__DIR__) . '/includes/bootstrap.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept');
header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') { http_response_code(204); exit; }

function ok($data = null, string $message = 'OK', int $status = 200): never
{
    http_response_code($status);
    echo json_encode(['success' => true, 'message' => $message, 'data' => $data], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function input(): array
{
    static $in = null;
    if ($in !== null) return $in;
    $raw = file_get_contents('php://input') ?: '';
    $json = json_decode($raw, true);
    $in = is_array($json) ? $json : [];
    return $in = array_merge($_GET, $_POST, $in);
}

function req(string $key, ?string $label = null): string
{
    $v = trim((string) (input()[$key] ?? ''));
    if ($v === '') throw new ApiException(($label ?? ucfirst(str_replace('_', ' ', $key))) . ' is required', 422, [$key => 'required']);
    return $v;
}

function user_payload(array $u): array
{
    return [
        'id' => (int) $u['id'], 'first_name' => $u['first_name'], 'last_name' => $u['last_name'],
        'name' => trim(($u['first_name'] ?? '') . ' ' . ($u['last_name'] ?? '')) ?: null,
        'email' => $u['email'], 'phone' => $u['phone'], 'avatar' => public_file($u['avatar']),
        'address' => $u['address'], 'lat' => $u['lat'] !== null ? (float) $u['lat'] : null, 'lng' => $u['lng'] !== null ? (float) $u['lng'] : null,
        'default_delivery_type' => $u['default_delivery_type'], 'auto_assign' => (bool) $u['auto_assign'],
        'two_factor' => (bool) $u['two_factor'], 'business_verified' => (bool) $u['business_verified'],
        'has_password' => !empty($u['password_hash']), 'profile_complete' => !empty($u['first_name']) && !empty($u['phone']),
        'created_at' => iso($u['created_at']),
    ];
}

function rider_payload(array $r): array
{
    return [
        'id' => (int) $r['id'], 'first_name' => $r['first_name'], 'last_name' => $r['last_name'],
        'name' => trim($r['first_name'] . ' ' . $r['last_name']), 'email' => $r['email'], 'phone' => $r['phone'],
        'photo' => public_file($r['photo']), 'vehicle_type' => $r['vehicle_type'], 'plate' => $r['plate'],
        'zone_id' => $r['zone_id'] ? (int) $r['zone_id'] : null, 'kyc_status' => $r['kyc_status'], 'status' => $r['status'],
        'is_online' => (bool) $r['is_online'], 'rating' => (float) $r['rating'],
    ];
}

function tx_payload(array $t): array
{
    $isCredit = $t['type'] === 'credit';
    $titles = ['topup' => 'Wallet top-up', 'delivery_payment' => 'Delivery payment', 'delivery_earning' => 'Delivery earning',
        'commission' => 'Commission', 'withdrawal' => 'Transfer out', 'withdrawal_fee' => 'Transfer fee', 'refund' => 'Refund', 'adjustment' => 'Adjustment'];
    return [
        'id' => (int) $t['id'], 'type' => $t['type'], 'category' => $t['category'], 'title' => $titles[$t['category']] ?? ucfirst($t['category']),
        'description' => $t['description'], 'amount_kobo' => (int) $t['amount_kobo'], 'amount' => ($isCredit ? '+' : '-') . naira($t['amount_kobo']),
        'balance_after_kobo' => (int) $t['balance_after_kobo'], 'reference' => $t['reference'], 'track_id' => $t['track_id'] ?? null,
        'created_at' => iso($t['created_at']),
    ];
}

function bank_payload(array $b): array
{
    return ['id' => (int) $b['id'], 'bank_name' => $b['bank_name'], 'bank_code' => $b['bank_code'], 'account_name' => $b['account_name'],
        'account_number' => $b['account_number'], 'is_verified' => (bool) $b['is_verified'], 'is_default' => (bool) $b['is_default']];
}

/** Current wallet owner (user or rider). */
function owner(): array
{
    $a = ApiAuth::current();
    if (!$a) throw new ApiException('Unauthenticated', 401);
    return [$a['type'], $a['id'], $a['row']];
}

/** Finds an order the current customer owns by numeric id, Track ID or order no. */
function user_order(array $user, string $code): array
{
    $o = ctype_digit($code) ? Orders::find((int) $code) : Orders::lookup($code);
    if (!$o || (int) $o['user_id'] !== (int) $user['id']) throw new ApiException('Order not found', 404);
    return $o;
}

function rider_order(array $rider, string $id): array
{
    $o = Orders::find((int) $id);
    if (!$o || (int) $o['rider_id'] !== (int) $rider['id']) throw new ApiException('Order not found', 404);
    return $o;
}

/* ─────────────────────────── Routing ─────────────────────────── */
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = $_GET['r'] ?? ($_SERVER['PATH_INFO'] ?? null);
if ($path === null) {
    $uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
    $base = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/api/index.php')), '/');
    $path = substr($uri, strlen($base)) ?: '/';
    $path = preg_replace('#^/index\.php#', '', $path);
}
$path = '/' . trim((string) $path, '/');

$routes = [];
function route(string $m, string $pattern, callable $fn): void
{
    global $routes;
    $routes[] = [$m, '#^' . preg_replace('#\{(\w+)\}#', '(?P<$1>[^/]+)', $pattern) . '$#', $fn];
}

/* ─────────────── Public ─────────────── */
route('GET', '/', fn() => ok(['name' => 'Dyspatch API', 'version' => '1.0', 'time' => date('c')]));

route('GET', '/config', function () {
    ok([
        'otp_length' => Settings::int('otp_length', 4),
        'otp_resend_seconds' => Settings::int('otp_resend_seconds', 60),
        'support_phone' => Settings::get('support_phone'), 'support_email' => Settings::get('support_email'),
        'topup_bank' => ['bank_name' => Settings::get('topup_bank_name'), 'account_name' => Settings::get('topup_account_name'), 'account_number' => Settings::get('topup_account_number')],
        'card_topup_enabled' => Payments::configured(),
        'withdrawal_min_kobo' => Settings::int('withdrawal_min_kobo', 50000),
        'withdrawal_cutoff_hour' => Settings::int('withdrawal_cutoff_hour', 17),
        'zones' => array_map(fn($z) => ['name' => $z['name'], 'code' => $z['code'], 'city' => $z['city'], 'is_live' => (bool) $z['is_live']], DB::all('SELECT * FROM zones ORDER BY is_live DESC, name')),
        'terms_url' => app_url('legal/terms'), 'privacy_url' => app_url('legal/privacy'),
    ]);
});

route('POST', '/auth/otp/request', function () {
    $phone = normalize_phone(req('phone'));
    if (!preg_match('/^\+\d{10,15}$/', $phone)) throw new ApiException('Enter a valid phone number', 422);
    $role = (input()['role'] ?? 'user') === 'rider' ? 'rider' : 'user';
    $table = $role === 'rider' ? 'riders' : 'users';
    $existing = DB::row("SELECT email, status FROM $table WHERE phone = ?", [$phone]);
    if ($existing && $existing['status'] === 'suspended') throw new ApiException('This account is suspended. Contact support.', 403);
    $res = Otp::issue($phone, $role . '_login', $existing['email'] ?? null);
    ok(['phone' => $phone, 'is_registered' => (bool) $existing] + $res, 'Verification code sent');
});

route('POST', '/auth/otp/verify', function () {
    $phone = normalize_phone(req('phone'));
    $role = (input()['role'] ?? 'user') === 'rider' ? 'rider' : 'user';
    Otp::verify($phone, req('code'), $role . '_login');
    $table = $role === 'rider' ? 'riders' : 'users';
    $row = DB::row("SELECT * FROM $table WHERE phone = ?", [$phone]);
    $isNew = !$row;
    if ($isNew) {
        $id = DB::insert($table, ['phone' => $phone, 'first_name' => trim((string) (input()['first_name'] ?? '')) ?: ($role === 'rider' ? '' : null), 'last_name' => trim((string) (input()['last_name'] ?? '')) ?: ($role === 'rider' ? '' : null)]);
        $row = DB::row("SELECT * FROM $table WHERE id = ?", [$id]);
        Wallet::get($role, $id);
        Notifier::notify($role, $id, 'system', 'Welcome to Dyspatch', $role === 'rider' ? 'Complete your verification to start earning.' : 'Send your first package in seconds and track it live.', [], ['send' => false]);
    }
    $token = ApiAuth::issueToken($role, (int) $row['id'], input()['device'] ?? ($_SERVER['HTTP_USER_AGENT'] ?? null));
    ok(['token' => $token, 'is_new' => $isNew, 'role' => $role, $role => $role === 'rider' ? rider_payload($row) : user_payload($row)], 'Verified');
});

route('POST', '/auth/google', function () {
    $claims = ApiAuth::verifyFirebaseToken(req('id_token'));
    $uid = $claims['sub'];
    $email = $claims['email'] ?? null;
    $u = DB::row('SELECT * FROM users WHERE firebase_uid = ?', [$uid]) ?: ($email ? DB::row('SELECT * FROM users WHERE email = ?', [$email]) : null);
    $isNew = !$u;
    if ($u && $u['status'] === 'suspended') throw new ApiException('This account is suspended. Contact support.', 403);
    if ($isNew) {
        $names = explode(' ', trim((string) ($claims['name'] ?? '')), 2);
        $id = DB::insert('users', ['firebase_uid' => $uid, 'email' => $email, 'first_name' => $names[0] ?: null, 'last_name' => $names[1] ?? null, 'avatar' => $claims['picture'] ?? null]);
        $u = DB::row('SELECT * FROM users WHERE id = ?', [$id]);
        Wallet::get('user', $id);
    } elseif (!$u['firebase_uid']) {
        DB::update('users', ['firebase_uid' => $uid], 'id = ?', [$u['id']]);
    }
    $token = ApiAuth::issueToken('user', (int) $u['id'], input()['device'] ?? null);
    ok(['token' => $token, 'is_new' => $isNew, 'role' => 'user', 'user' => user_payload($u)], 'Signed in');
});

route('POST', '/auth/logout', function () {
    $tok = input()['fcm_token'] ?? null;
    if ($tok) DB::query('DELETE FROM device_tokens WHERE fcm_token = ?', [$tok]);
    ApiAuth::revokeCurrent();
    ok(null, 'Logged out');
});

route('GET', '/track/{code}', function ($p) {
    $o = Orders::lookup(urldecode($p['code']));
    if (!$o) throw new ApiException('No package found with that Track ID', 404);
    $data = Orders::present($o, false);
    $data['trail'] = in_array($o['status'], Orders::ACTIVE, true) ? Orders::trail((int) $o['id'], 100) : [];
    ok($data);
});

route('GET', '/shared/{token}', function ($p) {
    $o = DB::row('SELECT * FROM orders WHERE share_token = ?', [$p['token']]);
    if (!$o || !Orders::shareValid($o)) throw new ApiException('This tracking link has expired', 404);
    ok(Orders::present($o, false));
});

route('GET', '/places/search', function () {
    $in = input();
    ok(Geo::search((string) ($in['q'] ?? ''), isset($in['lat']) ? (float) $in['lat'] : null, isset($in['lng']) ? (float) $in['lng'] : null));
});

route('GET', '/places/reverse', function () {
    $lat = (float) req('lat');
    $lng = (float) req('lng');
    $zone = Geo::zoneFor($lat, $lng);
    ok(['address' => Geo::reverse($lat, $lng), 'zone' => $zone ? ['name' => $zone['name'], 'code' => $zone['code'], 'is_live' => (bool) $zone['is_live']] : null]);
});

route('GET', '/banks', function () {
    $cache = BASE_PATH . '/storage/cache/banks.json';
    if (is_file($cache) && filemtime($cache) > time() - 86400 * 7) ok(json_decode((string) file_get_contents($cache), true));
    $banks = Payments::configured() ? Payments::provider()->banks() : [];
    if (!$banks) {
        $banks = array_map(fn($b) => ['name' => $b[0], 'code' => $b[1]], [
            ['Access Bank', '044'], ['Citibank Nigeria', '023'], ['Ecobank Nigeria', '050'], ['Fidelity Bank', '070'], ['First Bank of Nigeria', '011'],
            ['First City Monument Bank', '214'], ['Globus Bank', '00103'], ['Guaranty Trust Bank', '058'], ['Jaiz Bank', '301'], ['Keystone Bank', '082'],
            ['Kuda Bank', '50211'], ['Moniepoint MFB', '50515'], ['OPay', '999992'], ['PalmPay', '999991'], ['Polaris Bank', '076'],
            ['Providus Bank', '101'], ['Stanbic IBTC Bank', '221'], ['Standard Chartered Bank', '068'], ['Sterling Bank', '232'], ['Union Bank of Nigeria', '032'],
            ['United Bank For Africa', '033'], ['Unity Bank', '215'], ['Wema Bank', '035'], ['Zenith Bank', '057'],
        ]);
    } else {
        @mkdir(dirname($cache), 0775, true);
        file_put_contents($cache, json_encode($banks));
    }
    ok($banks);
});

/* ─────────────── Webhooks ─────────────── */
route('POST', '/webhooks/paystack', function () {
    $raw = file_get_contents('php://input') ?: '';
    $headers = array_change_key_case(function_exists('getallheaders') ? getallheaders() : [], CASE_LOWER);
    if (!isset($headers['x-paystack-signature'])) $headers['x-paystack-signature'] = $_SERVER['HTTP_X_PAYSTACK_SIGNATURE'] ?? '';
    if (!(new PaystackProvider())->verifyWebhook($raw, $headers)) throw new ApiException('Bad signature', 401);
    $ev = json_decode($raw, true) ?: [];
    $d = $ev['data'] ?? [];
    if (($ev['event'] ?? '') === 'charge.success') complete_card_topup((string) ($d['reference'] ?? ''), (int) ($d['amount'] ?? 0));
    if (in_array($ev['event'] ?? '', ['transfer.success', 'transfer.failed', 'transfer.reversed'], true)) {
        $w = DB::row('SELECT * FROM withdrawals WHERE reference = ?', [$d['reference'] ?? '']);
        if ($w && $w['status'] === 'processing') {
            if ($ev['event'] === 'transfer.success') {
                DB::update('withdrawals', ['status' => 'paid', 'processed_at' => now()], 'id = ?', [$w['id']]);
                Notifier::notify($w['owner_type'], (int) $w['owner_id'], 'payment', 'Withdrawal paid', naira($w['amount_kobo']) . ' has been sent to your bank account.');
            } else {
                Wallet::rejectWithdrawal((int) $w['id'], null, 'Bank transfer ' . str_replace('transfer.', '', $ev['event']));
            }
        }
    }
    ok();
});

route('POST', '/webhooks/flutterwave', function () {
    $raw = file_get_contents('php://input') ?: '';
    if (!(new FlutterwaveProvider())->verifyWebhook($raw, ['verif-hash' => $_SERVER['HTTP_VERIF_HASH'] ?? ''])) throw new ApiException('Bad signature', 401);
    $d = (json_decode($raw, true) ?: [])['data'] ?? [];
    if (($d['status'] ?? '') === 'successful') complete_card_topup((string) ($d['tx_ref'] ?? ''), (int) round(((float) ($d['amount'] ?? 0)) * 100));
    ok();
});

function complete_card_topup(string $ref, int $amountKobo): ?array
{
    return DB::tx(function () use ($ref, $amountKobo) {
        $t = DB::row("SELECT * FROM topup_requests WHERE reference = ? AND method IN ('paystack','flutterwave') FOR UPDATE", [$ref]);
        if (!$t || $t['status'] === 'confirmed') return $t;
        $verified = Payments::provider($t['method'])->verify($ref);
        if (!$verified['paid']) return $t;
        $amt = $verified['amount_kobo'] ?: $amountKobo;
        DB::update('topup_requests', ['status' => 'confirmed', 'amount_kobo' => $amt, 'confirmed_at' => now()], 'id = ?', [$t['id']]);
        Wallet::credit('user', (int) $t['user_id'], $amt, 'topup', 'Wallet top-up · card', null, 'TOP-' . $ref);
        Notifier::notify('user', (int) $t['user_id'], 'payment', 'Wallet funded', naira($amt) . ' was added to your wallet.', ['type' => 'topup', 'reference' => $ref]);
        return DB::row('SELECT * FROM topup_requests WHERE id = ?', [$t['id']]);
    });
}

/* ─────────────── Customer: profile ─────────────── */
route('GET', '/me', function () {
    $u = ApiAuth::requireUser();
    ok(user_payload($u) + ['wallet_balance_kobo' => Wallet::balance('user', (int) $u['id']),
        'unread_notifications' => (int) DB::value("SELECT COUNT(*) FROM notifications WHERE owner_type='user' AND owner_id=? AND read_at IS NULL", [$u['id']])]);
});

route('PUT', '/me', function () {
    $u = ApiAuth::requireUser();
    $in = input();
    $upd = [];
    foreach (['first_name', 'last_name', 'address'] as $f) if (array_key_exists($f, $in)) $upd[$f] = mb_substr(trim((string) $in[$f]), 0, $f === 'address' ? 255 : 80) ?: null;
    foreach (['lat', 'lng'] as $f) if (array_key_exists($f, $in)) $upd[$f] = $in[$f] === null || $in[$f] === '' ? null : (float) $in[$f];
    if (array_key_exists('email', $in)) {
        $email = trim((string) $in['email']);
        if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) throw new ApiException('Enter a valid email address', 422);
        if ($email !== '' && DB::value('SELECT 1 FROM users WHERE email = ? AND id <> ?', [$email, $u['id']])) throw new ApiException('That email is already in use', 422);
        $upd['email'] = $email ?: null;
    }
    if (!empty($in['phone'])) {
        $phone = normalize_phone((string) $in['phone']);
        if ($phone !== $u['phone']) {
            if (DB::value('SELECT 1 FROM users WHERE phone = ? AND id <> ?', [$phone, $u['id']])) throw new ApiException('That phone number is already in use', 422);
            if ($u['phone']) {
                // Changing an existing number requires an OTP sent to the new number.
                if (empty($in['phone_code'])) { Otp::issue($phone, 'phone_change'); throw new ApiException('Enter the code sent to ' . $phone, 428, ['phone_code' => 'required']); }
                Otp::verify($phone, (string) $in['phone_code'], 'phone_change');
            }
            $upd['phone'] = $phone;
        }
    }
    if (isset($in['default_delivery_type'])) $upd['default_delivery_type'] = $in['default_delivery_type'] === 'express' ? 'express' : 'standard';
    if (isset($in['auto_assign'])) $upd['auto_assign'] = filter_var($in['auto_assign'], FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
    if (isset($in['two_factor'])) $upd['two_factor'] = filter_var($in['two_factor'], FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
    if (!empty($in['avatar'])) { $p = save_upload($in['avatar'], 'avatars'); if ($p) $upd['avatar'] = $p; }
    if (!empty($_FILES['avatar'])) { $p = save_upload($_FILES['avatar'], 'avatars'); if ($p) $upd['avatar'] = $p; }
    if ($upd) DB::update('users', $upd, 'id = ?', [$u['id']]);
    ok(user_payload(DB::row('SELECT * FROM users WHERE id = ?', [$u['id']])), 'Profile updated');
});
route('POST', '/me', fn() => $GLOBALS['dispatch']('PUT', '/me'));

route('POST', '/me/password', function () {
    $u = ApiAuth::requireUser();
    $new = req('new_password', 'New password');
    if (strlen($new) < 8) throw new ApiException('Password must be at least 8 characters', 422);
    if ($u['password_hash'] && !password_verify((string) (input()['current_password'] ?? ''), $u['password_hash'])) throw new ApiException('Current password is incorrect', 422);
    DB::update('users', ['password_hash' => password_hash($new, PASSWORD_DEFAULT)], 'id = ?', [$u['id']]);
    Notifier::notify('user', (int) $u['id'], 'system', 'Password changed', 'Your Dyspatch password was changed. If this wasn\'t you, contact support immediately.');
    ok(null, 'Password updated');
});

route('POST', '/me/2fa/request', function () {
    $u = ApiAuth::requireUser();
    if (!$u['phone']) throw new ApiException('Add a phone number first', 422);
    ok(Otp::issue($u['phone'], '2fa', $u['email']), 'Code sent');
});
route('POST', '/me/2fa/verify', function () {
    $u = ApiAuth::requireUser();
    Otp::verify((string) $u['phone'], req('code'), '2fa');
    $enable = filter_var(input()['enable'] ?? true, FILTER_VALIDATE_BOOLEAN);
    DB::update('users', ['two_factor' => $enable ? 1 : 0], 'id = ?', [$u['id']]);
    ok(['two_factor' => $enable], $enable ? 'Two-factor authentication enabled' : 'Two-factor authentication disabled');
});

route('POST', '/devices', function () {
    [$type, $id] = owner();
    $tok = req('fcm_token');
    DB::query('INSERT INTO device_tokens (owner_type, owner_id, fcm_token, platform) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE owner_type = VALUES(owner_type), owner_id = VALUES(owner_id), platform = VALUES(platform)',
        [$type, $id, $tok, mb_substr((string) (input()['platform'] ?? ''), 0, 20)]);
    ok(null, 'Device registered');
});
route('DELETE', '/devices', function () {
    DB::query('DELETE FROM device_tokens WHERE fcm_token = ?', [req('fcm_token')]);
    ok(null, 'Device removed');
});

/* ─────────────── Customer: orders ─────────────── */
route('POST', '/orders/quote', function () {
    $u = ApiAuth::requireUser();
    $q = Orders::quote(input());
    $q['fee'] = naira($q['fee_kobo'], false);
    $q['wallet_balance_kobo'] = Wallet::balance('user', (int) $u['id']);
    unset($q['commission_pct'], $q['commission_kobo'], $q['rider_earning_kobo']);
    ok($q);
});

route('POST', '/orders', function () {
    $u = ApiAuth::requireUser();
    $o = Orders::create(input(), $u, 'app');
    Notifier::orderStatus($o, 'pending');
    Matching::dispatch((int) $o['id']);
    ok(Orders::present(Orders::find((int) $o['id'])), 'Delivery created', 201);
});

route('GET', '/orders', function () {
    $u = ApiAuth::requireUser();
    $f = input()['status'] ?? 'all';
    $sql = 'SELECT * FROM orders WHERE user_id = ?';
    if ($f === 'active') $sql .= " AND status IN ('pending','matched','picked_up','en_route','arrived')";
    elseif ($f === 'completed') $sql .= " AND status IN ('delivered','cancelled','failed')";
    $limit = max(1, min(100, (int) (input()['limit'] ?? 30)));
    $rows = DB::all($sql . ' ORDER BY id DESC LIMIT ' . $limit, [$u['id']]);
    ok(array_map(function ($o) {
        $r = Orders::riderPublic($o['rider_id'] ? (int) $o['rider_id'] : null);
        return [
            'id' => (int) $o['id'], 'order_no' => $o['order_no'], 'track_id' => $o['track_id'], 'route' => Orders::shortRoute($o),
            'status' => $o['status'], 'status_label' => Orders::LABELS[$o['status']], 'rider_name' => $r['name'] ?? null,
            'eta_minutes' => Orders::liveEta($o, $r), 'items_count' => (int) DB::value('SELECT COALESCE(SUM(quantity),0) FROM order_items WHERE order_id = ?', [$o['id']]),
            'fee_kobo' => (int) $o['fee_kobo'], 'fee' => naira($o['fee_kobo'], false), 'created_at' => iso($o['created_at']),
            'delivered_at' => iso($o['delivered_at']),
        ];
    }, $rows));
});

route('GET', '/orders/{code}', function ($p) {
    Matching::tick();
    ok(Orders::present(user_order(ApiAuth::requireUser(), urldecode($p['code']))));
});

route('GET', '/orders/{code}/rider-location', function ($p) {
    $o = user_order(ApiAuth::requireUser(), urldecode($p['code']));
    $r = Orders::riderPublic($o['rider_id'] ? (int) $o['rider_id'] : null);
    ok(['lat' => $r['lat'] ?? null, 'lng' => $r['lng'] ?? null, 'eta_minutes' => Orders::liveEta($o, $r) ?? 0,
        'status' => $o['status'], 'updated_at' => $r['location_updated_at'] ?? null]);
});

route('POST', '/orders/{code}/share-link', function ($p) {
    $o = user_order(ApiAuth::requireUser(), urldecode($p['code']));
    ok(['url' => Orders::shareLink((int) $o['id']), 'track_id' => $o['track_id']]);
});

route('POST', '/orders/{code}/sos', function ($p) {
    $u = ApiAuth::requireUser();
    $o = user_order($u, urldecode($p['code']));
    $in = input();
    $id = DB::insert('sos_alerts', ['order_id' => $o['id'], 'user_id' => $u['id'], 'rider_id' => $o['rider_id'],
        'lat' => isset($in['user_lat']) ? (float) $in['user_lat'] : null, 'lng' => isset($in['user_lng']) ? (float) $in['user_lng'] : null,
        'message' => mb_substr((string) ($in['message'] ?? 'User flagged a safety concern'), 0, 255)]);
    Orders::event((int) $o['id'], null, 'sos', 'SOS raised', 'Safety concern flagged by customer', 'user', (int) $u['id']);
    Notifier::adminAlert("SOS on {$o['track_id']}", '<p>A customer raised an SOS on order <b>' . e($o['track_id']) . '</b>.</p><p>' . e($in['message'] ?? '') . '</p>', app_url('admin/sos.php'));
    ok(['id' => $id], 'SOS sent. Our team has been alerted.');
});

route('POST', '/orders/{code}/cancel', function ($p) {
    $u = ApiAuth::requireUser();
    $o = user_order($u, urldecode($p['code']));
    if (!in_array($o['status'], ['pending', 'matched'], true)) throw new ApiException('This delivery can no longer be cancelled', 409);
    ok(Orders::present(Orders::setStatus((int) $o['id'], 'cancelled', 'user', (int) $u['id'], trim((string) (input()['reason'] ?? '')) ?: 'Cancelled by customer', true)), 'Delivery cancelled');
});

route('POST', '/orders/{code}/regenerate-code', function ($p) {
    $o = user_order(ApiAuth::requireUser(), urldecode($p['code']));
    if (!in_array($o['status'], Orders::ACTIVE, true)) throw new ApiException('Order is not active', 409);
    $o = Orders::regenerateDeliveryCode((int) $o['id']);
    ok(['delivery_code' => $o['delivery_code']], 'New code sent to the recipient');
});

route('POST', '/orders/{code}/rate', function ($p) {
    $o = user_order(ApiAuth::requireUser(), urldecode($p['code']));
    $rating = (int) req('rating');
    if ($o['status'] !== 'delivered' || !$o['rider_id']) throw new ApiException('You can rate after delivery', 409);
    if ($rating < 1 || $rating > 5) throw new ApiException('Rating must be 1–5', 422);
    if ($o['rider_rating']) throw new ApiException('Already rated', 409);
    DB::tx(function () use ($o, $rating) {
        DB::update('orders', ['rider_rating' => $rating], 'id = ?', [$o['id']]);
        DB::query('UPDATE riders SET rating = ROUND((rating * rating_count + ?) / (rating_count + 1), 2), rating_count = rating_count + 1 WHERE id = ?', [$rating, $o['rider_id']]);
    });
    ok(null, 'Thanks for rating your rider');
});

/* ─────────────── Wallet (customers & riders) ─────────────── */
route('GET', '/wallet', function () {
    [$type, $id] = owner();
    $banks = DB::all('SELECT * FROM bank_accounts WHERE owner_type = ? AND owner_id = ? ORDER BY is_default DESC, id', [$type, $id]);
    ok([
        'balance_kobo' => Wallet::balance($type, $id), 'balance' => naira(Wallet::balance($type, $id)),
        'bank_accounts' => array_map('bank_payload', $banks),
        'topup_bank' => ['bank_name' => Settings::get('topup_bank_name'), 'account_name' => Settings::get('topup_account_name'), 'account_number' => Settings::get('topup_account_number')],
        'recent_transactions' => array_map('tx_payload', Wallet::transactions($type, $id, 10)),
        'pending_withdrawals' => (int) DB::value("SELECT COALESCE(SUM(amount_kobo),0) FROM withdrawals WHERE owner_type=? AND owner_id=? AND status IN ('pending','processing')", [$type, $id]),
        'withdrawal_min_kobo' => Settings::int('withdrawal_min_kobo', 50000),
    ]);
});

route('GET', '/wallet/transactions', function () {
    [$type, $id] = owner();
    $filter = input()['filter'] ?? 'all';
    $rows = Wallet::transactions($type, $id, (int) (input()['limit'] ?? 100));
    if ($filter === 'topup') $rows = array_filter($rows, fn($t) => in_array($t['category'], ['topup', 'refund', 'delivery_earning'], true));
    if ($filter === 'transferred') $rows = array_filter($rows, fn($t) => in_array($t['category'], ['withdrawal', 'withdrawal_fee'], true));
    ok(array_values(array_map('tx_payload', $rows)));
});

route('GET', '/wallet/withdrawal-fee', function () {
    $amt = to_kobo(req('amount'));
    ok(['amount_kobo' => $amt, 'fee_kobo' => Pricing::withdrawalFee($amt), 'payout_date' => Wallet::payoutDate()]);
});

// Bank-transfer top-up: create a reference → user transfers → taps "I've sent the money" → admin confirms.
route('POST', '/wallet/topups', function () {
    $u = ApiAuth::requireUser();
    $t = DB::row("SELECT * FROM topup_requests WHERE user_id = ? AND method = 'bank_transfer' AND status = 'awaiting' AND created_at > NOW() - INTERVAL 1 DAY ORDER BY id DESC LIMIT 1", [$u['id']]);
    if (!$t) {
        $ref = 'TOP-' . date('ymd') . '-' . rand_code(6);
        DB::insert('topup_requests', ['user_id' => $u['id'], 'reference' => $ref, 'method' => 'bank_transfer']);
        $t = DB::row('SELECT * FROM topup_requests WHERE reference = ?', [$ref]);
    }
    ok(['reference' => $t['reference'], 'status' => $t['status'],
        'bank' => ['bank_name' => Settings::get('topup_bank_name'), 'account_name' => Settings::get('topup_account_name'), 'account_number' => Settings::get('topup_account_number')],
        'instructions' => 'Transfer any amount and use ' . $t['reference'] . ' as the narration/description.']);
});

route('POST', '/wallet/topups/{ref}/sent', function ($p) {
    $u = ApiAuth::requireUser();
    $t = DB::row('SELECT * FROM topup_requests WHERE reference = ? AND user_id = ?', [$p['ref'], $u['id']]);
    if (!$t) throw new ApiException('Top-up not found', 404);
    $amt = isset(input()['amount']) ? to_kobo(input()['amount']) : null;
    if ($t['status'] === 'awaiting') DB::update('topup_requests', ['status' => 'pending', 'amount_kobo' => $amt ?: null], 'id = ?', [$t['id']]);
    Notifier::adminAlert('Top-up awaiting confirmation', '<p>Reference <b>' . e($t['reference']) . '</b>' . ($amt ? ' · ' . naira($amt) : '') . ' from ' . e($u['phone'] ?? $u['email']) . '.</p>', app_url('admin/topups.php'));
    ok(['reference' => $t['reference'], 'status' => 'pending'], "We'll credit your wallet once the transfer is confirmed");
});

route('POST', '/wallet/topups/card', function () {
    $u = ApiAuth::requireUser();
    if (!Payments::configured()) throw new ApiException('Card payments are not available yet. Use bank transfer.', 503);
    $amt = to_kobo(req('amount'));
    if ($amt < 10000) throw new ApiException('Minimum top-up is ₦100', 422);
    $provider = Settings::get('payment_provider', 'paystack');
    $ref = 'TOP-' . date('ymd') . '-' . rand_code(8);
    DB::insert('topup_requests', ['user_id' => $u['id'], 'reference' => $ref, 'amount_kobo' => $amt, 'method' => $provider, 'status' => 'pending']);
    $email = $u['email'] ?: ('user' . $u['id'] . '@' . (parse_url(app_url(), PHP_URL_HOST) ?: 'dyspatch.com.ng'));
    ok(Payments::provider($provider)->initialize($email, $amt, $ref, app_url('api/wallet/topups/' . $ref . '/callback')));
});

route('GET', '/wallet/topups/{ref}/verify', function ($p) {
    $u = ApiAuth::requireUser();
    $t = DB::row('SELECT * FROM topup_requests WHERE reference = ? AND user_id = ?', [$p['ref'], $u['id']]);
    if (!$t) throw new ApiException('Top-up not found', 404);
    if ($t['method'] !== 'bank_transfer' && $t['status'] !== 'confirmed') $t = complete_card_topup($t['reference'], (int) $t['amount_kobo']) ?? $t;
    ok(['reference' => $t['reference'], 'status' => $t['status'], 'amount_kobo' => $t['amount_kobo'] !== null ? (int) $t['amount_kobo'] : null, 'balance_kobo' => Wallet::balance('user', (int) $u['id'])]);
});

route('GET', '/wallet/topups/{ref}/callback', function ($p) {
    $t = DB::row('SELECT * FROM topup_requests WHERE reference = ?', [$p['ref']]);
    if ($t) complete_card_topup($t['reference'], (int) $t['amount_kobo']);
    header('Content-Type: text/html; charset=utf-8');
    echo '<!doctype html><meta name="viewport" content="width=device-width"><body style="font-family:Montserrat,sans-serif;text-align:center;padding:60px 20px"><h2>Payment received</h2><p>You can return to the Dyspatch app.</p></body>';
    exit;
});

route('POST', '/wallet/withdraw', function () {
    [$type, $id] = owner();
    $acct = (int) (input()['bank_account_id'] ?? 0);
    if (!$acct) $acct = (int) DB::value('SELECT id FROM bank_accounts WHERE owner_type=? AND owner_id=? ORDER BY is_default DESC, id LIMIT 1', [$type, $id]);
    if (!$acct) throw new ApiException('Add a bank account first', 422);
    $w = Wallet::requestWithdrawal($type, $id, $acct, to_kobo(req('amount')));
    Notifier::adminAlert('New withdrawal request', '<p>' . naira($w['amount_kobo']) . " requested by $type #$id. Payout date: {$w['scheduled_for']}.</p>", app_url('admin/withdrawals.php'));
    $sameDay = $w['scheduled_for'] === date('Y-m-d');
    ok(['reference' => $w['reference'], 'amount_kobo' => (int) $w['amount_kobo'], 'fee_kobo' => (int) $w['fee_kobo'], 'status' => $w['status'],
        'scheduled_for' => $w['scheduled_for'], 'balance_kobo' => Wallet::balance($type, $id)],
        $sameDay ? 'Transfer initiated — you will be paid today' : 'Transfer initiated — you will be paid on ' . date('D, j M', strtotime($w['scheduled_for'])));
});

route('GET', '/withdrawals', function () {
    [$type, $id] = owner();
    ok(array_map(fn($w) => ['reference' => $w['reference'], 'amount_kobo' => (int) $w['amount_kobo'], 'fee_kobo' => (int) $w['fee_kobo'], 'status' => $w['status'],
        'scheduled_for' => $w['scheduled_for'], 'created_at' => iso($w['created_at'])],
        DB::all('SELECT * FROM withdrawals WHERE owner_type=? AND owner_id=? ORDER BY id DESC LIMIT 50', [$type, $id])));
});

route('GET', '/bank-accounts', function () {
    [$type, $id] = owner();
    ok(array_map('bank_payload', DB::all('SELECT * FROM bank_accounts WHERE owner_type=? AND owner_id=? ORDER BY is_default DESC, id', [$type, $id])));
});

route('POST', '/bank-accounts', function () {
    [$type, $id, $row] = owner();
    $num = preg_replace('/\D/', '', req('account_number', 'Account number'));
    if (strlen($num) !== 10) throw new ApiException('Enter a valid 10-digit account number', 422);
    $bank = req('bank_name', 'Bank name');
    $name = req('account_name', 'Account name');
    if (DB::value('SELECT COUNT(*) FROM bank_accounts WHERE owner_type=? AND owner_id=?', [$type, $id]) >= 5) throw new ApiException('You can save up to 5 accounts', 422);
    $verified = 0;
    $code = trim((string) (input()['bank_code'] ?? '')) ?: null;
    if ($code && Settings::get('paystack_secret_key')) {
        $r = http_request('GET', "https://api.paystack.co/bank/resolve?account_number=$num&bank_code=$code", ['Authorization' => 'Bearer ' . Settings::get('paystack_secret_key')]);
        if ($r['json']['status'] ?? false) { $name = $r['json']['data']['account_name']; $verified = 1; }
        else throw new ApiException('Could not verify this account number with the bank', 422);
    }
    $first = !DB::value('SELECT 1 FROM bank_accounts WHERE owner_type=? AND owner_id=?', [$type, $id]);
    $bid = DB::insert('bank_accounts', ['owner_type' => $type, 'owner_id' => $id, 'bank_name' => $bank, 'bank_code' => $code,
        'account_name' => mb_strtoupper($name), 'account_number' => $num, 'is_verified' => $verified, 'is_default' => $first ? 1 : 0]);
    ok(bank_payload(DB::row('SELECT * FROM bank_accounts WHERE id = ?', [$bid])), $verified ? 'Account verified and saved' : 'Account submitted for verification', 201);
});

route('POST', '/bank-accounts/{id}/default', function ($p) {
    [$type, $id] = owner();
    if (!DB::value('SELECT 1 FROM bank_accounts WHERE id=? AND owner_type=? AND owner_id=?', [$p['id'], $type, $id])) throw new ApiException('Not found', 404);
    DB::query('UPDATE bank_accounts SET is_default = (id = ?) WHERE owner_type=? AND owner_id=?', [$p['id'], $type, $id]);
    ok(null, 'Default account updated');
});

route('DELETE', '/bank-accounts/{id}', function ($p) {
    [$type, $id] = owner();
    if (DB::value("SELECT 1 FROM withdrawals WHERE bank_account_id = ? AND status IN ('pending','processing')", [$p['id']])) throw new ApiException('This account has a pending withdrawal', 409);
    DB::query('DELETE FROM bank_accounts WHERE id=? AND owner_type=? AND owner_id=?', [$p['id'], $type, $id]);
    ok(null, 'Account removed');
});

/* ─────────────── Notifications, locations, verification ─────────────── */
route('GET', '/notifications', function () {
    [$type, $id] = owner();
    $cat = input()['category'] ?? null;
    $sql = 'SELECT * FROM notifications WHERE owner_type=? AND owner_id=?';
    $p = [$type, $id];
    if (in_array($cat, ['delivery', 'payment', 'system'], true)) { $sql .= ' AND category = ?'; $p[] = $cat; }
    ok(array_map(fn($n) => ['id' => (int) $n['id'], 'category' => $n['category'], 'title' => $n['title'], 'body' => $n['body'],
        'data' => $n['data'] ? json_decode($n['data'], true) : null, 'is_read' => (bool) $n['read_at'], 'created_at' => iso($n['created_at'])],
        DB::all($sql . ' ORDER BY id DESC LIMIT 100', $p)));
});

route('POST', '/notifications/read', function () {
    [$type, $id] = owner();
    $ids = array_filter(array_map('intval', (array) (input()['ids'] ?? [])));
    if ($ids) DB::query('UPDATE notifications SET read_at = NOW() WHERE owner_type=? AND owner_id=? AND read_at IS NULL AND id IN (' . implode(',', $ids) . ')', [$type, $id]);
    else DB::query('UPDATE notifications SET read_at = NOW() WHERE owner_type=? AND owner_id=? AND read_at IS NULL', [$type, $id]);
    ok(null, 'Marked as read');
});

route('GET', '/saved-locations', function () {
    $u = ApiAuth::requireUser();
    ok(array_map(fn($l) => ['id' => (int) $l['id'], 'label' => $l['label'], 'address' => $l['address'], 'lat' => $l['lat'] !== null ? (float) $l['lat'] : null,
        'lng' => $l['lng'] !== null ? (float) $l['lng'] : null, 'is_default_pickup' => (bool) $l['is_default_pickup']],
        DB::all('SELECT * FROM saved_locations WHERE user_id = ? ORDER BY is_default_pickup DESC, id DESC', [$u['id']])));
});

route('POST', '/saved-locations', function () {
    $u = ApiAuth::requireUser();
    $in = input();
    $default = filter_var($in['is_default_pickup'] ?? false, FILTER_VALIDATE_BOOLEAN);
    if ($default) DB::query('UPDATE saved_locations SET is_default_pickup = 0 WHERE user_id = ?', [$u['id']]);
    $id = DB::insert('saved_locations', ['user_id' => $u['id'], 'label' => mb_substr(req('label'), 0, 60), 'address' => mb_substr(req('address'), 0, 255),
        'lat' => isset($in['lat']) ? (float) $in['lat'] : null, 'lng' => isset($in['lng']) ? (float) $in['lng'] : null, 'is_default_pickup' => $default ? 1 : 0]);
    ok(['id' => $id], 'Location saved', 201);
});

route('DELETE', '/saved-locations/{id}', function ($p) {
    $u = ApiAuth::requireUser();
    DB::query('DELETE FROM saved_locations WHERE id = ? AND user_id = ?', [$p['id'], $u['id']]);
    ok(null, 'Location removed');
});

route('GET', '/business-verification', function () {
    $u = ApiAuth::requireUser();
    $b = DB::row('SELECT * FROM business_verifications WHERE user_id = ? ORDER BY id DESC LIMIT 1', [$u['id']]);
    ok($b ? ['status' => $b['status'], 'business_name' => $b['business_name'], 'reg_number' => $b['reg_number'], 'address' => $b['address'], 'note' => $b['note'], 'created_at' => iso($b['created_at'])] : null);
});

route('POST', '/business-verification', function () {
    $u = ApiAuth::requireUser();
    if (DB::value("SELECT 1 FROM business_verifications WHERE user_id = ? AND status = 'pending'", [$u['id']])) throw new ApiException('You already have a verification under review', 409);
    $doc = save_upload($_FILES['id_document'] ?? (input()['id_document'] ?? null), 'kyc');
    if (!$doc) throw new ApiException('Upload a clear photo of a government ID', 422);
    $id = DB::insert('business_verifications', ['user_id' => $u['id'], 'business_name' => mb_substr(req('business_name'), 0, 150),
        'reg_number' => mb_substr(req('reg_number', 'Registration number'), 0, 60), 'address' => mb_substr(req('address'), 0, 255), 'id_document' => $doc, 'provider' => 'manual']);
    Notifier::adminAlert('Business verification submitted', '<p>' . e(input()['business_name'] ?? '') . ' submitted documents for review.</p>', app_url('admin/verifications.php'));
    ok(['id' => $id, 'status' => 'pending'], 'Submitted! We\'ll review your documents shortly.', 201);
});

/* ─────────────── Rider app ─────────────── */
route('GET', '/rider/me', function () {
    $r = ApiAuth::requireRider();
    $active = DB::row("SELECT * FROM orders WHERE rider_id = ? AND status IN ('matched','picked_up','en_route','arrived') LIMIT 1", [$r['id']]);
    ok(rider_payload($r) + ['wallet_balance_kobo' => Wallet::balance('rider', (int) $r['id']), 'active_order_id' => $active ? (int) $active['id'] : null,
        'today_earnings_kobo' => (int) DB::value("SELECT COALESCE(SUM(rider_earning_kobo),0) FROM orders WHERE rider_id = ? AND status='delivered' AND DATE(delivered_at) = CURDATE()", [$r['id']]),
        'today_deliveries' => (int) DB::value("SELECT COUNT(*) FROM orders WHERE rider_id = ? AND status='delivered' AND DATE(delivered_at) = CURDATE()", [$r['id']])]);
});

route('PUT', '/rider/me', function () {
    $r = ApiAuth::requireRider();
    $in = input();
    $upd = [];
    foreach (['first_name', 'last_name', 'plate'] as $f) if (isset($in[$f])) $upd[$f] = mb_substr(trim((string) $in[$f]), 0, 80);
    if (isset($in['email'])) $upd['email'] = filter_var($in['email'], FILTER_VALIDATE_EMAIL) ?: null;
    if (isset($in['vehicle_type']) && in_array($in['vehicle_type'], ['bike', 'bicycle', 'car', 'truck'], true)) $upd['vehicle_type'] = $in['vehicle_type'];
    if (!empty($in['zone_code'])) $upd['zone_id'] = DB::value('SELECT id FROM zones WHERE code = ?', [strtoupper($in['zone_code'])]);
    if ($p = save_upload($_FILES['photo'] ?? ($in['photo'] ?? null), 'riders')) $upd['photo'] = $p;
    if ($upd) DB::update('riders', $upd, 'id = ?', [$r['id']]);
    ok(rider_payload(DB::row('SELECT * FROM riders WHERE id = ?', [$r['id']])), 'Profile updated');
});

route('POST', '/rider/kyc', function () {
    $r = ApiAuth::requireRider();
    $in = input();
    $type = in_array($in['id_type'] ?? '', ['nin', 'bvn', 'drivers_license', 'voters_card'], true) ? $in['id_type'] : 'nin';
    $num = req('id_number', 'ID number');
    $doc = save_upload($_FILES['id_document'] ?? ($in['id_document'] ?? null), 'kyc');
    $res = Kyc::provider()->verify($type, $num, (string) ($in['first_name'] ?? $r['first_name']), (string) ($in['last_name'] ?? $r['last_name']));
    $status = $res['status'] === 'verified' ? 'verified' : ($res['status'] === 'failed' ? 'rejected' : 'submitted');
    DB::update('riders', ['id_type' => $type, 'id_number' => $num, 'id_document' => $doc ?: $r['id_document'], 'kyc_status' => $status,
        'kyc_provider' => Settings::get('kyc_provider', 'manual'), 'kyc_reference' => $res['reference'],
        'status' => $status === 'verified' && $r['status'] === 'pending' ? 'active' : $r['status']], 'id = ?', [$r['id']]);
    if ($status === 'submitted') Notifier::adminAlert('Rider awaiting verification', '<p>' . e($r['first_name'] . ' ' . $r['last_name'] . ' ' . $r['phone']) . ' submitted ID for review.</p>', app_url('admin/rider.php?id=' . $r['id']));
    ok(['kyc_status' => $status, 'message' => $res['message']], $status === 'verified' ? 'Verified! You can go online now.' : 'Submitted for review — usually under 48 hours');
});

route('POST', '/rider/online', function () {
    $r = ApiAuth::requireRider();
    $on = filter_var(input()['online'] ?? true, FILTER_VALIDATE_BOOLEAN);
    if ($on && ($r['status'] !== 'active' || $r['kyc_status'] !== 'verified')) throw new ApiException('Your account must be verified before going online', 403);
    $upd = ['is_online' => $on ? 1 : 0];
    if (isset(input()['lat'], input()['lng'])) $upd += ['lat' => (float) input()['lat'], 'lng' => (float) input()['lng'], 'location_updated_at' => now()];
    DB::update('riders', $upd, 'id = ?', [$r['id']]);
    if ($on) Matching::tick();
    ok(['is_online' => $on], $on ? 'You are online' : 'You are offline');
});

route('POST', '/rider/location', function () {
    $r = ApiAuth::requireRider();
    $lat = (float) req('lat');
    $lng = (float) req('lng');
    $heading = isset(input()['heading']) ? (float) input()['heading'] : null;
    DB::update('riders', ['lat' => $lat, 'lng' => $lng, 'heading' => $heading, 'location_updated_at' => now()], 'id = ?', [$r['id']]);
    $active = DB::value("SELECT id FROM orders WHERE rider_id = ? AND status IN ('matched','picked_up','en_route','arrived') LIMIT 1", [$r['id']]);
    $last = DB::row('SELECT lat, lng, created_at FROM rider_locations WHERE rider_id = ? ORDER BY id DESC LIMIT 1', [$r['id']]);
    if (!$last || haversine_km((float) $last['lat'], (float) $last['lng'], $lat, $lng) > 0.02 || strtotime($last['created_at']) < time() - 60) {
        DB::insert('rider_locations', ['rider_id' => $r['id'], 'order_id' => $active ?: null, 'lat' => $lat, 'lng' => $lng, 'heading' => $heading,
            'speed' => isset(input()['speed']) ? (float) input()['speed'] : null]);
    }
    Matching::tick();
    ok(['active_order_id' => $active ? (int) $active : null]);
});

route('GET', '/rider/offers', function () {
    $r = ApiAuth::requireRider();
    Matching::tick();
    ok(array_map(function ($f) {
        $o = Orders::find((int) $f['order_id']);
        return ['offer_id' => (int) $f['id'], 'order_id' => (int) $o['id'], 'expires_in' => max(0, strtotime($f['expires_at']) - time()),
            'distance_to_pickup_km' => (float) $f['distance_km'], 'trip_km' => (float) $o['distance_km'], 'earning_kobo' => (int) $o['rider_earning_kobo'],
            'pickup' => ['address' => $o['pickup_address'], 'lat' => (float) $o['pickup_lat'], 'lng' => (float) $o['pickup_lng']],
            'dropoff' => ['address' => $o['dropoff_address'], 'lat' => (float) $o['dropoff_lat'], 'lng' => (float) $o['dropoff_lng']],
            'package_type' => $o['package_type'], 'payment_method' => $o['payment_method'], 'fee_kobo' => (int) $o['fee_kobo']];
    }, DB::all("SELECT * FROM order_offers WHERE rider_id = ? AND status = 'offered' AND expires_at > NOW()", [$r['id']])));
});

route('POST', '/rider/offers/{id}/accept', function ($p) {
    $r = ApiAuth::requireRider();
    ok(rider_order_payload(Matching::accept((int) $p['id'], (int) $r['id'])), 'Delivery accepted');
});
route('POST', '/rider/offers/{id}/decline', function ($p) {
    $r = ApiAuth::requireRider();
    Matching::decline((int) $p['id'], (int) $r['id']);
    ok(null, 'Declined');
});

function rider_order_payload(array $o): array
{
    $items = Orders::items((int) $o['id']);
    return ['id' => (int) $o['id'], 'order_no' => $o['order_no'], 'track_id' => $o['track_id'], 'status' => $o['status'],
        'status_label' => Orders::LABELS[$o['status']], 'sender_name' => $o['sender_name'], 'sender_phone' => $o['sender_phone'],
        'pickup' => ['address' => $o['pickup_address'], 'lat' => (float) $o['pickup_lat'], 'lng' => (float) $o['pickup_lng']],
        'dropoff' => ['address' => $o['dropoff_address'], 'lat' => (float) $o['dropoff_lat'], 'lng' => (float) $o['dropoff_lng']],
        'recipient_name' => $o['recipient_name'], 'recipient_phone' => $o['recipient_phone'], 'package_type' => $o['package_type'],
        'package_description' => $o['package_description'], 'items' => $items, 'payment_method' => $o['payment_method'],
        'collect_cash_kobo' => $o['payment_method'] === 'cash' ? (int) $o['fee_kobo'] : 0, 'earning_kobo' => (int) $o['rider_earning_kobo'],
        'distance_km' => (float) $o['distance_km'], 'created_at' => iso($o['created_at']), 'delivered_at' => iso($o['delivered_at'])];
}

route('GET', '/rider/orders', function () {
    $r = ApiAuth::requireRider();
    $f = input()['status'] ?? 'all';
    $sql = 'SELECT * FROM orders WHERE rider_id = ?';
    if ($f === 'active') $sql .= " AND status IN ('matched','picked_up','en_route','arrived')";
    elseif ($f === 'completed') $sql .= " AND status IN ('delivered','cancelled','failed')";
    ok(array_map('rider_order_payload', DB::all($sql . ' ORDER BY id DESC LIMIT 50', [$r['id']])));
});

route('GET', '/rider/orders/{id}', fn($p) => ok(rider_order_payload(rider_order(ApiAuth::requireRider(), $p['id']))));

route('POST', '/rider/orders/{id}/pickup', function ($p) {
    $r = ApiAuth::requireRider();
    $o = rider_order($r, $p['id']);
    if (!hash_equals((string) $o['pickup_code'], trim(req('code', 'Pickup code')))) throw new ApiException('Wrong pickup code. Ask the sender for the 4-digit code.', 422);
    $in = input();
    ok(rider_order_payload(Orders::setStatus((int) $o['id'], 'picked_up', 'rider', (int) $r['id'], 'Pickup code verified', false, isset($in['lat']) ? (float) $in['lat'] : null, isset($in['lng']) ? (float) $in['lng'] : null)), 'Package picked up');
});

foreach (['en-route' => 'en_route', 'arrived' => 'arrived'] as $seg => $st) {
    route('POST', "/rider/orders/{id}/$seg", function ($p) use ($st) {
        $r = ApiAuth::requireRider();
        $o = rider_order($r, $p['id']);
        $in = input();
        ok(rider_order_payload(Orders::setStatus((int) $o['id'], $st, 'rider', (int) $r['id'], null, false, isset($in['lat']) ? (float) $in['lat'] : null, isset($in['lng']) ? (float) $in['lng'] : null)), Orders::LABELS[$st]);
    });
}

route('POST', '/rider/orders/{id}/deliver', function ($p) {
    $r = ApiAuth::requireRider();
    $o = rider_order($r, $p['id']);
    if ($photo = save_upload($_FILES['photo'] ?? (input()['photo'] ?? null), 'proofs')) DB::update('orders', ['proof_photo' => $photo], 'id = ?', [$o['id']]);
    $in = input();
    ok(rider_order_payload(Orders::verifyDeliveryCode((int) $o['id'], req('code', 'Delivery code'), (int) $r['id'], isset($in['lat']) ? (float) $in['lat'] : null, isset($in['lng']) ? (float) $in['lng'] : null)), 'Delivered — earnings added to your wallet');
});

route('POST', '/rider/orders/{id}/fail', function ($p) {
    $r = ApiAuth::requireRider();
    $o = rider_order($r, $p['id']);
    $o = Orders::setStatus((int) $o['id'], 'failed', 'rider', (int) $r['id'], req('reason'));
    Notifier::adminAlert("Delivery failed: {$o['track_id']}", '<p>' . e($o['cancel_reason']) . '</p>', app_url('admin/order.php?id=' . $o['id']));
    ok(rider_order_payload($o), 'Reported');
});

route('POST', '/rider/sos', function () {
    $r = ApiAuth::requireRider();
    $active = DB::value("SELECT id FROM orders WHERE rider_id = ? AND status IN ('matched','picked_up','en_route','arrived') LIMIT 1", [$r['id']]);
    $id = DB::insert('sos_alerts', ['order_id' => $active ?: null, 'rider_id' => $r['id'], 'lat' => $r['lat'], 'lng' => $r['lng'],
        'message' => mb_substr((string) (input()['message'] ?? 'Rider flagged a safety concern'), 0, 255)]);
    Notifier::adminAlert('Rider SOS', '<p>' . e($r['first_name'] . ' ' . $r['last_name'] . ' (' . $r['phone'] . ')') . ' raised an SOS.</p>', app_url('admin/sos.php'));
    ok(['id' => $id], 'SOS sent. Our team has been alerted.');
});

/* ─────────────────────────── Dispatch ─────────────────────────── */
$GLOBALS['dispatch'] = function (string $method, string $path) use (&$routes) {
    $allowed = false;
    foreach ($routes as [$m, $re, $fn]) {
        if (preg_match($re, $path, $mm)) {
            $allowed = true;
            if ($m === $method || ($method === 'PATCH' && $m === 'PUT')) {
                $fn(array_filter($mm, 'is_string', ARRAY_FILTER_USE_KEY));
                return;
            }
        }
    }
    throw new ApiException($allowed ? 'Method not allowed' : 'Endpoint not found', $allowed ? 405 : 404);
};

try {
    $GLOBALS['dispatch']($method, $path);
} catch (ApiException $e) {
    http_response_code($e->status);
    echo json_encode(['success' => false, 'message' => $e->getMessage(), 'errors' => (object) $e->errors], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
} catch (Throwable $e) {
    log_line('api', $e::class . ': ' . $e->getMessage() . ' @ ' . $e->getFile() . ':' . $e->getLine());
    http_response_code(500);
    $msg = config('env') === 'development' ? $e->getMessage() : 'Something went wrong. Please try again.';
    echo json_encode(['success' => false, 'message' => $msg, 'errors' => (object) []]);
}
