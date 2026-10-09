<?php
require __DIR__ . '/_init.php';
require_admin();
$cat = $_GET['cat'] ?? '';
$owner = $_GET['owner'] ?? '';
$q = trim((string) ($_GET['q'] ?? ''));
$from = $_GET['from'] ?? date('Y-m-01');
$to = $_GET['to'] ?? date('Y-m-d');

$where = ['DATE(t.created_at) BETWEEN ? AND ?'];
$p = [$from, $to];
if ($cat !== '') { $where[] = 't.category = ?'; $p[] = $cat; }
if (in_array($owner, ['user', 'rider', 'platform'], true)) { $where[] = 'w.owner_type = ?'; $p[] = $owner; }
if ($q !== '') { $where[] = '(t.reference LIKE ? OR t.description LIKE ? OR o.track_id LIKE ?)'; array_push($p, "%$q%", "%$q%", "%$q%"); }
$sql = 'SELECT t.*, w.owner_type, w.owner_id, o.track_id, o.id oid FROM wallet_transactions t JOIN wallets w ON w.id = t.wallet_id LEFT JOIN orders o ON o.id = t.order_id WHERE ' . implode(' AND ', $where) . ' ORDER BY t.id DESC';

if (($_GET['export'] ?? '') === 'csv') {
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment; filename="dyspatch-transactions-' . $from . '-to-' . $to . '.csv"');
    $out = fopen('php://output', 'w');
    fputcsv($out, ['Date', 'Reference', 'Owner', 'Owner ID', 'Type', 'Category', 'Amount NGN', 'Balance after NGN', 'Description', 'Track ID']);
    foreach (DB::all($sql . ' LIMIT 50000', $p) as $t) fputcsv($out, [$t['created_at'], $t['reference'], $t['owner_type'], $t['owner_id'], $t['type'], $t['category'], $t['amount_kobo'] / 100, $t['balance_after_kobo'] / 100, $t['description'], $t['track_id']]);
    exit;
}
[$rows, $pager] = paginate($sql, $p, 40);
$sum = DB::row("SELECT
    COALESCE(SUM(CASE WHEN t.category='delivery_payment' THEN amount_kobo END),0) gmv,
    COALESCE(SUM(CASE WHEN w.owner_type='platform' AND t.category='commission' THEN amount_kobo END),0) commission,
    COALESCE(SUM(CASE WHEN t.category='topup' THEN amount_kobo END),0) topups,
    COALESCE(SUM(CASE WHEN t.category='withdrawal' THEN amount_kobo END),0) withdrawals
    FROM wallet_transactions t JOIN wallets w ON w.id = t.wallet_id WHERE DATE(t.created_at) BETWEEN ? AND ?", [$from, $to]);
$cash = (int) DB::value("SELECT COALESCE(SUM(fee_kobo),0) FROM orders WHERE payment_method='cash' AND status='delivered' AND DATE(delivered_at) BETWEEN ? AND ?", [$from, $to]);
$float = (int) DB::value("SELECT COALESCE(SUM(balance_kobo),0) FROM wallets WHERE owner_type IN ('user','rider')");
$cats = ['topup' => 'Top-up', 'delivery_payment' => 'Delivery payment', 'delivery_earning' => 'Rider earning', 'commission' => 'Commission', 'withdrawal' => 'Withdrawal', 'withdrawal_fee' => 'Withdrawal fee', 'refund' => 'Refund', 'adjustment' => 'Adjustment'];

layout_start('Transactions', 'transactions', 'Kobo-precise ledger of every wallet movement.', '<a class="btn ghost" href="?' . e(http_build_query(array_merge($_GET, ['export' => 'csv']))) . '">' . icon('down') . ' Export CSV</a>');
?>
<div class="grid g4">
  <div class="card stat"><span class="k">Wallet deliveries (GMV)</span><span class="v"><?= naira($sum['gmv'], false) ?></span><span class="d">+ <?= naira($cash, false) ?> cash collected</span></div>
  <div class="card stat"><span class="k">Platform commission</span><span class="v"><?= naira($sum['commission'], false) ?></span><span class="d">Selected period</span></div>
  <div class="card stat"><span class="k">Top-ups / Withdrawals</span><span class="v small" style="font-size:20px"><?= naira($sum['topups'], false) ?> / <?= naira($sum['withdrawals'], false) ?></span><span class="d">In / out</span></div>
  <div class="card stat dark"><span class="k">Wallet float</span><span class="v"><?= naira($float, false) ?></span><span class="d">Held for customers & riders now</span></div>
</div>
<form class="filters">
  <input class="input" type="date" name="from" value="<?= e($from) ?>"><input class="input" type="date" name="to" value="<?= e($to) ?>">
  <select class="input" name="cat"><option value="">All categories</option><?php foreach ($cats as $k => $l): ?><option value="<?= $k ?>" <?= $cat === $k ? 'selected' : '' ?>><?= $l ?></option><?php endforeach; ?></select>
  <select class="input" name="owner"><option value="">All wallets</option><option value="user" <?= $owner === 'user' ? 'selected' : '' ?>>Customers</option><option value="rider" <?= $owner === 'rider' ? 'selected' : '' ?>>Riders</option><option value="platform" <?= $owner === 'platform' ? 'selected' : '' ?>>Platform</option></select>
  <input class="input" name="q" value="<?= e($q) ?>" placeholder="Reference or Track ID"><button class="btn ghost sm">Filter</button>
</form>
<div class="card"><div class="table-wrap"><table class="t"><thead><tr><th>Date</th><th>Reference</th><th>Wallet</th><th>Category</th><th>Description</th><th class="right">Amount</th><th class="right">Balance after</th></tr></thead><tbody>
<?php foreach ($rows as $t): $href = $t['owner_type'] === 'platform' ? null : ($t['owner_type'] === 'rider' ? 'rider' : 'customer') . '.php?id=' . $t['owner_id']; ?>
<tr><td class="muted small nowrap"><?= date('j M y, H:i', strtotime($t['created_at'])) ?></td><td class="mono small"><?= e($t['reference']) ?></td>
  <td><?= $href ? '<a href="' . $href . '">' . ucfirst($t['owner_type']) . ' #' . $t['owner_id'] . '</a>' : 'Platform' ?></td>
  <td><span class="badge plain"><?= e($cats[$t['category']] ?? $t['category']) ?></span></td>
  <td class="small"><?= e($t['description']) ?><?= $t['track_id'] ? ' · <a href="order.php?id=' . $t['oid'] . '" class="green">' . e($t['track_id']) . '</a>' : '' ?></td>
  <td class="right nowrap <?= $t['type'] === 'credit' ? 'green' : '' ?>" style="font-weight:600"><?= ($t['type'] === 'credit' ? '+' : '−') . naira($t['amount_kobo']) ?></td>
  <td class="right nowrap muted"><?= naira($t['balance_after_kobo']) ?></td></tr>
<?php endforeach; ?>
<?php if (!$rows): ?><tr><td colspan="7"><div class="empty"><?= icon('receipt') ?><div>No transactions in this period.</div></div></td></tr><?php endif; ?>
</tbody></table></div><?= $pager ?></div>
<?php layout_end();
