<?php
/**
 * One-time installer: writes config/config.php, creates tables, creates the first admin.
 * Delete this file after installation.
 */
declare(strict_types=1);
define('INSTALLING', true);
$base = __DIR__;
$configFile = "$base/config/config.php";
$done = false;
$error = null;

if (file_exists($configFile) && !isset($_GET['force'])) {
    $cfg = require $configFile;
    try {
        $pdo = new PDO("mysql:host={$cfg['db']['host']};port={$cfg['db']['port']};dbname={$cfg['db']['name']}", $cfg['db']['user'], $cfg['db']['pass']);
        if ($pdo->query("SHOW TABLES LIKE 'admins'")->fetch() && (int) $pdo->query('SELECT COUNT(*) FROM admins')->fetchColumn() > 0) {
            exit('<p style="font-family:sans-serif;padding:40px">Dyspatch is already installed. Delete <code>install.php</code> from the server.</p>');
        }
    } catch (Throwable $e) { /* fall through to the form */ }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        $db = ['host' => trim($_POST['db_host']), 'port' => (int) ($_POST['db_port'] ?: 3306), 'name' => trim($_POST['db_name']), 'user' => trim($_POST['db_user']), 'pass' => (string) $_POST['db_pass'], 'charset' => 'utf8mb4'];
        $pdo = new PDO("mysql:host={$db['host']};port={$db['port']};dbname={$db['name']};charset=utf8mb4", $db['user'], $db['pass'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        $sql = file_get_contents("$base/database/schema.sql");
        foreach (array_filter(array_map('trim', preg_split('/;\s*\n/', preg_replace('/^--.*$/m', '', $sql)))) as $stmt) $pdo->exec($stmt);

        $email = trim($_POST['admin_email']);
        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($_POST['admin_password']) < 8) throw new RuntimeException('Enter a valid admin email and a password of at least 8 characters.');
        $pdo->prepare('INSERT INTO admins (name, email, password_hash, role) VALUES (?,?,?,?)')->execute([trim($_POST['admin_name']) ?: 'Admin', $email, password_hash($_POST['admin_password'], PASSWORD_DEFAULT), 'super']);
        $pdo->prepare("INSERT INTO settings (`key`,`value`) VALUES ('admin_alert_email', ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)")->execute([$email]);

        $url = rtrim(trim($_POST['app_url']), '/');
        $cfg = "<?php\nreturn " . var_export([
            'app_url' => $url, 'env' => 'production', 'timezone' => 'Africa/Lagos', 'db' => $db,
            'app_key' => bin2hex(random_bytes(32)), 'token_ttl_days' => 60, 'cron_key' => bin2hex(random_bytes(12)),
        ], true) . ";\n";
        if (@file_put_contents($configFile, $cfg) === false) throw new RuntimeException('Could not write config/config.php — make the config folder writable, or create the file manually.');
        foreach (['storage/logs', 'storage/cache', 'storage/uploads'] as $d) @mkdir("$base/$d", 0775, true);
        $done = (require $configFile)['cron_key'];
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}
$guessUrl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'http') . '://' . ($_SERVER['HTTP_HOST'] ?? 'dyspatch.bitprofil.com') . rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? '/'), '/');
?>
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Install Dyspatch</title>
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/css/admin.css"></head>
<body class="dots-bg" style="padding:40px 16px">
<div class="card" style="max-width:640px;margin:0 auto">
  <div class="card-h"><img src="assets/img/logo-mark.svg" width="28" alt=""><h2>Install Dyspatch backend</h2></div>
  <div class="card-b">
  <?php if ($done): ?>
    <div class="flash ok">Installed successfully.</div>
    <div class="stack" style="margin-top:16px">
      <p><b>1.</b> Delete <code>install.php</code> from the server now.</p>
      <p><b>2.</b> Add a cron job in cPanel (every minute):<br><code class="mono">* * * * * php <?= htmlspecialchars($base) ?>/cron/run.php &gt;/dev/null 2&gt;&amp;1</code></p>
      <p class="muted small">Or call by URL: <span class="mono"><?= htmlspecialchars(rtrim($_POST['app_url'], '/')) ?>/cron/run.php?key=<?= htmlspecialchars($done) ?></span></p>
      <p><b>3.</b> <a class="btn" href="admin/login.php">Open the admin</a> and finish setup under <b>Settings</b> (email, push, payments, SMS).</p>
    </div>
  <?php else: ?>
    <?php if ($error): ?><div class="flash err" style="margin-bottom:16px"><?= htmlspecialchars($error) ?></div><?php endif; ?>
    <form method="post" class="form-grid">
      <label class="f full">Site URL<input class="input" name="app_url" value="<?= htmlspecialchars($_POST['app_url'] ?? $guessUrl) ?>" required></label>
      <label class="f">Database host<input class="input" name="db_host" value="<?= htmlspecialchars($_POST['db_host'] ?? 'localhost') ?>" required></label>
      <label class="f">Port<input class="input" name="db_port" value="<?= htmlspecialchars($_POST['db_port'] ?? '3306') ?>"></label>
      <label class="f">Database name<input class="input" name="db_name" value="<?= htmlspecialchars($_POST['db_name'] ?? '') ?>" required></label>
      <label class="f">Database user<input class="input" name="db_user" value="<?= htmlspecialchars($_POST['db_user'] ?? '') ?>" required></label>
      <label class="f full">Database password<input class="input" type="password" name="db_pass"></label>
      <div class="divider full"></div>
      <label class="f">Admin name<input class="input" name="admin_name" value="<?= htmlspecialchars($_POST['admin_name'] ?? '') ?>"></label>
      <label class="f">Admin email<input class="input" type="email" name="admin_email" value="<?= htmlspecialchars($_POST['admin_email'] ?? '') ?>" required></label>
      <label class="f full">Admin password<input class="input" type="password" name="admin_password" minlength="8" required></label>
      <div class="full row end"><button class="btn">Install</button></div>
    </form>
  <?php endif; ?>
  </div>
</div>
</body></html>
