<?php
require __DIR__ . '/_init.php';
require_admin();
Matching::tick();

$today = DB::row("SELECT COUNT(*) n, COALESCE(SUM(status='delivered'),0) delivered, COALESCE(SUM(CASE WHEN status <> 'cancelled' THEN fee_kobo END),0) gmv,
    COALESCE(SUM(CASE WHEN status='delivered' THEN commission_kobo END),0) commission FROM orders WHERE DATE(created_at) = CURDATE()");
$yday = DB::row("SELECT COUNT(*) n FROM orders WHERE DATE(created_at) = CURDATE() - INTERVAL 1 DAY");
$active = (int) DB::value("SELECT COUNT(*) FROM orders WHERE status IN ('matched','picked_up','en_route','arrived')");
$pending = (int) DB::value("SELECT COUNT(*) FROM orders WHERE status = 'pending'");
$ridersOnline = (int) DB::value("SELECT COUNT(*) FROM riders WHERE is_online = 1 AND location_updated_at > NOW() - INTERVAL 10 MINUTE");
$ridersTotal = (int) DB::value("SELECT COUNT(*) FROM riders WHERE status = 'active'");
$avgMatch = DB::value("SELECT AVG(TIMESTAMPDIFF(SECOND, created_at, matched_at)) FROM orders WHERE matched_at IS NOT NULL AND created_at > NOW() - INTERVAL 7 DAY");
$platform = Wallet::balance('platform', 0);
$c = nav_counts();

$days = [];
foreach (DB::all("SELECT DATE(created_at) d, COUNT(*) n, SUM(status='delivered') del FROM orders WHERE created_at >= CURDATE() - INTERVAL 13 DAY GROUP BY DATE(created_at)") as $r) $days[$r['d']] = $r;
$max = 1;
$series = [];
for ($i = 13; $i >= 0; $i--) {
    $d = date('Y-m-d', strtotime("-$i day"));
    $n = (int) ($days[$d]['n'] ?? 0);
    $series[] = [$d, $n, (int) ($days[$d]['del'] ?? 0)];
    $max = max($max, $n);
}
$recent = DB::all('SELECT o.*, r.first_name rf, r.last_name rl FROM orders o LEFT JOIN riders r ON r.id = o.rider_id ORDER BY o.id DESC LIMIT 8');
$byStatus = [];
foreach (DB::all("SELECT status, COUNT(*) n FROM orders WHERE created_at > NOW() - INTERVAL 30 DAY GROUP BY status") as $r) $byStatus[$r['status']] = (int) $r['n'];
$delta = $yday['n'] ? round(($today['n'] - $yday['n']) / $yday['n'] * 100) : null;

layout_start('Dashboard', 'dashboard', 'Good ' . (date('G') < 12 ? 'morning' : (date('G') < 17 ? 'afternoon' : 'evening')) . ', ' . e(explode(' ', admin()['name'])[0]) . '. Here\'s what\'s moving right now.',
    '<a class="btn" href="order_new.php">' . icon('plus') . ' New delivery</a>');
?>
<?php if ($c['sos']): ?><a class="flash err" href="sos.php"><?= icon('alert') ?><span><b><?= $c['sos'] ?> open SOS alert<?= $c['sos'] > 1 ? 's' : '' ?></b> — review now.</span></a><?php endif; ?>

<div class="grid g4">
  <div class="card stat dark"><span class="ico" style="background:#34A85333;color:#6BD187"><?= icon('box') ?></span><span class="k">Deliveries today</span><span class="v"><?= number_format((int) $today['n']) ?></span>
    <span class="d"><?= $delta === null ? 'No data for yesterday' : (($delta >= 0 ? '▲ ' : '▼ ') . abs($delta) . '% vs yesterday') ?></span></div>
  <div class="card stat"><span class="ico"><?= icon('activity') ?></span><span class="k">Active now</span><span class="v"><?= $active ?></span><span class="d"><?= $pending ?> waiting for a rider</span></div>
  <div class="card stat"><span class="ico"><?= icon('bike') ?></span><span class="k">Riders online</span><span class="v"><?= $ridersOnline ?></span><span class="d">of <?= $ridersTotal ?> active riders<?= $avgMatch ? ' · avg match ' . (int) $avgMatch . 's' : '' ?></span></div>
  <div class="card stat"><span class="ico"><?= icon('wallet') ?></span><span class="k">Revenue today</span><span class="v"><?= naira($today['commission'], false) ?></span><span class="d">GMV <?= naira($today['gmv'], false) ?> · platform <?= naira($platform, false) ?></span></div>
</div>

<div class="grid g-main">
  <div class="card">
    <div class="card-h"><h2>Live operations</h2><span class="badge b-online">Auto-refresh</span><a class="btn ghost sm" href="live.php">Full map</a></div>
    <div class="card-b" style="padding:12px"><div id="map" class="map"></div></div>
  </div>
  <div class="stack" style="gap:20px">
    <div class="card">
      <div class="card-h"><h3>Needs attention</h3></div>
      <div class="card-b stack" style="gap:10px">
        <?php
        $todo = [
            ['orders.php?status=pending', 'box', "$pending orders waiting for a rider", $pending],
            ['topups.php', 'down', "{$c['topups']} top-ups to confirm", $c['topups']],
            ['withdrawals.php', 'up', "{$c['withdrawals']} withdrawals to pay", $c['withdrawals']],
            ['verifications.php', 'filecheck', "{$c['kyc']} verifications to review", $c['kyc']],
            ['sos.php', 'alert', "{$c['sos']} SOS alerts open", $c['sos']],
        ];
        $any = false;
        foreach ($todo as [$href, $ic, $label, $n]) if ($n) { $any = true; ?>
          <a href="<?= $href ?>" class="row" style="padding:10px 12px;border-radius:12px;background:var(--surface-2)"><span class="av" style="width:30px;height:30px;border-radius:10px"><?= str_replace('<svg', '<svg width="15" height="15"', icon($ic)) ?></span><span style="flex:1;font-weight:500"><?= e($label) ?></span><span class="muted">→</span></a>
        <?php }
        if (!$any): ?><div class="muted" style="padding:6px 2px">All clear. Nothing waiting on you.</div><?php endif; ?>
      </div>
    </div>
    <div class="card">
      <div class="card-h"><h3>Deliveries · last 14 days</h3><div class="legend"><span><i></i>Created</span></div></div>
      <div class="card-b">
        <div class="bars">
          <?php foreach ($series as [$d, $n, $del]): ?>
            <div class="bar" title="<?= date('D j M', strtotime($d)) ?>: <?= $n ?> created, <?= $del ?> delivered"><i style="height:<?= max(2, round($n / $max * 100)) ?>%" class="<?= $n ? '' : 'c' ?>"></i><span><?= date('j', strtotime($d)) ?></span></div>
          <?php endforeach; ?>
        </div>
      </div>
    </div>
  </div>
</div>

<div class="card">
  <div class="card-h"><h2>Recent deliveries</h2>
    <div class="chips"><?php foreach (['pending', 'en_route', 'delivered', 'cancelled'] as $s): ?><a class="chip" href="orders.php?status=<?= $s ?>"><?= e(Orders::LABELS[$s]) ?><span class="n"><?= $byStatus[$s] ?? 0 ?></span></a><?php endforeach; ?></div>
    <a class="btn ghost sm" href="orders.php">See all</a></div>
  <div class="table-wrap">
    <table class="t">
      <thead><tr><th>Track ID</th><th>Route</th><th>Status</th><th>Rider</th><th class="right">Fee</th><th>Created</th></tr></thead>
      <tbody>
      <?php foreach ($recent as $o): ?>
        <tr class="link" data-href="order.php?id=<?= $o['id'] ?>">
          <td><?= tid($o['track_id']) ?><div class="sub"><?= e($o['order_no']) ?></div></td>
          <td><div class="strong"><?= e(Orders::shortRoute($o)) ?></div><div class="sub"><?= e($o['recipient_name']) ?></div></td>
          <td><?= badge($o['status']) ?></td>
          <td><?= $o['rf'] ? e($o['rf'] . ' ' . $o['rl']) : '<span class="faint">—</span>' ?></td>
          <td class="right strong"><?= naira($o['fee_kobo'], false) ?></td>
          <td class="muted nowrap"><?= time_ago($o['created_at']) ?></td>
        </tr>
      <?php endforeach; ?>
      <?php if (!$recent): ?><tr><td colspan="6"><div class="empty"><?= icon('box') ?><div>No deliveries yet. <a class="green" href="order_new.php">Create the first one</a>.</div></div></td></tr><?php endif; ?>
      </tbody>
    </table>
  </div>
</div>
<?php
$center = DB::row('SELECT center_lat, center_lng FROM zones WHERE is_live = 1 ORDER BY id LIMIT 1') ?: ['center_lat' => 6.335, 'center_lng' => 5.6037];
layout_end('<script>window.LIVE_CENTER=[' . (float) $center['center_lat'] . ',' . (float) $center['center_lng'] . '];</script><script src="../assets/js/live.js?v=3"></script>');
