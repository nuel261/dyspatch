<?php
require __DIR__ . '/_init.php';
$admin = require_admin();

handle_post(function ($in) use ($admin) {
    $id = (int) ($in['id'] ?? 0);
    $s = DB::row('SELECT * FROM sos_alerts WHERE id = ?', [$id]);
    if (!$s) throw new ApiException('Alert not found');
    if (($in['action'] ?? '') === 'ack') {
        DB::update('sos_alerts', ['status' => 'acknowledged', 'admin_id' => $admin['id']], 'id = ?', [$id]);
        if ($s['user_id']) Notifier::notify('user', (int) $s['user_id'], 'system', 'We received your SOS', 'Our safety team is on it and will contact you shortly.', ['type' => 'sos'], ['send' => false]);
        if ($s['order_id']) Orders::event((int) $s['order_id'], null, 'sos_ack', 'SOS acknowledged', 'Safety team responding', 'admin', (int) $admin['id']);
        audit((int) $admin['id'], 'sos.ack', 'sos', $id);
        return 'Alert acknowledged — the customer has been notified.';
    }
    if (($in['action'] ?? '') === 'resolve') {
        $note = trim((string) ($in['note'] ?? '')) ?: 'Resolved';
        DB::update('sos_alerts', ['status' => 'resolved', 'admin_id' => $admin['id'], 'resolution_note' => $note, 'resolved_at' => now()], 'id = ?', [$id]);
        if ($s['order_id']) Orders::event((int) $s['order_id'], null, 'sos_resolved', 'SOS resolved', $note, 'admin', (int) $admin['id']);
        audit((int) $admin['id'], 'sos.resolve', 'sos', $id, $note);
        return 'Alert resolved.';
    }
    return null;
});

$f = $_GET['f'] ?? 'open';
$where = $f === 'all' ? '1=1' : ($f === 'resolved' ? "s.status = 'resolved'" : "s.status <> 'resolved'");
$rows = DB::all("SELECT s.*, o.track_id, o.status ostatus, o.rider_id orid, u.first_name uf, u.last_name ul, u.phone up,
    r.first_name rf, r.last_name rl, r.phone rp, r.lat rlat, r.lng rlng, a.name admin_name
    FROM sos_alerts s LEFT JOIN orders o ON o.id = s.order_id LEFT JOIN users u ON u.id = s.user_id
    LEFT JOIN riders r ON r.id = COALESCE(s.rider_id, o.rider_id) LEFT JOIN admins a ON a.id = s.admin_id
    WHERE $where ORDER BY FIELD(s.status,'open','acknowledged','resolved'), s.id DESC LIMIT 100");
$pts = array_values(array_filter(array_map(fn($s) => ($s['lat'] ?? $s['rlat']) !== null ? ['id' => (int) $s['id'], 'lat' => (float) ($s['lat'] ?? $s['rlat']), 'lng' => (float) ($s['lng'] ?? $s['rlng']), 'open' => $s['status'] !== 'resolved', 'label' => $s['track_id'] ?: 'SOS #' . $s['id']] : null, $rows)));

layout_start('SOS alerts', 'sos', 'Safety concerns raised by customers and riders. Respond to open alerts first.');
?>
<div class="chips"><?php foreach (['open' => 'Open', 'resolved' => 'Resolved', 'all' => 'All'] as $k => $l): ?><a class="chip <?= $f === $k ? 'on' : '' ?>" href="?f=<?= $k ?>"><?= $l ?></a><?php endforeach; ?></div>
<?php if ($pts): ?><div class="card"><div id="sosmap" class="map short"></div></div><?php endif; ?>
<div class="stack" style="gap:14px">
<?php foreach ($rows as $s): $who = $s['user_id'] ? trim($s['uf'] . ' ' . $s['ul']) . ' (customer)' : trim($s['rf'] . ' ' . $s['rl']) . ' (rider)'; ?>
  <div class="card" style="<?= $s['status'] === 'open' ? 'border-color:#EA433566' : '' ?>">
    <div class="card-h">
      <span class="badge b-<?= $s['status'] ?>"><?= ucfirst($s['status']) ?></span>
      <h3><?= e($s['message'] ?: 'Safety concern') ?></h3>
      <span class="muted small"><?= time_ago($s['created_at']) ?> · <?= date('j M, H:i', strtotime($s['created_at'])) ?></span>
    </div>
    <div class="card-b grid g3">
      <dl class="kv" style="grid-template-columns:80px 1fr"><dt>Raised by</dt><dd><?= e($who) ?></dd><dt>Phone</dt><dd><?php $ph = $s['user_id'] ? $s['up'] : $s['rp']; ?><?= $ph ? '<a class="green" href="tel:' . e($ph) . '">' . e($ph) . '</a>' : '—' ?></dd></dl>
      <dl class="kv" style="grid-template-columns:80px 1fr"><dt>Order</dt><dd><?= $s['order_id'] ? '<a href="order.php?id=' . $s['order_id'] . '">' . tid((string) $s['track_id']) . '</a> ' . badge($s['ostatus']) : '—' ?></dd>
        <dt>Rider</dt><dd><?= $s['rf'] ? e(trim($s['rf'] . ' ' . $s['rl'])) . ' · <a class="green" href="tel:' . e($s['rp']) . '">' . e($s['rp']) . '</a>' : '—' ?></dd></dl>
      <div><?php if ($s['status'] === 'resolved'): ?><div class="callout"><b><?= e($s['admin_name'] ?: 'Admin') ?>:</b> <?= e($s['resolution_note']) ?></div>
      <?php else: ?><form method="post" class="stack" style="gap:8px"><?= csrf_field() ?><input type="hidden" name="id" value="<?= $s['id'] ?>">
        <?php if ($s['status'] === 'open'): ?><button class="btn danger" name="action" value="ack">Acknowledge & respond</button><?php endif; ?>
        <div class="row" style="gap:6px"><input class="input" name="note" placeholder="Resolution note" style="flex:1"><button class="btn ghost sm" name="action" value="resolve">Resolve</button></div>
      </form><?php endif; ?></div>
    </div>
  </div>
<?php endforeach; ?>
<?php if (!$rows): ?><div class="card"><div class="empty"><?= icon('shield') ?><div>No alerts. All clear.</div></div></div><?php endif; ?>
</div>
<?php
$json = json_encode($pts);
layout_end($pts ? "<script>const m=DMap.create('sosmap');const pts=$json;const b=[];pts.forEach(p=>{b.push([p.lat,p.lng]);L.circleMarker([p.lat,p.lng],{radius:10,color:p.open?'#EA4335':'#A0A4AB',fillOpacity:.6}).addTo(m).bindPopup(esc(p.label));});if(b.length)m.fitBounds(b,{maxZoom:14,padding:[30,30]});</script>" : '');
