<?php
/**
 * Background jobs. cPanel → Cron Jobs (every minute):
 *   * * * * * php /home/USER/public_html/cron/run.php >/dev/null 2>&1
 * Or by URL: https://dyspatch.bitprofil.com/cron/run.php?key=CRON_KEY
 */
require dirname(__DIR__) . '/includes/bootstrap.php';
if (PHP_SAPI !== 'cli' && !hash_equals((string) config('cron_key'), (string) ($_GET['key'] ?? ''))) { http_response_code(403); exit('Forbidden'); }
@set_time_limit(55);
$lock = fopen(BASE_PATH . '/storage/cache/cron.lock', 'c');
if (!flock($lock, LOCK_EX | LOCK_NB)) exit("Already running\n");

$out = [];
$started = time();
// 1) Matching engine: expire stale offers and re-offer. Run repeatedly within the minute so the 45s accept window is honoured.
do {
    $r = Matching::tick();
    if ($r['expired'] || $r['offered']) $out[] = "match: expired {$r['expired']}, offered {$r['offered']}";
    sleep(10);
} while (PHP_SAPI === 'cli' && time() - $started < 45);

// 2) Riders who stopped sending location are taken offline.
$n = DB::query("UPDATE riders SET is_online = 0 WHERE is_online = 1 AND (location_updated_at IS NULL OR location_updated_at < NOW() - INTERVAL 15 MINUTE)")->rowCount();
if ($n) $out[] = "offline: $n";

// 3) Orders nobody accepted for 20 minutes → alert ops once.
foreach (DB::all("SELECT o.* FROM orders o WHERE o.status = 'pending' AND o.created_at < NOW() - INTERVAL 20 MINUTE AND o.created_at > NOW() - INTERVAL 21 MINUTE") as $o) {
    Notifier::adminAlert("No rider for {$o['track_id']}", '<p>Order <b>' . e($o['track_id']) . '</b> has waited 20 minutes without a rider. Assign one manually.</p>', app_url('admin/order.php?id=' . $o['id']));
}

// 4) Housekeeping (once an hour).
if ((int) date('i') === 0) {
    DB::query('DELETE FROM otps WHERE created_at < NOW() - INTERVAL 2 DAY');
    DB::query('DELETE FROM api_tokens WHERE expires_at < NOW()');
    DB::query('DELETE FROM rider_locations WHERE order_id IS NULL AND created_at < NOW() - INTERVAL 7 DAY');
}
flock($lock, LOCK_UN);
echo ($out ? implode("\n", $out) : 'ok') . "\n";
