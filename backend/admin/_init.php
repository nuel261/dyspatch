<?php
declare(strict_types=1);
require dirname(__DIR__) . '/includes/bootstrap.php';

session_name('dyspatch_admin');
session_set_cookie_params(['httponly' => true, 'samesite' => 'Lax', 'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off']);
session_start();

function admin(): ?array
{
    static $a = false;
    if ($a !== false) return $a;
    $a = !empty($_SESSION['admin_id']) ? DB::row('SELECT * FROM admins WHERE id = ? AND is_active = 1', [$_SESSION['admin_id']]) : null;
    return $a;
}

function require_admin(array $roles = []): array
{
    $a = admin();
    if (!$a) { header('Location: login.php?next=' . urlencode($_SERVER['REQUEST_URI'] ?? '')); exit; }
    if ($roles && !in_array($a['role'], $roles, true)) { http_response_code(403); layout_start('Not allowed', ''); echo '<div class="card card-b">You do not have permission to view this page.</div>'; layout_end(); exit; }
    return $a;
}

function csrf(): string
{
    if (empty($_SESSION['csrf'])) $_SESSION['csrf'] = bin2hex(random_bytes(16));
    return $_SESSION['csrf'];
}
function csrf_field(): string { return '<input type="hidden" name="_csrf" value="' . csrf() . '">'; }
function check_csrf(): void
{
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && !hash_equals(csrf(), (string) ($_POST['_csrf'] ?? $_SERVER['HTTP_X_CSRF'] ?? ''))) {
        http_response_code(419);
        exit('Session expired. Go back and refresh the page.');
    }
}

function flash(?string $msg = null, string $type = 'ok'): ?array
{
    if ($msg !== null) { $_SESSION['flash'] = [$type, $msg]; return null; }
    $f = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $f;
}

function redirect(string $url): never { header("Location: $url"); exit; }

/** Runs a POST action with CSRF + friendly error flash, then redirects back. */
function handle_post(callable $fn, ?string $back = null): void
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') return;
    check_csrf();
    try {
        $msg = $fn($_POST);
        if (is_string($msg)) flash($msg);
    } catch (ApiException $e) {
        flash($e->getMessage(), 'err');
    } catch (Throwable $e) {
        log_line('admin', $e->getMessage() . ' @ ' . $e->getFile() . ':' . $e->getLine());
        flash(config('env') === 'development' ? $e->getMessage() : 'Something went wrong.', 'err');
    }
    redirect($back ?? ($_SERVER['REQUEST_URI'] ?? 'index.php'));
}

function badge(?string $status, ?string $label = null): string
{
    $s = (string) $status;
    $label ??= Orders::LABELS[$s] ?? Orders::ITEM_LABELS[$s] ?? ucwords(str_replace('_', ' ', $s));
    return '<span class="badge b-' . e($s) . '">' . e($label) . '</span>';
}

function tid(string $code): string
{
    return '<span class="tid" data-copy="' . e($code) . '" title="Click to copy">' . e($code) . '</span>';
}

function initials(?string $name): string
{
    $p = preg_split('/\s+/', trim((string) $name)) ?: [];
    return strtoupper(mb_substr($p[0] ?? '?', 0, 1) . mb_substr($p[1] ?? '', 0, 1));
}

function avatar(?string $name, ?string $photo = null, string $cls = ''): string
{
    return '<span class="av ' . $cls . '">' . ($photo ? '<img src="' . e(public_file($photo)) . '" alt="">' : e(initials($name))) . '</span>';
}

function icon(string $n): string
{
    static $p = [
        'home' => '<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
        'box' => '<path d="M21 8 12 3 3 8v8l9 5 9-5z"/><path d="m3 8 9 5 9-5M12 13v8"/>',
        'map' => '<path d="m9 4-6 2v14l6-2 6 2 6-2V4l-6 2z"/><path d="M9 4v14M15 6v14"/>',
        'pin' => '<path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/>',
        'users' => '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 7M21.5 20a6.5 6.5 0 0 0-4-6"/>',
        'bike' => '<circle cx="5.5" cy="17" r="3.5"/><circle cx="18.5" cy="17" r="3.5"/><path d="M5.5 17 9 9h6l3.5 8M9 9 7.5 6H5M15 9l-3 8"/>',
        'wallet' => '<rect x="3" y="6" width="18" height="14" rx="3"/><path d="M3 10h18M16 15h2M7 6V4.5A1.5 1.5 0 0 1 8.5 3H18"/>',
        'down' => '<path d="M12 4v12m0 0-5-5m5 5 5-5M5 20h14"/>',
        'up' => '<path d="M12 20V8m0 0-5 5m5-5 5 5M5 4h14"/>',
        'alert' => '<path d="M12 3 2 20h20z"/><path d="M12 10v4m0 3v.01"/>',
        'settings' => '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
        'shield' => '<path d="M12 3 4 6v6c0 4.5 3.4 8.3 8 9 4.6-.7 8-4.5 8-9V6z"/><path d="m9 12 2 2 4-4"/>',
        'logout' => '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l-5-5 5-5M5 12h11"/>',
        'search' => '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
        'plus' => '<path d="M12 5v14M5 12h14"/>',
        'check' => '<path d="m5 12 5 5 9-10"/>',
        'clock' => '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
        'bell' => '<path d="M6 8a6 6 0 1 1 12 0c0 7 3 8 3 8H3s3-1 3-8M10 20a2 2 0 0 0 4 0"/>',
        'receipt' => '<path d="M5 3h14v18l-3-2-2 2-2-2-2 2-2-2-3 2z"/><path d="M9 8h6M9 12h6"/>',
        'filecheck' => '<path d="M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8z"/><path d="M14 3v5h5M9 15l2 2 4-4"/>',
        'menu' => '<path d="M4 7h16M4 12h16M4 17h16"/>',
        'sun' => '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
        'copy' => '<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
        'phone' => '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/>',
        'link' => '<path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7"/><path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7"/>',
        'truck' => '<path d="M3 6h11v10H3zM14 9h4l3 3v4h-7"/><circle cx="7" cy="17.5" r="1.8"/><circle cx="17" cy="17.5" r="1.8"/>',
        'layers' => '<path d="m12 3 9 5-9 5-9-5z"/><path d="m3 13 9 5 9-5"/>',
        'activity' => '<path d="M3 12h4l3-8 4 16 3-8h4"/>',
    ];
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">' . ($p[$n] ?? '') . '</svg>';
}

function nav_counts(): array
{
    static $c = null;
    return $c ??= [
        'sos' => (int) DB::value("SELECT COUNT(*) FROM sos_alerts WHERE status <> 'resolved'"),
        'topups' => (int) DB::value("SELECT COUNT(*) FROM topup_requests WHERE status = 'pending' AND method = 'bank_transfer'"),
        'withdrawals' => (int) DB::value("SELECT COUNT(*) FROM withdrawals WHERE status IN ('pending','failed')"),
        'kyc' => (int) DB::value("SELECT COUNT(*) FROM riders WHERE kyc_status = 'submitted'") + (int) DB::value("SELECT COUNT(*) FROM business_verifications WHERE status = 'pending'"),
        'pending' => (int) DB::value("SELECT COUNT(*) FROM orders WHERE status = 'pending'"),
    ];
}

function layout_start(string $title, string $active, string $subtitle = '', string $actions = '', bool $search = true): void
{
    $a = admin();
    $c = $a ? nav_counts() : [];
    $f = flash();
    $nav = [
        ['Operations', [
            ['index.php', 'home', 'Dashboard', 'dashboard', null],
            ['orders.php', 'box', 'Orders', 'orders', $c['pending'] ?? 0, 'g'],
            ['live.php', 'map', 'Live map', 'live', null],
            ['sos.php', 'alert', 'SOS alerts', 'sos', $c['sos'] ?? 0],
        ]],
        ['People', [
            ['riders.php', 'bike', 'Riders', 'riders', null],
            ['customers.php', 'users', 'Customers', 'customers', null],
            ['verifications.php', 'filecheck', 'Verifications', 'verifications', $c['kyc'] ?? 0],
        ]],
        ['Money', [
            ['topups.php', 'down', 'Top-ups', 'topups', $c['topups'] ?? 0],
            ['withdrawals.php', 'up', 'Withdrawals', 'withdrawals', $c['withdrawals'] ?? 0],
            ['transactions.php', 'receipt', 'Transactions', 'transactions', null],
        ]],
        ['Platform', [
            ['zones.php', 'layers', 'Zones', 'zones', null],
            ['notify.php', 'bell', 'Broadcast', 'notify', null],
            ['settings.php', 'settings', 'Settings', 'settings', null],
            ['admins.php', 'shield', 'Admins & logs', 'admins', null],
        ]],
    ];
    $riders = (int) DB::value("SELECT COUNT(*) FROM riders WHERE is_online = 1 AND location_updated_at > NOW() - INTERVAL 10 MINUTE");
    $today = (int) DB::value('SELECT COUNT(*) FROM orders WHERE DATE(created_at) = CURDATE()');
    $active = (int) DB::value("SELECT COUNT(*) FROM orders WHERE status IN ('matched','picked_up','en_route','arrived')");
    $live = implode(' & ', array_column(DB::all('SELECT name FROM zones WHERE is_live = 1'), 'name')) ?: 'NO LIVE ZONES';
    ?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= e($title) ?> · Dyspatch Admin</title>
<meta name="theme-color" content="#0E120F">
<link rel="icon" href="../assets/img/favicon.png">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css">
<link rel="stylesheet" href="../assets/css/admin.css?v=3">
<script>try{var t=localStorage.getItem('dsp-theme');if(t)document.documentElement.dataset.theme=t}catch(e){}</script>
</head>
<body>
<div class="shell">
  <aside class="side">
    <a class="brand" href="index.php"><img src="../assets/img/logo-mark.svg" alt=""> Dyspatch <small>Admin</small></a>
    <?php foreach ($nav as [$label, $links]): ?>
      <div class="label"><?= e($label) ?></div>
      <?php foreach ($links as $l): ?>
        <a href="<?= $l[0] ?>" class="<?= $active === $l[3] ? 'active' : '' ?>"><?= icon($l[1]) ?> <?= e($l[2]) ?><?php if (!empty($l[4])): ?><span class="count <?= $l[5] ?? '' ?>"><?= (int) $l[4] ?></span><?php endif; ?></a>
      <?php endforeach; ?>
    <?php endforeach; ?>
    <div class="foot">
      <?php if ($a): ?><b><?= e($a['name']) ?></b><?= e(ucfirst($a['role'])) ?> · <a href="logout.php" style="display:inline;padding:0;color:#6BD187">Sign out</a><?php endif; ?>
    </div>
  </aside>
  <main class="main">
    <div class="ticker"><span><i class="dot"></i>System: <b>Operational</b></span><span>·</span><span>Riders online: <b><?= $riders ?></b></span><span>·</span><span>Active deliveries: <b><?= $active ?></b></span><span>·</span><span>Deliveries today: <b><?= number_format($today) ?></b></span><span>·</span><span>Live: <b><?= e(strtoupper($live)) ?></b></span><span>·</span><span><?= date('D j M · H:i') ?> WAT</span></div>
    <div class="topbar">
      <button class="btn ghost sm menu-btn" onclick="document.body.classList.toggle('nav-open')" aria-label="Menu"><?= icon('menu') ?></button>
      <div class="title"><h1><?= e($title) ?></h1><?php if ($subtitle): ?><p class="muted"><?= $subtitle ?></p><?php endif; ?></div>
      <?php if ($search): ?>
      <form class="tracksearch" action="track.php" method="get"><?= icon('search') ?><input name="q" placeholder="Track ID, item code or phone" autocomplete="off"><button class="btn sm">Track</button></form>
      <?php endif; ?>
      <?= $actions ?>
      <button class="btn ghost sm" id="themeBtn" title="Toggle theme" aria-label="Toggle theme"><?= icon('sun') ?></button>
    </div>
    <div class="content">
      <?php if ($f): ?><div class="flash <?= e($f[0]) ?>"><?= icon($f[0] === 'ok' ? 'check' : 'alert') ?><span><?= e($f[1]) ?></span></div><?php endif; ?>
<?php
}

function layout_end(string $scripts = ''): void
{
    ?>
    </div>
  </main>
</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js"></script>
<script src="../assets/js/admin.js?v=3"></script>
<?= $scripts ?>
</body>
</html>
<?php
}

/** Simple paginator: returns [rows, html]. */
function paginate(string $sql, array $params, int $per = 25): array
{
    $page = max(1, (int) ($_GET['page'] ?? 1));
    $total = (int) DB::value('SELECT COUNT(*) FROM (' . $sql . ') x', $params);
    $rows = DB::all($sql . ' LIMIT ' . $per . ' OFFSET ' . (($page - 1) * $per), $params);
    $pages = max(1, (int) ceil($total / $per));
    $html = '';
    if ($pages > 1) {
        $q = $_GET;
        $mk = function ($p) use ($q) { $q['page'] = $p; return '?' . http_build_query($q); };
        $html = '<div class="row between" style="padding:14px 22px;border-top:1px solid var(--border)"><span class="muted small">Page ' . $page . ' of ' . $pages . ' · ' . number_format($total) . ' total</span><div class="row">'
            . ($page > 1 ? '<a class="btn ghost sm" href="' . e($mk($page - 1)) . '">Previous</a>' : '')
            . ($page < $pages ? '<a class="btn ghost sm" href="' . e($mk($page + 1)) . '">Next</a>' : '') . '</div></div>';
    }
    return [$rows, $html, $total];
}
