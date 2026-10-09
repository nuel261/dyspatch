<?php
/** Broadcast announcements: in-app + push, optionally email. */
require __DIR__ . '/_init.php';
$admin = require_admin(['super', 'ops']);

handle_post(function ($in) use ($admin) {
    $title = trim((string) ($in['title'] ?? ''));
    $body = trim((string) ($in['body'] ?? ''));
    if ($title === '' || $body === '') throw new ApiException('Title and message are required');
    $aud = $in['audience'] ?? 'customers';
    $email = !empty($in['email']);
    $targets = match ($aud) {
        'riders' => DB::all("SELECT id, 'rider' t FROM riders WHERE status = 'active'"),
        'riders_online' => DB::all("SELECT id, 'rider' t FROM riders WHERE status = 'active' AND is_online = 1"),
        'riders_pending' => DB::all("SELECT id, 'rider' t FROM riders WHERE kyc_status IN ('none','rejected') AND status <> 'suspended'"),
        'customers_active' => DB::all("SELECT DISTINCT u.id, 'user' t FROM users u JOIN orders o ON o.user_id = u.id WHERE u.status = 'active' AND o.created_at > NOW() - INTERVAL 30 DAY"),
        'test' => [['id' => 0, 't' => 'test']],
        default => DB::all("SELECT id, 'user' t FROM users WHERE status = 'active'"),
    };
    if ($aud === 'test') {
        $to = (string) Settings::get('admin_alert_email') ?: $admin['email'];
        $ok = Mailer::send($to, $title, Mailer::template($title, nl2br(e($body))));
        return $ok ? "Test email sent to $to." : 'Test email failed — check Settings → Email and storage/logs/mail-*.log';
    }
    @set_time_limit(0);
    $n = 0;
    foreach ($targets as $t) {
        Notifier::notify($t['t'], (int) $t['id'], 'system', $title, $body, ['type' => 'broadcast'], ['send' => $email]);
        $n++;
    }
    audit((int) $admin['id'], 'broadcast', null, null, "$aud · $n · $title");
    return "Sent to $n recipient" . ($n === 1 ? '' : 's') . '.';
});

$counts = [
    'customers' => (int) DB::value("SELECT COUNT(*) FROM users WHERE status = 'active'"),
    'customers_active' => (int) DB::value("SELECT COUNT(DISTINCT user_id) FROM orders WHERE created_at > NOW() - INTERVAL 30 DAY"),
    'riders' => (int) DB::value("SELECT COUNT(*) FROM riders WHERE status = 'active'"),
    'riders_online' => (int) DB::value("SELECT COUNT(*) FROM riders WHERE status = 'active' AND is_online = 1"),
    'riders_pending' => (int) DB::value("SELECT COUNT(*) FROM riders WHERE kyc_status IN ('none','rejected') AND status <> 'suspended'"),
];
$devices = DB::row("SELECT SUM(owner_type='user') u, SUM(owner_type='rider') r FROM device_tokens");
$recent = DB::all("SELECT l.*, a.name FROM audit_logs l LEFT JOIN admins a ON a.id = l.admin_id WHERE l.action = 'broadcast' ORDER BY l.id DESC LIMIT 10");

layout_start('Broadcast', 'notify', 'Send an announcement to customers or riders as an in-app notification and push, with optional email.');
?>
<?php if (!Push::enabled()): ?><div class="flash warn"><?= icon('alert') ?><span>Push notifications are not configured yet — messages will still appear in the app's notification list. Add your Firebase service account in <a href="settings.php#push" style="text-decoration:underline">Settings → Push</a>.</span></div><?php endif; ?>
<div class="grid g-main">
  <form method="post" class="card" data-confirm="Send this announcement now?"><?= csrf_field() ?>
    <div class="card-h"><h2>New announcement</h2></div>
    <div class="card-b stack">
      <label class="f">Audience<select class="input" name="audience">
        <option value="customers">All customers (<?= $counts['customers'] ?>)</option>
        <option value="customers_active">Customers active in last 30 days (<?= $counts['customers_active'] ?>)</option>
        <option value="riders">All active riders (<?= $counts['riders'] ?>)</option>
        <option value="riders_online">Riders online now (<?= $counts['riders_online'] ?>)</option>
        <option value="riders_pending">Riders yet to verify (<?= $counts['riders_pending'] ?>)</option>
        <option value="test">Test — email me only</option>
      </select></label>
      <label class="f">Title<input class="input" name="title" maxlength="120" required placeholder="e.g. We're live in Lekki!"></label>
      <label class="f">Message<textarea class="input" name="body" maxlength="255" required placeholder="Keep it short — this is what shows on the lock screen."></textarea></label>
      <label class="switch"><input type="checkbox" name="email" value="1"> Also send by email (to recipients with an email address)</label>
      <div class="row end"><button class="btn"><?= icon('bell') ?> Send</button></div>
    </div>
  </form>
  <div class="stack" style="gap:20px">
    <div class="card"><div class="card-h"><h3>Reach</h3></div><div class="card-b"><dl class="kv">
      <dt>Push devices</dt><dd><?= (int) $devices['u'] ?> customer · <?= (int) $devices['r'] ?> rider</dd>
      <dt>Push</dt><dd><?= Push::enabled() ? badge('active', 'Configured') : badge('none', 'Not configured') ?></dd>
      <dt>Email</dt><dd><?= Mailer::enabled() ? badge('active', Settings::get('smtp_host') ? 'SMTP ' . Settings::get('smtp_host') : 'PHP mail()') : badge('none', 'Disabled') ?></dd>
    </dl></div></div>
    <div class="card"><div class="card-h"><h3>Recent broadcasts</h3></div><div class="table-wrap"><table class="t"><tbody>
      <?php foreach ($recent as $r): ?><tr><td class="small"><?= e($r['details']) ?><div class="sub"><?= e($r['name']) ?> · <?= time_ago($r['created_at']) ?></div></td></tr><?php endforeach; ?>
      <?php if (!$recent): ?><tr><td><div class="empty">Nothing sent yet.</div></td></tr><?php endif; ?>
    </tbody></table></div></div>
  </div>
</div>
<?php layout_end();
