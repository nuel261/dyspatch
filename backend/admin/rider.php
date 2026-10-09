<?php
require __DIR__ . '/_init.php';
$admin = require_admin();
$id = (int) ($_GET['id'] ?? 0);
$r = DB::row('SELECT * FROM riders WHERE id = ?', [$id]);
if (!$r) { flash('Rider not found', 'err'); redirect('riders.php'); }
$name = trim($r['first_name'] . ' ' . $r['last_name']) ?: 'Unnamed rider';

handle_post(function ($in) use ($r, $admin, $name) {
    $aid = (int) $admin['id'];
    switch ($in['action'] ?? '') {
        case 'kyc_approve':
            DB::update('riders', ['kyc_status' => 'verified', 'status' => $r['status'] === 'suspended' ? 'suspended' : 'active'], 'id = ?', [$r['id']]);
            audit($aid, 'rider.kyc_approve', 'rider', (int) $r['id']);
            Notifier::notify('rider', (int) $r['id'], 'system', "You're verified!", 'Your ID has been verified. Go online to start receiving delivery requests.', ['type' => 'kyc']);
            return "$name is verified and can go online.";
        case 'kyc_reject':
            DB::update('riders', ['kyc_status' => 'rejected'], 'id = ?', [$r['id']]);
            audit($aid, 'rider.kyc_reject', 'rider', (int) $r['id'], $in['reason'] ?? '');
            Notifier::notify('rider', (int) $r['id'], 'system', 'Verification unsuccessful', 'We could not verify your ID. ' . trim((string) ($in['reason'] ?? '')) . ' Please resubmit in the app.', ['type' => 'kyc']);
            return 'Verification rejected. The rider has been notified.';
        case 'suspend':
            $reason = trim((string) ($in['reason'] ?? '')) ?: 'Terms of Service violation';
            DB::update('riders', ['status' => 'suspended', 'is_online' => 0, 'suspension_reason' => $reason], 'id = ?', [$r['id']]);
            DB::query('DELETE FROM api_tokens WHERE owner_type = ? AND owner_id = ?', ['rider', $r['id']]);
            audit($aid, 'rider.suspend', 'rider', (int) $r['id'], $reason);
            return "$name has been suspended from the platform.";
        case 'reinstate':
            DB::update('riders', ['status' => $r['kyc_status'] === 'verified' ? 'active' : 'pending', 'suspension_reason' => null], 'id = ?', [$r['id']]);
            audit($aid, 'rider.reinstate', 'rider', (int) $r['id']);
            Notifier::notify('rider', (int) $r['id'], 'system', 'Account reinstated', 'Your Dyspatch rider account is active again.');
            return "$name has been reinstated.";
        case 'offline':
            DB::update('riders', ['is_online' => 0], 'id = ?', [$r['id']]);
            return 'Rider set offline.';
        case 'update':
            DB::update('riders', [
                'first_name' => trim((string) $in['first_name']), 'last_name' => trim((string) $in['last_name']),
                'email' => filter_var($in['email'] ?? '', FILTER_VALIDATE_EMAIL) ?: null, 'vehicle_type' => $in['vehicle_type'],
                'plate' => strtoupper(trim((string) $in['plate'])) ?: null, 'zone_id' => ((int) $in['zone_id']) ?: null,
            ], 'id = ?', [$r['id']]);
            audit($aid, 'rider.update', 'rider', (int) $r['id']);
            return 'Rider details saved.';
        case 'adjust':
            if (!in_array($admin['role'], ['super'], true)) throw new ApiException('Only super admins can adjust balances');
            $amt = to_kobo($in['amount'] ?? 0);
            $note = trim((string) ($in['note'] ?? '')) ?: 'Manual adjustment';
            if ($amt > 0) Wallet::credit('rider', (int) $r['id'], $amt, 'adjustment', $note);
            elseif ($amt < 0) Wallet::debit('rider', (int) $r['id'], -$amt, 'adjustment', $note);
            else throw new ApiException('Enter a non-zero amount');
            audit($aid, 'wallet.adjust', 'rider', (int) $r['id'], naira($amt) . " · $note");
            return 'Wallet adjusted by ' . naira($amt) . '.';
    }
    return null;
});

$stats = DB::row("SELECT COUNT(*) total, SUM(status='delivered') delivered, SUM(status IN ('cancelled','failed')) failed,
    COALESCE(SUM(CASE WHEN status='delivered' THEN rider_earning_kobo END),0) earned,
    SUM(status='delivered' AND DATE(delivered_at)=CURDATE()) today FROM orders WHERE rider_id = ?", [$id]);
$offers = DB::row("SELECT COUNT(*) total, SUM(status='accepted') accepted FROM order_offers WHERE rider_id = ?", [$id]);
$orders = DB::all('SELECT * FROM orders WHERE rider_id = ? ORDER BY id DESC LIMIT 15', [$id]);
$txs = Wallet::transactions('rider', $id, 10);
$banks = DB::all("SELECT * FROM bank_accounts WHERE owner_type = 'rider' AND owner_id = ?", [$id]);
$zones = DB::all('SELECT id, name FROM zones ORDER BY name');
$zone = $r['zone_id'] ? DB::value('SELECT name FROM zones WHERE id = ?', [$r['zone_id']]) : null;
$on = $r['is_online'] && $r['location_updated_at'] && strtotime($r['location_updated_at']) > time() - 600;
$accept = $offers['total'] ? round($offers['accepted'] / $offers['total'] * 100) : null;

layout_start($name, 'riders', e($r['phone']) . ' · joined ' . date('j M Y', strtotime($r['created_at'])), '<a class="btn ghost" href="riders.php">All riders</a>');
?>
<div class="grid g4">
  <div class="card stat"><span class="k">Delivered</span><span class="v"><?= number_format((int) $stats['delivered']) ?></span><span class="d"><?= (int) $stats['today'] ?> today</span><span class="ico"><?= icon('check') ?></span></div>
  <div class="card stat"><span class="k">Lifetime earnings</span><span class="v"><?= naira($stats['earned'], false) ?></span><span class="d">Paid per drop to wallet</span><span class="ico"><?= icon('wallet') ?></span></div>
  <div class="card stat"><span class="k">Acceptance</span><span class="v"><?= $accept === null ? '—' : $accept . '%' ?></span><span class="d"><?= (int) $offers['total'] ?> requests offered</span><span class="ico"><?= icon('activity') ?></span></div>
  <div class="card stat dark"><span class="k">Wallet balance</span><span class="v"><?= naira(Wallet::balance('rider', $id)) ?></span><span class="d">★ <?= number_format((float) $r['rating'], 2) ?> from <?= (int) $r['rating_count'] ?> ratings</span></div>
</div>

<div class="grid g-main">
  <div class="stack" style="gap:20px">
    <div class="card"><div class="card-h"><h2>Verification</h2><?= badge($r['kyc_status'], ['none' => 'Not submitted', 'submitted' => 'Awaiting review', 'verified' => 'Verified', 'rejected' => 'Rejected'][$r['kyc_status']]) ?></div>
      <div class="card-b grid g2">
        <dl class="kv">
          <dt>ID type</dt><dd><?= e(strtoupper(str_replace('_', ' ', (string) $r['id_type'])) ?: '—') ?></dd>
          <dt>ID number</dt><dd class="mono"><?= e($r['id_number'] ?: '—') ?></dd>
          <dt>Provider</dt><dd><?= e($r['kyc_provider'] ?: '—') ?><?= $r['kyc_reference'] ? ' · <span class="mono small">' . e($r['kyc_reference']) . '</span>' : '' ?></dd>
        </dl>
        <div><?php if ($r['id_document']): ?><a href="<?= e(public_file($r['id_document'])) ?>" target="_blank"><img src="<?= e(public_file($r['id_document'])) ?>" alt="ID document" style="width:100%;max-height:200px;object-fit:cover;border-radius:12px;border:1px solid var(--border)"></a><?php else: ?><div class="callout">No ID document uploaded yet.</div><?php endif; ?></div>
      </div>
      <?php if ($r['kyc_status'] === 'submitted' || $r['kyc_status'] === 'rejected'): ?>
      <div class="card-b row" style="border-top:1px solid var(--border)">
        <form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="kyc_approve"><button class="btn"><?= icon('check') ?> Approve verification</button></form>
        <button class="btn danger ghost" data-open="dlgReject">Reject</button>
      </div><?php endif; ?>
    </div>

    <div class="card"><div class="card-h"><h2>Recent deliveries</h2><a class="btn ghost sm" href="orders.php?q=<?= urlencode($r['phone']) ?>">All orders</a></div>
      <div class="table-wrap"><table class="t"><thead><tr><th>Track ID</th><th>Route</th><th>Status</th><th class="right">Earning</th><th>Date</th></tr></thead><tbody>
      <?php foreach ($orders as $o): ?><tr class="link" data-href="order.php?id=<?= $o['id'] ?>"><td><?= tid($o['track_id']) ?></td><td class="small"><?= e(Orders::shortRoute($o)) ?></td><td><?= badge($o['status']) ?></td><td class="right"><?= naira($o['rider_earning_kobo'], false) ?></td><td class="muted small nowrap"><?= date('j M, H:i', strtotime($o['created_at'])) ?></td></tr><?php endforeach; ?>
      <?php if (!$orders): ?><tr><td colspan="5"><div class="empty">No deliveries yet.</div></td></tr><?php endif; ?>
      </tbody></table></div></div>

    <div class="card"><div class="card-h"><h2>Wallet activity</h2><?php if ($admin['role'] === 'super'): ?><button class="btn ghost sm" data-open="dlgAdjust">Adjust balance</button><?php endif; ?></div>
      <div class="table-wrap"><table class="t"><tbody>
      <?php foreach ($txs as $t): ?><tr><td><div class="strong"><?= e($t['description']) ?></div><div class="sub mono"><?= e($t['reference']) ?></div></td><td class="right nowrap <?= $t['type'] === 'credit' ? 'green' : '' ?>" style="font-weight:600"><?= ($t['type'] === 'credit' ? '+' : '−') . naira($t['amount_kobo']) ?></td><td class="muted small nowrap"><?= time_ago($t['created_at']) ?></td></tr><?php endforeach; ?>
      <?php if (!$txs): ?><tr><td><div class="empty">No wallet activity yet.</div></td></tr><?php endif; ?>
      </tbody></table></div></div>
  </div>

  <div class="stack" style="gap:20px">
    <div class="card"><div class="card-b stack" style="align-items:center;text-align:center">
      <?= avatar($name, $r['photo'], 'lg') ?>
      <div><h2><?= e($name) ?></h2><div class="muted"><?= e(ucfirst($r['vehicle_type'])) ?> · <span class="mono"><?= e($r['plate'] ?: 'no plate') ?></span></div></div>
      <div class="row" style="justify-content:center"><?= badge($r['status'], ucfirst($r['status'])) ?><?= badge($on ? 'online' : 'offline', $on ? 'Online' : 'Offline') ?></div>
      <?php if ($r['status'] === 'suspended' && $r['suspension_reason']): ?><div class="flash err small" style="width:100%">Policy: <?= e($r['suspension_reason']) ?></div><?php endif; ?>
      <div class="row" style="justify-content:center">
        <a class="btn ghost sm" href="tel:<?= e($r['phone']) ?>"><?= icon('phone') ?> Call</a>
        <button class="btn ghost sm" data-open="dlgEdit">Edit</button>
        <?php if ($on): ?><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="offline"><button class="btn ghost sm">Set offline</button></form><?php endif; ?>
        <?php if ($r['status'] === 'suspended'): ?><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="reinstate"><button class="btn soft sm">Reinstate</button></form>
        <?php else: ?><button class="btn danger ghost sm" data-open="dlgSuspend">Suspend</button><?php endif; ?>
      </div>
    </div></div>
    <div class="card"><div class="card-h"><h3>Last known location</h3><span class="muted small"><?= time_ago($r['location_updated_at']) ?></span></div>
      <?php if ($r['lat'] !== null): ?><div id="rmap" class="map short" style="border-radius:0 0 20px 20px"></div><?php else: ?><div class="card-b muted">No location reported yet.</div><?php endif; ?></div>
    <div class="card"><div class="card-h"><h3>Details</h3></div><div class="card-b"><dl class="kv">
      <dt>Phone</dt><dd><?= e($r['phone']) ?></dd><dt>Email</dt><dd><?= e($r['email'] ?: '—') ?></dd><dt>Zone</dt><dd><?= e($zone ?: '—') ?></dd>
      <dt>Payout accounts</dt><dd><?php foreach ($banks as $b): ?><div><?= e($b['bank_name']) ?> · <span class="mono"><?= e($b['account_number']) ?></span><?= $b['is_verified'] ? ' ' . badge('verified', 'Verified') : '' ?></div><?php endforeach; ?><?= $banks ? '' : '—' ?></dd>
    </dl></div></div>
  </div>
</div>

<dialog id="dlgReject"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="kyc_reject">
  <div class="d-h"><h3>Reject verification</h3><button type="button" class="x" data-close>×</button></div>
  <div class="d-b"><label class="f">Reason (sent to rider)<input class="input" name="reason" placeholder="e.g. ID photo is blurry" required></label></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn danger">Reject</button></div></form></dialog>
<dialog id="dlgSuspend"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="suspend">
  <div class="d-h"><h3>Suspend rider</h3><button type="button" class="x" data-close>×</button></div>
  <div class="d-b"><p class="muted small">Riders are independent platform users. Suspend only for a platform policy / Terms of Service reason.</p>
    <label class="f">Policy reason<select class="input" name="reason"><option>Repeated failed deliveries</option><option>Safety complaint under review</option><option>Fraudulent activity</option><option>Invalid or expired documents</option><option>Terms of Service violation</option></select></label></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn danger">Suspend</button></div></form></dialog>
<dialog id="dlgAdjust"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="adjust">
  <div class="d-h"><h3>Adjust wallet</h3><button type="button" class="x" data-close>×</button></div>
  <div class="d-b"><label class="f">Amount (₦)<input class="input" name="amount" placeholder="e.g. 500 or -500" required><span class="hint">Positive credits the wallet, negative debits it.</span></label><label class="f">Note<input class="input" name="note" required placeholder="Shown in the rider's wallet history"></label></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Apply</button></div></form></dialog>
<dialog id="dlgEdit"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="update">
  <div class="d-h"><h3>Edit rider</h3><button type="button" class="x" data-close>×</button></div>
  <div class="d-b"><div class="form-grid">
    <label class="f">First name<input class="input" name="first_name" value="<?= e($r['first_name']) ?>"></label><label class="f">Last name<input class="input" name="last_name" value="<?= e($r['last_name']) ?>"></label>
    <label class="f">Email<input class="input" name="email" value="<?= e($r['email']) ?>"></label><label class="f">Plate<input class="input" name="plate" value="<?= e($r['plate']) ?>"></label>
    <label class="f">Vehicle<select class="input" name="vehicle_type"><?php foreach (['bike' => 'Motorbike', 'bicycle' => 'Bicycle', 'car' => 'Car', 'truck' => 'Truck'] as $k => $l): ?><option value="<?= $k ?>" <?= $r['vehicle_type'] === $k ? 'selected' : '' ?>><?= $l ?></option><?php endforeach; ?></select></label>
    <label class="f">Zone<select class="input" name="zone_id"><option value="">—</option><?php foreach ($zones as $z): ?><option value="<?= $z['id'] ?>" <?= (int) $r['zone_id'] === (int) $z['id'] ? 'selected' : '' ?>><?= e($z['name']) ?></option><?php endforeach; ?></select></label>
  </div></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Save</button></div></form></dialog>
<?php
$js = $r['lat'] !== null ? '<script>const m=DMap.create("rmap",[' . (float) $r['lat'] . ',' . (float) $r['lng'] . '],15);L.marker([' . (float) $r['lat'] . ',' . (float) $r['lng'] . '],{icon:DMap.icon("rider","' . ($on ? '' : 'idle') . '")}).addTo(m);</script>' : '';
layout_end($js);
