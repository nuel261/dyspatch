<?php
require __DIR__ . '/_init.php';
$admin = require_admin();
$id = (int) ($_GET['id'] ?? 0);
$o = Orders::find($id);
if (!$o) { flash('Order not found', 'err'); redirect('orders.php'); }

if (($_GET['data'] ?? '') === '1') {
    header('Content-Type: application/json');
    $r = Orders::riderPublic($o['rider_id'] ? (int) $o['rider_id'] : null);
    echo json_encode(['status' => $o['status'], 'rider' => $r ? [$r['lat'], $r['lng']] : null, 'seen' => $r['location_updated_at'] ?? null, 'trail' => Orders::trail($id), 'eta' => Orders::liveEta($o, $r)]);
    exit;
}

handle_post(function ($in) use ($o, $admin) {
    $aid = (int) $admin['id'];
    switch ($in['action'] ?? '') {
        case 'assign':
            Orders::assignRider((int) $o['id'], (int) $in['rider_id'], 'admin', $aid);
            audit($aid, 'order.assign', 'order', (int) $o['id'], 'rider ' . $in['rider_id']);
            return 'Rider assigned';
        case 'unassign':
            Orders::setStatus((int) $o['id'], 'pending', 'admin', $aid, 'Rider unassigned by dispatch', true);
            Matching::dispatch((int) $o['id']);
            audit($aid, 'order.unassign', 'order', (int) $o['id']);
            return 'Rider removed — order is back in the matching queue';
        case 'redispatch':
            DB::query("DELETE FROM order_offers WHERE order_id = ? AND status IN ('expired','declined','withdrawn')", [$o['id']]);
            $f = Matching::dispatch((int) $o['id']);
            return $f ? 'Offered to the nearest available rider' : 'No eligible riders within the matching radius right now';
        case 'status':
            $force = !empty($in['force']);
            Orders::setStatus((int) $o['id'], (string) $in['status'], 'admin', $aid, trim((string) ($in['note'] ?? '')) ?: null, $force);
            audit($aid, 'order.status', 'order', (int) $o['id'], $in['status'] . ($force ? ' (forced)' : ''));
            return 'Status updated to ' . (Orders::LABELS[$in['status']] ?? $in['status']);
        case 'item_status':
            $item = DB::row('SELECT * FROM order_items WHERE id = ? AND order_id = ?', [(int) $in['item_id'], $o['id']]);
            if (!$item) throw new ApiException('Item not found');
            Orders::setItemStatus((int) $item['id'], (string) $in['status'], 'admin', $aid, trim((string) ($in['note'] ?? '')) ?: null);
            audit($aid, 'item.status', 'order', (int) $o['id'], $item['item_code'] . ' → ' . $in['status']);
            return $item['item_code'] . ' updated';
        case 'add_item':
            $n = (int) DB::value('SELECT COUNT(*) FROM order_items WHERE order_id = ?', [$o['id']]) + 1;
            $code = $o['track_id'] . '-' . str_pad((string) $n, 2, '0', STR_PAD_LEFT);
            while (DB::value('SELECT 1 FROM order_items WHERE item_code = ?', [$code])) $code = $o['track_id'] . '-' . str_pad((string) ++$n, 2, '0', STR_PAD_LEFT);
            $iid = DB::insert('order_items', ['order_id' => $o['id'], 'item_code' => $code, 'description' => mb_substr(trim((string) $in['description']), 0, 255) ?: 'Item',
                'quantity' => max(1, (int) ($in['quantity'] ?? 1)), 'weight_kg' => ($in['weight_kg'] ?? '') !== '' ? (float) $in['weight_kg'] : null]);
            Orders::event((int) $o['id'], $iid, 'item_added', "$code · Item added", null, 'admin', $aid);
            return "Item $code added";
        case 'note':
            $title = trim((string) ($in['title'] ?? '')) ?: 'Update';
            Orders::event((int) $o['id'], ($in['item_id'] ?? '') !== '' ? (int) $in['item_id'] : null, 'note', mb_substr($title, 0, 120), trim((string) ($in['note'] ?? '')) ?: null, 'admin', $aid,
                ($in['lat'] ?? '') !== '' ? (float) $in['lat'] : null, ($in['lng'] ?? '') !== '' ? (float) $in['lng'] : null);
            if (!empty($in['notify']) && $o['user_id']) {
                Notifier::notify('user', (int) $o['user_id'], 'delivery', $title . ' · ' . $o['track_id'], trim((string) ($in['note'] ?? '')) ?: $title,
                    ['type' => 'order', 'order_id' => (string) $o['id'], 'track_id' => $o['track_id']], ['cta_label' => 'Track package', 'cta_url' => app_url('track?id=' . $o['track_id'])]);
            }
            return 'Tracking update added';
        case 'regen':
            Orders::regenerateDeliveryCode((int) $o['id']);
            audit($aid, 'order.regen_code', 'order', (int) $o['id']);
            return 'New delivery code sent to the recipient';
        case 'recipient':
            DB::update('orders', ['recipient_name' => trim((string) $in['recipient_name']), 'recipient_phone' => normalize_phone((string) $in['recipient_phone'])], 'id = ?', [$o['id']]);
            Orders::event((int) $o['id'], null, 'note', 'Recipient details updated', null, 'admin', $aid);
            return 'Recipient updated';
        case 'mark_paid':
            DB::update('orders', ['payment_status' => 'paid'], 'id = ?', [$o['id']]);
            audit($aid, 'order.mark_paid', 'order', (int) $o['id']);
            return 'Marked as paid';
    }
    return null;
});

$o = Orders::find($id);
$items = DB::all('SELECT * FROM order_items WHERE order_id = ? ORDER BY id', [$id]);
$events = DB::all('SELECT e.*, i.item_code FROM tracking_events e LEFT JOIN order_items i ON i.id = e.item_id WHERE e.order_id = ? ORDER BY e.created_at DESC, e.id DESC', [$id]);
$rider = $o['rider_id'] ? DB::row('SELECT * FROM riders WHERE id = ?', [$o['rider_id']]) : null;
$user = $o['user_id'] ? DB::row('SELECT * FROM users WHERE id = ?', [$o['user_id']]) : null;
$zone = $o['zone_id'] ? DB::row('SELECT * FROM zones WHERE id = ?', [$o['zone_id']]) : null;
$offers = DB::all('SELECT f.*, r.first_name, r.last_name FROM order_offers f JOIN riders r ON r.id = f.rider_id WHERE f.order_id = ? ORDER BY f.id DESC LIMIT 10', [$id]);
$nearby = in_array($o['status'], ['pending', 'matched'], true) ? Matching::eligibleRiders($o, 8) : [];
$allRiders = in_array($o['status'], ['pending', 'matched'], true)
    ? DB::all("SELECT r.id, r.first_name, r.last_name, r.plate, r.is_online FROM riders r WHERE r.status = 'active' AND NOT EXISTS (SELECT 1 FROM orders x WHERE x.rider_id = r.id AND x.status IN ('matched','picked_up','en_route','arrived')) ORDER BY r.is_online DESC, r.first_name LIMIT 300")
    : [];
$isActive = in_array($o['status'], Orders::ACTIVE, true);
$done = in_array($o['status'], ['delivered', 'cancelled', 'failed'], true);
$flow = ['pending' => 0, 'matched' => 1, 'picked_up' => 2, 'en_route' => 3, 'arrived' => 4, 'delivered' => 5];
$stepIdx = $flow[$o['status']] ?? -1;
$publicUrl = app_url('track?id=' . urlencode($o['track_id']));

layout_start($o['track_id'], 'orders', e($o['order_no']) . ' · ' . e($zone['name'] ?? 'No zone') . ' · created ' . date('j M Y, H:i', strtotime($o['created_at'])) . ' via ' . e($o['channel']),
    '<a class="btn ghost sm" target="_blank" href="' . e($publicUrl) . '">' . icon('link') . ' Public page</a><a class="btn ghost sm" target="_blank" href="label.php?id=' . $id . '">Print labels</a>', true);
?>
<div class="card card-b stack" style="gap:16px">
  <div class="row between">
    <div class="row"><?= badge($o['status']) ?> <?= tid($o['track_id']) ?>
      <?php if ($isActive && $rider): ?><span class="muted small" id="etaText"></span><?php endif; ?></div>
    <div class="row small muted"><?= e(ucfirst($o['payment_method'])) ?> · <?= badge($o['payment_status'] === 'paid' ? 'paid' : ($o['payment_status'] === 'refunded' ? 'info' : 'pending'), ucfirst($o['payment_status'])) ?></div>
  </div>
  <?php if (in_array($o['status'], ['cancelled', 'failed'], true)): ?>
    <div class="flash err"><?= icon('alert') ?><span><?= e(Orders::LABELS[$o['status']]) ?><?= $o['cancel_reason'] ? ': ' . e($o['cancel_reason']) : '' ?></span></div>
  <?php else: ?>
    <div class="steps"><?php foreach (['Created', 'Rider assigned', 'Picked up', 'In transit', 'Arrived', 'Delivered'] as $i => $l): ?><div class="<?= $i <= $stepIdx ? 'on' : '' ?>"><?= e($l) ?></div><?php endforeach; ?></div>
  <?php endif; ?>
</div>

<div class="grid g-main">
  <div class="stack" style="gap:20px">
    <div class="card" style="padding:10px"><div id="map" class="map"></div></div>

    <div class="card">
      <div class="card-h"><h2>Items</h2><span class="muted small"><?= count($items) ?> parcel<?= count($items) === 1 ? '' : 's' ?> · each has its own tracking code</span><button class="btn ghost sm" data-open="dlgItem"><?= icon('plus') ?> Add item</button></div>
      <div class="table-wrap"><table class="t">
        <thead><tr><th>Item code</th><th>Description</th><th>Qty</th><th>Status</th><th class="right">Update</th></tr></thead>
        <tbody>
        <?php foreach ($items as $it): ?>
          <tr id="item-<?= $it['id'] ?>">
            <td><?= tid($it['item_code']) ?></td>
            <td><div class="strong"><?= e($it['description']) ?></div><?php if ($it['weight_kg']): ?><div class="sub"><?= (float) $it['weight_kg'] ?> kg</div><?php endif; ?></td>
            <td><?= (int) $it['quantity'] ?></td>
            <td><?= badge($it['status']) ?><div class="sub"><?= time_ago($it['updated_at']) ?></div></td>
            <td class="right">
              <form method="post" class="row end" style="gap:6px"><?= csrf_field() ?><input type="hidden" name="action" value="item_status"><input type="hidden" name="item_id" value="<?= $it['id'] ?>">
                <select class="input" name="status" style="width:auto;padding:6px 10px;font-size:12.5px"><?php foreach (Orders::ITEM_LABELS as $k => $l): ?><option value="<?= $k ?>" <?= $it['status'] === $k ? 'selected' : '' ?>><?= e($l) ?></option><?php endforeach; ?></select>
                <button class="btn sm soft">Save</button></form>
            </td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table></div>
    </div>

    <div class="card">
      <div class="card-h"><h2>Tracking history</h2><button class="btn ghost sm" data-open="dlgNote"><?= icon('plus') ?> Add update</button></div>
      <div class="card-b">
        <ul class="timeline">
          <?php foreach ($events as $i => $ev):
              $bad = in_array($ev['status'], ['cancelled', 'failed', 'sos', 'item_lost', 'item_damaged', 'item_returned'], true);
              $cls = $ev['item_id'] ? 'item done' : ($bad ? 'bad' : ($i === 0 && !$done ? 'current' : 'done')); ?>
            <li class="<?= $cls ?>"><span class="pt"></span>
              <div class="tl-h"><span><?= e($ev['title']) ?></span><time title="<?= e($ev['created_at']) ?>"><?= date('j M, H:i', strtotime($ev['created_at'])) ?></time></div>
              <div class="tl-n"><?= $ev['note'] ? e($ev['note']) . ' · ' : '' ?>by <?= e($ev['actor_type']) ?><?php if ($ev['lat']): ?> · <span class="mono"><?= round((float) $ev['lat'], 4) ?>, <?= round((float) $ev['lng'], 4) ?></span><?php endif; ?></div>
            </li>
          <?php endforeach; ?>
        </ul>
      </div>
    </div>
  </div>

  <div class="stack" style="gap:20px">
    <div class="card">
      <div class="card-h"><h3>Rider</h3><?php if ($rider): ?><a class="btn ghost sm" href="rider.php?id=<?= $rider['id'] ?>">Profile</a><?php endif; ?></div>
      <div class="card-b stack">
        <?php if ($rider): ?>
          <div class="who"><?= avatar($rider['first_name'] . ' ' . $rider['last_name'], $rider['photo']) ?><div><div class="strong"><?= e($rider['first_name'] . ' ' . $rider['last_name']) ?></div><div class="muted small"><?= e(ucfirst($rider['vehicle_type'])) ?> · <?= e($rider['plate'] ?: 'No plate') ?> · ★ <?= number_format((float) $rider['rating'], 1) ?></div></div></div>
          <div class="row"><a class="btn ghost sm" href="tel:<?= e($rider['phone']) ?>"><?= icon('phone') ?> <?= e($rider['phone']) ?></a><span class="muted small">Last seen <?= time_ago($rider['location_updated_at']) ?></span></div>
          <?php if ($o['status'] === 'matched'): ?>
            <form method="post" data-confirm="Remove this rider and send the order back to matching?"><?= csrf_field() ?><input type="hidden" name="action" value="unassign"><button class="btn danger ghost sm">Unassign rider</button></form>
          <?php endif; ?>
        <?php else: ?>
          <p class="muted"><?= $o['status'] === 'pending' ? 'Searching for a rider within ' . Settings::float('matching_radius_km', 5) . ' km of pickup.' : 'No rider was assigned.' ?></p>
        <?php endif; ?>
        <?php if ($allRiders): ?>
          <div class="divider"></div>
          <?php if ($nearby): ?><p class="small muted">Nearest available: <?= implode(', ', array_map(fn($r) => e($r['first_name']) . ' (' . round($r['distance_km'], 1) . ' km)', $nearby)) ?></p><?php endif; ?>
          <form method="post" class="stack" style="gap:8px"><?= csrf_field() ?><input type="hidden" name="action" value="assign">
            <select class="input" name="rider_id" required><option value="">Assign a rider manually…</option>
              <?php foreach ($allRiders as $r): ?><option value="<?= $r['id'] ?>"><?= e($r['first_name'] . ' ' . $r['last_name']) ?><?= $r['plate'] ? ' · ' . e($r['plate']) : '' ?><?= $r['is_online'] ? ' · online' : ' · offline' ?></option><?php endforeach; ?></select>
            <div class="row"><button class="btn sm"><?= $rider ? 'Reassign' : 'Assign' ?></button>
            <?php if ($o['status'] === 'pending'): ?></form><form method="post" style="display:inline"><?= csrf_field() ?><input type="hidden" name="action" value="redispatch"><button class="btn ghost sm">Auto-match now</button><?php endif; ?></div>
          </form>
        <?php endif; ?>
        <?php if ($offers): ?>
          <details><summary class="small muted" style="cursor:pointer">Offer history (<?= count($offers) ?>)</summary>
            <div class="stack small" style="gap:6px;margin-top:8px"><?php foreach ($offers as $f): ?><div class="row between"><span><?= e($f['first_name'] . ' ' . $f['last_name']) ?> · <?= (float) $f['distance_km'] ?> km</span><?= badge($f['status'] === 'accepted' ? 'active' : ($f['status'] === 'offered' ? 'pending' : 'none'), ucfirst($f['status'])) ?></div><?php endforeach; ?></div></details>
        <?php endif; ?>
      </div>
    </div>

    <?php if (!$done): ?>
    <div class="card">
      <div class="card-h"><h3>Update status</h3></div>
      <div class="card-b">
        <form method="post" class="stack" style="gap:10px"><?= csrf_field() ?><input type="hidden" name="action" value="status">
          <select class="input" name="status"><?php foreach (Orders::LABELS as $k => $l): if ($k === $o['status']) continue; ?><option value="<?= $k ?>"><?= e($l) ?></option><?php endforeach; ?></select>
          <input class="input" name="note" placeholder="Note / reason (shown on timeline)">
          <label class="switch small"><input type="checkbox" name="force" value="1"> Override normal flow</label>
          <button class="btn">Update status</button>
        </form>
        <p class="faint small" style="margin-top:10px">Cancelling refunds wallet payments automatically. Delivering credits the rider's earnings and commission.</p>
      </div>
    </div>
    <?php endif; ?>

    <div class="card">
      <div class="card-h"><h3>Handover codes</h3></div>
      <div class="card-b stack">
        <div class="row between"><span class="muted">Pickup code</span><span class="code"><?= e($o['pickup_code']) ?></span></div>
        <div class="row between"><span class="muted">Delivery code</span><span class="code"><?= e($o['delivery_code']) ?></span></div>
        <p class="small muted">Attempts used: <?= (int) $o['delivery_code_attempts'] ?>/<?= Settings::int('otp_max_attempts', 3) ?><?= $o['delivery_code_expires_at'] ? ' · expires ' . date('H:i', strtotime($o['delivery_code_expires_at'])) : '' ?></p>
        <?php if ($isActive): ?><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="regen"><button class="btn ghost sm">Regenerate &amp; SMS recipient</button></form><?php endif; ?>
      </div>
    </div>

    <div class="card">
      <div class="card-h"><h3>Details</h3><?php if (!$done): ?><button class="btn ghost sm" data-open="dlgRecipient">Edit recipient</button><?php endif; ?></div>
      <div class="card-b stack" style="gap:16px">
        <div>
          <div class="addr"><span class="pin a"></span><div><div class="small muted">Pickup<?= $o['sender_name'] ? ' · ' . e($o['sender_name']) : '' ?></div><div class="strong"><?= e($o['pickup_address']) ?></div><?php if ($o['sender_phone']): ?><div class="small muted"><?= e($o['sender_phone']) ?></div><?php endif; ?></div></div>
          <div class="addr"><span class="line"></span></div>
          <div class="addr"><span class="pin b"></span><div><div class="small muted">Drop-off · <?= e($o['recipient_name']) ?></div><div class="strong"><?= e($o['dropoff_address']) ?></div><div class="small muted"><?= e($o['recipient_phone']) ?></div></div></div>
        </div>
        <div class="divider"></div>
        <dl class="kv">
          <dt>Customer</dt><dd><?= $user ? '<a class="green" href="customer.php?id=' . $user['id'] . '">' . e(trim($user['first_name'] . ' ' . $user['last_name']) ?: $user['phone']) . '</a>' : 'Walk-in / web' ?></dd>
          <dt>Package</dt><dd><?= e(ucfirst($o['package_type'])) ?><?= $o['package_description'] ? ' · ' . e($o['package_description']) : '' ?></dd>
          <dt>Delivery type</dt><dd><?= e(ucfirst($o['delivery_type'])) ?></dd>
          <dt>Distance</dt><dd><?= (float) $o['distance_km'] ?> km · est. <?= (int) $o['eta_minutes'] ?> min</dd>
          <dt>Fee</dt><dd class="strong"><?= naira($o['fee_kobo']) ?></dd>
          <dt>Commission</dt><dd><?= naira($o['commission_kobo']) ?> (<?= (float) $o['commission_pct'] ?>%)</dd>
          <dt>Rider earns</dt><dd><?= naira($o['rider_earning_kobo']) ?></dd>
          <?php if ($o['rider_rating']): ?><dt>Rating</dt><dd>★ <?= (int) $o['rider_rating'] ?>/5</dd><?php endif; ?>
          <?php if ($o['proof_photo']): ?><dt>Proof</dt><dd><a class="green" target="_blank" href="<?= e(public_file($o['proof_photo'])) ?>">View photo</a></dd><?php endif; ?>
        </dl>
        <?php if ($o['payment_status'] === 'unpaid' && $o['payment_method'] !== 'wallet'): ?>
          <form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="mark_paid"><button class="btn ghost sm">Mark as paid</button></form>
        <?php endif; ?>
      </div>
    </div>
  </div>
</div>

<dialog id="dlgItem"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="add_item">
  <div class="d-h"><h3>Add item</h3><button type="button" class="x" data-close>&times;</button></div>
  <div class="d-b"><label class="f">Description<input class="input" name="description" required placeholder="e.g. Blue carton, 2 phones"></label>
    <div class="form-grid"><label class="f">Quantity<input class="input" type="number" name="quantity" value="1" min="1"></label><label class="f">Weight (kg)<input class="input" type="number" step="0.1" name="weight_kg"></label></div></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Add item</button></div></form></dialog>

<dialog id="dlgNote"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="note">
  <div class="d-h"><h3>Add tracking update</h3><button type="button" class="x" data-close>&times;</button></div>
  <div class="d-b">
    <label class="f">Title<input class="input" name="title" required placeholder="e.g. Arrived at Ugbowo hub, Delayed by traffic"></label>
    <label class="f">Details <span class="hint">optional</span><textarea class="input" name="note"></textarea></label>
    <label class="f">Applies to<select class="input" name="item_id"><option value="">Whole order</option><?php foreach ($items as $it): ?><option value="<?= $it['id'] ?>"><?= e($it['item_code'] . ' · ' . $it['description']) ?></option><?php endforeach; ?></select></label>
    <label class="switch"><input type="checkbox" name="notify" value="1" checked> Notify customer (push + email)</label>
  </div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Add update</button></div></form></dialog>

<dialog id="dlgRecipient"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="recipient">
  <div class="d-h"><h3>Edit recipient</h3><button type="button" class="x" data-close>&times;</button></div>
  <div class="d-b"><label class="f">Name<input class="input" name="recipient_name" value="<?= e($o['recipient_name']) ?>" required></label><label class="f">Phone<input class="input" name="recipient_phone" value="<?= e($o['recipient_phone']) ?>" required></label></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Save</button></div></form></dialog>

<?php
$js = json_encode(['pickup' => [(float) $o['pickup_lat'], (float) $o['pickup_lng']], 'dropoff' => [(float) $o['dropoff_lat'], (float) $o['dropoff_lng']], 'active' => $isActive, 'id' => $id]);
layout_end(<<<HTML
<script>
(function(){
  const O = $js;
  const map = DMap.create('map', O.pickup, 13);
  L.marker(O.pickup, {icon: DMap.icon('pick')}).bindPopup('Pickup').addTo(map);
  L.marker(O.dropoff, {icon: DMap.icon('drop')}).bindPopup('Drop-off').addTo(map);
  L.polyline([O.pickup, O.dropoff], {color:'#34A853', weight:2, opacity:.5, dashArray:'6 6'}).addTo(map);
  map.fitBounds([O.pickup, O.dropoff], {padding:[50,50]});
  let rider, trail;
  async function refresh(){
    try {
      const d = await fetch('order.php?id=' + O.id + '&data=1', {credentials:'same-origin'}).then(r => r.json());
      if (d.trail && d.trail.length > 1) { if (trail) trail.setLatLngs(d.trail); else trail = L.polyline(d.trail, {color:'#1E88E5', weight:4, opacity:.8}).addTo(map); }
      if (d.rider && d.rider[0] !== null) {
        if (rider) rider.setLatLng(d.rider); else rider = L.marker(d.rider, {icon: DMap.icon('rider'), zIndexOffset: 1000}).bindPopup('Rider').addTo(map);
      }
      const t = document.getElementById('etaText');
      if (t && d.eta !== null) t.textContent = d.eta > 0 ? '· ETA ' + d.eta + ' min' : '';
    } catch(e) {}
  }
  refresh();
  if (O.active) setInterval(refresh, 8000);
})();
</script>
HTML);
