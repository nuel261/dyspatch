<?php
require __DIR__ . '/_init.php';
$admin = require_admin(['super', 'ops']);

handle_post(function ($in) use ($admin) {
    $t = DB::row('SELECT * FROM topup_requests WHERE id = ?', [(int) ($in['id'] ?? 0)]);
    if (!$t) throw new ApiException('Top-up not found');
    if ($t['status'] === 'confirmed' || $t['status'] === 'rejected') throw new ApiException('This top-up was already processed');
    if (($in['action'] ?? '') === 'confirm') {
        $amt = to_kobo($in['amount'] ?? '');
        if ($amt <= 0) throw new ApiException('Enter the amount received');
        DB::tx(function () use ($t, $amt, $admin) {
            DB::update('topup_requests', ['status' => 'confirmed', 'amount_kobo' => $amt, 'admin_id' => $admin['id'], 'confirmed_at' => now()], 'id = ?', [$t['id']]);
            Wallet::credit('user', (int) $t['user_id'], $amt, 'topup', 'Wallet top-up · bank transfer', null, 'TOP-' . $t['reference']);
        });
        Notifier::notify('user', (int) $t['user_id'], 'payment', 'Wallet funded', naira($amt) . ' was added to your wallet.', ['type' => 'topup', 'reference' => $t['reference']],
            ['heading' => 'Your wallet has been funded', 'html' => '<p>We received your transfer of <b style="color:#0E0F10">' . naira($amt) . '</b> (ref ' . e($t['reference']) . '). It is now available in your Dyspatch wallet.</p>']);
        audit((int) $admin['id'], 'topup.confirm', 'topup', (int) $t['id'], naira($amt));
        return 'Wallet credited with ' . naira($amt) . '.';
    }
    if (($in['action'] ?? '') === 'reject') {
        $note = trim((string) ($in['note'] ?? '')) ?: 'Transfer not received';
        DB::update('topup_requests', ['status' => 'rejected', 'admin_id' => $admin['id'], 'note' => $note, 'confirmed_at' => now()], 'id = ?', [$t['id']]);
        Notifier::notify('user', (int) $t['user_id'], 'payment', 'Top-up not confirmed', "We couldn't confirm your top-up {$t['reference']}: $note. Contact support if you were debited.", ['type' => 'topup']);
        audit((int) $admin['id'], 'topup.reject', 'topup', (int) $t['id'], $note);
        return 'Top-up rejected.';
    }
    return null;
});

$f = $_GET['f'] ?? 'pending';
$where = $f === 'all' ? '1=1' : 't.status = ?';
$p = $f === 'all' ? [] : [$f];
[$rows, $pager] = paginate("SELECT t.*, u.first_name, u.last_name, u.phone FROM topup_requests t JOIN users u ON u.id = t.user_id WHERE $where ORDER BY t.id DESC", $p);
$c = DB::row("SELECT SUM(status='pending') pending, SUM(status='awaiting') awaiting, SUM(status='confirmed') confirmed, SUM(status='rejected') rejected,
    COALESCE(SUM(CASE WHEN status='confirmed' AND DATE(confirmed_at)=CURDATE() THEN amount_kobo END),0) today FROM topup_requests");

layout_start('Top-ups', 'topups', 'Confirm bank transfers to ' . e(Settings::get('topup_bank_name')) . ' · ' . e(Settings::get('topup_account_number')) . ' (' . e(Settings::get('topup_account_name')) . '). ' . naira($c['today']) . ' confirmed today.');
?>
<div class="callout">Match the <b>reference</b> in the customer's transfer narration against your bank statement, enter the amount actually received, then confirm. The customer is credited instantly and notified by push and email. Card top-ups (Paystack/Flutterwave) confirm automatically.</div>
<div class="chips"><?php foreach (['pending' => ['Needs confirmation', $c['pending']], 'awaiting' => ['Reference issued', $c['awaiting']], 'confirmed' => ['Confirmed', $c['confirmed']], 'rejected' => ['Rejected', $c['rejected']], 'all' => ['All', null]] as $k => [$l, $n]): ?><a class="chip <?= $f === $k ? 'on' : '' ?>" href="?f=<?= $k ?>"><?= $l ?><?php if ($n !== null): ?><span class="n"><?= (int) $n ?></span><?php endif; ?></a><?php endforeach; ?></div>
<div class="card"><div class="table-wrap"><table class="t"><thead><tr><th>Reference</th><th>Customer</th><th>Method</th><th class="right">Amount</th><th>Status</th><th>Requested</th><th></th></tr></thead><tbody>
<?php foreach ($rows as $t): $name = trim($t['first_name'] . ' ' . $t['last_name']) ?: $t['phone']; $open = in_array($t['status'], ['pending', 'awaiting'], true); ?>
<tr>
  <td><?= tid($t['reference']) ?></td>
  <td><a href="customer.php?id=<?= $t['user_id'] ?>" class="strong"><?= e($name) ?></a><div class="sub"><?= e($t['phone']) ?></div></td>
  <td><?= e(ucwords(str_replace('_', ' ', $t['method']))) ?></td>
  <td class="right nowrap"><?= $t['amount_kobo'] !== null ? naira($t['amount_kobo']) : '<span class="faint">Not stated</span>' ?></td>
  <td><?= badge($t['status'], ['awaiting' => 'Reference issued', 'pending' => 'Needs confirmation', 'confirmed' => 'Confirmed', 'rejected' => 'Rejected'][$t['status']]) ?><?= $t['note'] ? '<div class="sub">' . e($t['note']) . '</div>' : '' ?></td>
  <td class="muted small nowrap"><?= date('j M, H:i', strtotime($t['created_at'])) ?></td>
  <td class="right nowrap"><?php if ($open && $t['method'] === 'bank_transfer'): ?>
    <form method="post" class="row end" style="gap:6px"><?= csrf_field() ?><input type="hidden" name="id" value="<?= $t['id'] ?>">
      <input class="input" name="amount" style="width:120px;padding:7px 10px" placeholder="₦ received" value="<?= $t['amount_kobo'] ? e($t['amount_kobo'] / 100) : '' ?>">
      <button class="btn sm" name="action" value="confirm">Confirm</button>
      <button class="btn danger ghost sm" name="action" value="reject" formnovalidate>Reject</button>
    </form><?php endif; ?></td>
</tr>
<?php endforeach; ?>
<?php if (!$rows): ?><tr><td colspan="7"><div class="empty"><?= icon('down') ?><div>Nothing here right now.</div></div></td></tr><?php endif; ?>
</tbody></table></div><?= $pager ?></div>
<?php layout_end();
