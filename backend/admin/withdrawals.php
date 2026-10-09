<?php
require __DIR__ . '/_init.php';
$admin = require_admin(['super', 'ops']);

handle_post(function ($in) use ($admin) {
    $id = (int) ($in['id'] ?? 0);
    $aid = (int) $admin['id'];
    switch ($in['action'] ?? '') {
        case 'pay':
            $w = Wallet::processWithdrawal($id, $aid, false, $in['note'] ?? null);
            audit($aid, 'withdrawal.pay', 'withdrawal', $id, $w['provider'] . ' ' . $w['status']);
            return $w['status'] === 'paid' ? 'Marked as paid.' : 'Transfer sent to ' . ucfirst((string) $w['provider']) . ' — status: ' . $w['status'] . '.';
        case 'manual':
            Wallet::processWithdrawal($id, $aid, true, trim((string) ($in['note'] ?? '')) ?: 'Paid manually');
            audit($aid, 'withdrawal.manual', 'withdrawal', $id);
            return 'Marked as paid manually.';
        case 'reject':
            Wallet::rejectWithdrawal($id, $aid, trim((string) ($in['note'] ?? '')) ?: 'Rejected by admin');
            audit($aid, 'withdrawal.reject', 'withdrawal', $id, $in['note'] ?? '');
            return 'Withdrawal rejected and funds returned to the wallet.';
        case 'pay_due':
            $n = 0; $fail = 0;
            foreach (DB::all("SELECT id FROM withdrawals WHERE status = 'pending' AND scheduled_for <= CURDATE()") as $w) {
                try { Wallet::processWithdrawal((int) $w['id'], $aid); $n++; } catch (Throwable $e) { $fail++; }
            }
            audit($aid, 'withdrawal.batch', null, null, "$n processed, $fail failed");
            return "$n payout(s) processed" . ($fail ? ", $fail failed — see the Failed tab." : '.');
    }
    return null;
});

$f = $_GET['f'] ?? 'pending';
$map = ['pending' => "w.status = 'pending'", 'due' => "w.status = 'pending' AND w.scheduled_for <= CURDATE()", 'processing' => "w.status = 'processing'", 'failed' => "w.status = 'failed'", 'paid' => "w.status = 'paid'", 'rejected' => "w.status = 'rejected'", 'all' => '1=1'];
$where = $map[$f] ?? $map['pending'];
[$rows, $pager] = paginate("SELECT w.*, b.bank_name, b.account_name, b.account_number, b.is_verified,
    COALESCE(CONCAT(r.first_name,' ',r.last_name), CONCAT(u.first_name,' ',u.last_name)) owner_name, COALESCE(r.phone, u.phone) owner_phone
    FROM withdrawals w LEFT JOIN bank_accounts b ON b.id = w.bank_account_id
    LEFT JOIN riders r ON w.owner_type = 'rider' AND r.id = w.owner_id LEFT JOIN users u ON w.owner_type = 'user' AND u.id = w.owner_id
    WHERE $where ORDER BY w.scheduled_for, w.id", []);
$c = DB::row("SELECT SUM(status='pending') pending, SUM(status='pending' AND scheduled_for <= CURDATE()) due, COALESCE(SUM(CASE WHEN status='pending' AND scheduled_for <= CURDATE() THEN net_kobo END),0) due_amt,
    SUM(status='processing') processing, SUM(status='failed') failed, SUM(status='paid') paid, SUM(status='rejected') rejected FROM withdrawals");
$provider = Settings::get('withdrawal_provider', 'manual');
$auto = $provider !== 'manual' && Payments::configured($provider);
$cut = Settings::int('withdrawal_cutoff_hour', 17);

layout_start('Withdrawals', 'withdrawals', "Requests before {$cut}:00 WAT are due same day; later ones roll to the next business day. Payout method: <b>" . ($auto ? ucfirst($provider) . ' disbursement' : 'Manual bank transfer') . '</b>.',
    (int) $c['due'] ? '<form method="post" data-confirm="Process all ' . (int) $c['due'] . ' due payouts (' . naira($c['due_amt']) . ')?">' . csrf_field() . '<input type="hidden" name="action" value="pay_due"><button class="btn">' . icon('up') . ' Pay all due · ' . naira($c['due_amt'], false) . '</button></form>' : '');
?>
<?php if (!$auto): ?><div class="flash warn"><?= icon('alert') ?><span>Automatic disbursement is off. Pay each request from your bank, then click <b>Mark paid</b>. Turn on Paystack or Flutterwave payouts in <a href="settings.php#payments" style="text-decoration:underline">Settings</a>.</span></div><?php endif; ?>
<div class="chips"><?php foreach (['pending' => ['Pending', $c['pending']], 'due' => ['Due today', $c['due']], 'processing' => ['Processing', $c['processing']], 'failed' => ['Failed', $c['failed']], 'paid' => ['Paid', $c['paid']], 'rejected' => ['Rejected', $c['rejected']], 'all' => ['All', null]] as $k => [$l, $n]): ?><a class="chip <?= $f === $k ? 'on' : '' ?>" href="?f=<?= $k ?>"><?= $l ?><?php if ($n !== null): ?><span class="n"><?= (int) $n ?></span><?php endif; ?></a><?php endforeach; ?></div>
<div class="card"><div class="table-wrap"><table class="t"><thead><tr><th>Reference</th><th>Payee</th><th>Bank account</th><th class="right">Amount</th><th class="right">Fee</th><th>Pay on</th><th>Status</th><th></th></tr></thead><tbody>
<?php foreach ($rows as $w): $open = in_array($w['status'], ['pending', 'failed', 'processing'], true); ?>
<tr>
  <td><?= tid($w['reference']) ?><div class="sub"><?= date('j M, H:i', strtotime($w['created_at'])) ?></div></td>
  <td><a class="strong" href="<?= $w['owner_type'] === 'rider' ? 'rider' : 'customer' ?>.php?id=<?= $w['owner_id'] ?>"><?= e(trim((string) $w['owner_name']) ?: 'Unnamed') ?></a><div class="sub"><?= ucfirst($w['owner_type']) ?> · <?= e($w['owner_phone']) ?></div></td>
  <td><?= e($w['bank_name']) ?> <?= $w['is_verified'] ? badge('verified', 'Verified') : '' ?><div class="sub"><span class="mono"><?= e($w['account_number']) ?></span> · <?= e($w['account_name']) ?></div></td>
  <td class="right nowrap" style="font-weight:600"><?= naira($w['net_kobo']) ?></td><td class="right nowrap muted"><?= naira($w['fee_kobo']) ?></td>
  <td class="nowrap"><?= date('D j M', strtotime($w['scheduled_for'])) ?><?= $w['status'] === 'pending' && $w['scheduled_for'] <= date('Y-m-d') ? ' ' . badge('pending', 'Due') : '' ?></td>
  <td><?= badge($w['status'], ucfirst($w['status'])) ?><?= $w['note'] ? '<div class="sub">' . e($w['note']) . '</div>' : '' ?><?= $w['provider_ref'] ? '<div class="sub mono">' . e($w['provider_ref']) . '</div>' : '' ?></td>
  <td class="right nowrap"><?php if ($open): ?>
    <form method="post" class="row end" style="gap:6px"><?= csrf_field() ?><input type="hidden" name="id" value="<?= $w['id'] ?>"><input type="hidden" name="note" value="">
      <?php if ($auto && $w['status'] !== 'processing'): ?><button class="btn sm" name="action" value="pay"><?= $w['status'] === 'failed' ? 'Retry' : 'Pay now' ?></button><?php endif; ?>
      <button class="btn <?= $auto ? 'ghost' : '' ?> sm" name="action" value="manual" onclick="return confirm('Confirm you have transferred <?= e(naira($w['net_kobo'])) ?> to this account?')">Mark paid</button>
      <button class="btn danger ghost sm" name="action" value="reject" onclick="const r=prompt('Reason (shown to the payee):','Account details could not be verified'); if(!r) return false; this.form.note.value=r;">Reject</button>
    </form><?php endif; ?></td>
</tr>
<?php endforeach; ?>
<?php if (!$rows): ?><tr><td colspan="8"><div class="empty"><?= icon('up') ?><div>No withdrawals in this view.</div></div></td></tr><?php endif; ?>
</tbody></table></div><?= $pager ?></div>
<?php layout_end();
