<?php
require __DIR__ . '/_init.php';
if (admin()) redirect('index.php');

$error = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $key = 'login_' . ($_SERVER['REMOTE_ADDR'] ?? '');
    $_SESSION[$key] = array_filter($_SESSION[$key] ?? [], fn($t) => $t > time() - 900);
    if (count($_SESSION[$key]) >= 8) {
        $error = 'Too many attempts. Try again in 15 minutes.';
    } else {
        $a = DB::row('SELECT * FROM admins WHERE email = ? AND is_active = 1', [trim((string) ($_POST['email'] ?? ''))]);
        if ($a && password_verify((string) ($_POST['password'] ?? ''), $a['password_hash'])) {
            session_regenerate_id(true);
            $_SESSION['admin_id'] = (int) $a['id'];
            unset($_SESSION[$key]);
            DB::update('admins', ['last_login_at' => now()], 'id = ?', [$a['id']]);
            audit((int) $a['id'], 'login');
            $next = (string) ($_GET['next'] ?? '');
            redirect($next && str_starts_with($next, '/') && !str_starts_with($next, '//') ? $next : 'index.php');
        }
        $_SESSION[$key][] = time();
        $error = 'Incorrect email or password.';
    }
}
$riders = (int) DB::value("SELECT COUNT(*) FROM riders WHERE is_online = 1");
$today = (int) DB::value('SELECT COUNT(*) FROM orders WHERE DATE(created_at) = CURDATE()');
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sign in · Dyspatch Admin</title>
<link rel="icon" href="../assets/img/favicon.png">
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../assets/css/admin.css?v=3">
</head>
<body>
<div class="auth">
  <div class="art">
    <div class="brand"><img src="../assets/img/logo-mark.svg" alt=""> Dyspatch</div>
    <div style="position:relative;z-index:1">
      <h1>Move <em>everything</em>.<br>Trust <em>every</em> rider.</h1>
      <p style="color:#A0A4AB;margin-top:16px;max-width:400px">Dispatch, track every parcel live, and keep riders and customers moving — from one console.</p>
    </div>
    <div class="meta">System: <b>Operational</b> &nbsp;·&nbsp; Riders online: <b><?= $riders ?></b> &nbsp;·&nbsp; Deliveries today: <b><?= $today ?></b></div>
  </div>
  <div class="panel">
    <form method="post" autocomplete="on">
      <?= csrf_field() ?>
      <div>
        <h2>Welcome back</h2>
        <p class="muted" style="margin-top:6px">Sign in to the Dyspatch admin dashboard.</p>
      </div>
      <?php if ($error): ?><div class="flash err"><?= e($error) ?></div><?php endif; ?>
      <label class="f">Email<input class="input" type="email" name="email" required autofocus value="<?= e($_POST['email'] ?? '') ?>"></label>
      <label class="f">Password<input class="input" type="password" name="password" required></label>
      <button class="btn block" style="padding:13px">Sign in</button>
      <p class="faint small" style="text-align:center">admin.dyspatch · authorised staff only</p>
    </form>
  </div>
</div>
</body>
</html>
