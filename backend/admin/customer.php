<?php
require __DIR__ . '/_init.php';
$admin = require_admin();
$id = (int) ($_GET['id'] ?? 0);
$u = DB::row('SELECT * FROM users WHERE id = ?', [$id]);
if (!$u) { flash('Customer not found', 'err'); redirect('customers.php'); }
$name = trim($u['first_name'] . ' ' . $u['last_name']) ?: 'New customer';

handle_post(function ($in) use ($u, $admin, $name) {
    $aid = (int) $admin['id'];
    switch ($in['action'] ?? '') {
        case 'suspend':
            DB::update('users', ['status' => 'suspended'], 'id = ?', [$u['id']]);
            DB::query("DELETE FROM api_tokens WHERE owner_type = 'user' AND owner_id = ?", [$u['id']]);
            audit($aid, 'user.suspend', 'user', (int) $u['id'], $in['reason'] ?? '');
            return "$name has been suspended and signed out.";
        case 'reinstate':
            DB::update('users', ['status' => 'active'], 'id = ?', [$u['id']]);
            audit($aid, 'user.reinstate', 'user', (int) $u['id']);
            return "$name has been reinstated.";
        case 'adjust':
            if ($admin['role'] !== 'super') throw new ApiException('Only super admins can adjust balances');
            $amt = to_kobo($in['amount'] ?? 0);
            $note = trim((string) ($in['note'] ?? '')) ?: 'Manual adjustment';
            if ($amt > 0) Wallet::credit('user', (int) $u['id'], $amt, 'adjustment', $note);
            elseif ($amt < 0) Wallet::debit('user', (int) $u['id'], -$amt, 'adjustment', $note);
            else throw new ApiException('Enter a non-zero amount');
            Notifier::notify('user', (int) $u['id'], 'payment', $amt > 0 ? 'Wallet credited' : 'Wallet debited', naira(abs($amt)) . " · $note", ['type' => 'adjustment']);
            audit($aid, 'wallet.adjust', 'user', (int) $u['id'], naira($amt) . " · $note");
            return 'Wallet adjusted by ' . naira($amt) . '.';
        case 'message':
            $title = trim((string) ($in['title'] ?? ''));
            $body = trim((string) ($in['body'] ?? ''));
            if ($title === '' || $body === '') throw new ApiException('Title and message are required');
            Notifier::notify('user', (int) $u['id'], 'system', $title, $body, ['type' => 'message'], ['send' => !empty($in['email'])]);
            audit($aid, 'user.message', 'user', (int) $u['id'], $title);
            return 'Message sent.';
    }
    return null;
});

$stats = DB::row("SELECT COUNT(*) total, SUM(status='delivered') delivered, SUM(status IN ('pending','matched','picked_up','en_route','arrived')) active,
    COALESCE(SUM(CASE WHEN status='delivered' THEN fee_kobo END),0) spent FROM orders WHERE user_id = ?", [$id]);
$orders = DB::all('SELECT * FROM orders WHERE user_id = ? ORDER BY id DESC LIMIT 20', [$id]);
$txs = Wallet::transactions('user', $id, 12);
$devices = (int) DB::value("SELECT COUNT(*) FROM device_tokens WHERE owner_type = 'user' AND owner_id = ?", [$id]);
$biz = DB::row('SELECT * FROM business_verifications WHERE user_id = ? ORDER BY id DESC LIMIT 1', [$id]);
$locs = DB::all('SELECT * FROM saved_locations WHERE user_id = ?', [$id]);

layout_start($name, 'customers', e($u['phone'] ?: $u['email']) . ' · customer since ' . date('j M Y', strtotime($u['created_at'])),
    '<a class="btn ghost" href="order_new.php">' . icon('plus') . ' New delivery</a>');
?>
<div class="grid g4">
  <div class="card stat"><span class="k">Deliveries</span><span class="v"><?= number_format((int) $stats['delivered']) ?></span><span class="d"><?= (int) $stats['total'] ?> orders total</span><span class="ico"><?= icon('box') ?></span></div>
  <div class="card stat"><span class="k">Active now</span><span class="v"><?= (int) $stats['active'] ?></span><span class="d">In progress</span><span class="ico"><?= icon('truck') ?></span></div>
  <div class="card stat"><span class="k">Lifetime spend</span><span class="v"><?= naira($stats['spent'], false) ?></span><span class="d">Delivered orders</span><span class="ico"><?= icon('receipt') ?></span></div>
  <div class="card stat dark"><span class="k">Wallet</span><span class="v"><?= naira(Wallet::balance('user', $id)) ?></span><span class="d"><?= $devices ?> device<?= $devices === 1 ? '' : 's' ?> with push enabled</span></div>
</div>
<div class="grid g-main">
  <div class="stack" style="gap:20px">
    <div class="card"><div class="card-h"><h2>Orders</h2></div><div class="table-wrap"><table class="t"><thead><tr><th>Track ID</th><th>Route</th><th>Status</th><th class="right">Fee</th><th>Created</th></tr></thead><tbody>
      <?php foreach ($orders as $o): ?><tr class="link" data-href="order.php?id=<?= $o['id'] ?>"><td><?= tid($o['track_id']) ?></td><td class="small"><?= e(Orders::shortRoute($o)) ?></td><td><?= badge($o['status']) ?></td><td class="right"><?= naira($o['fee_kobo'], false) ?></td><td class="muted small nowrap"><?= date('j M, H:i', strtotime($o['created_at'])) ?></td></tr><?php endforeach; ?>
      <?php if (!$orders): ?><tr><td colspan="5"><div class="empty">No orders yet.</div></td></tr><?php endif; ?>
    </tbody></table></div></div>
    <div class="card"><div class="card-h"><h2>Wallet activity</h2><?php if ($admin['role'] === 'super'): ?><button class="btn ghost sm" data-open="dlgAdjust">Adjust balance</button><?php endif; ?></div><div class="table-wrap"><table class="t"><tbody>
      <?php foreach ($txs as $t): ?><tr><td><div class="strong"><?= e($t['description']) ?></div><div class="sub mono"><?= e($t['reference']) ?></div></td><td class="right nowrap <?= $t['type'] === 'credit' ? 'green' : '' ?>" style="font-weight:600"><?= ($t['type'] === 'credit' ? '+' : '−') . naira($t['amount_kobo']) ?></td><td class="muted small nowrap"><?= time_ago($t['created_at']) ?></td></tr><?php endforeach; ?>
      <?php if (!$txs): ?><tr><td><div class="empty">No wallet activity yet.</div></td></tr><?php endif; ?>
    </tbody></table></div></div>
  </div>
  <div class="stack" style="gap:20px">
    <div class="card"><div class="card-b stack" style="align-items:center;text-align:center">
      <?= avatar($name, $u['avatar'], 'lg') ?>
      <div><h2><?= e($name) ?></h2><div class="muted"><?= e($u['address'] ?: 'No address set') ?></div></div>
      <div class="row" style="justify-content:center"><?= badge($u['status'] === 'active' ? 'active' : 'suspended', ucfirst($u['status'])) ?><?= $u['business_verified'] ? badge('verified', 'Verified business') : '' ?></div>
      <div class="row" style="justify-content:center">
        <?php if ($u['phone']): ?><a class="btn ghost sm" href="tel:<?= e($u['phone']) ?>"><?= icon('phone') ?> Call</a><?php endif; ?>
        <button class="btn ghost sm" data-open="dlgMsg"><?= icon('bell') ?> Message</button>
        <?php if ($u['status'] === 'active'): ?><form method="post" data-confirm="Suspend this customer and sign them out?"><?= csrf_field() ?><input type="hidden" name="action" value="suspend"><button class="btn danger ghost sm">Suspend</button></form>
        <?php else: ?><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="reinstate"><button class="btn soft sm">Reinstate</button></form><?php endif; ?>
      </div></div></div>
    <div class="card"><div class="card-h"><h3>Profile</h3></div><div class="card-b"><dl class="kv">
      <dt>Phone</dt><dd><?= e($u['phone'] ?: '—') ?></dd><dt>Email</dt><dd><?= e($u['email'] ?: '—') ?></dd>
      <dt>Sign-in</dt><dd><?= $u['firebase_uid'] ? 'Google' : 'Phone OTP' ?><?= $u['two_factor'] ? ' · 2FA on' : '' ?></dd>
      <dt>Default type</dt><dd><?= e(ucfirst($u['default_delivery_type'])) ?></dd>
      <dt>Business</dt><dd><?= $biz ? e($biz['business_name']) . ' ' . badge($biz['status']) : '—' ?></dd>
      <dt>Saved places</dt><dd><?php foreach ($locs as $l): ?><div><b><?= e($l['label']) ?></b> · <span class="muted"><?= e($l['address']) ?></span></div><?php endforeach; ?><?= $locs ? '' : '—' ?></dd>
    </dl></div></div>
  </div>
</div>
<dialog id="dlgAdjust"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="adjust">
  <div class="d-h"><h3>Adjust wallet</h3><button type="button" class="x" data-close>×</button></div>
  <div class="d-b"><label class="f">Amount (₦)<input class="input" name="amount" placeholder="e.g. 2000 or -500" required><span class="hint">Positive credits, negative debits. The customer is notified.</span></label><label class="f">Note<input class="input" name="note" required placeholder="e.g. Goodwill credit for delayed delivery"></label></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Apply</button></div></form></dialog>
<dialog id="dlgMsg"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="message">
  <div class="d-h"><h3>Message customer</h3><button type="button" class="x" data-close>×</button></div>
  <div class="d-b"><label class="f">Title<input class="input" name="title" required></label><label class="f">Message<textarea class="input" name="body" required></textarea></label>
    <label class="switch"><input type="checkbox" name="email" value="1" <?= $u['email'] ? 'checked' : 'disabled' ?>> Also send by email</label><p class="muted small">Delivered as an in-app notification and push notification.</p></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Send</button></div></form></dialog>
<?php layout_end();
