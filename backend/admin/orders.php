<?php
require __DIR__ . '/_init.php';
require_admin();

$status = $_GET['status'] ?? '';
$zone = (int) ($_GET['zone'] ?? 0);
$q = trim((string) ($_GET['q'] ?? ''));
$from = $_GET['from'] ?? '';
$to = $_GET['to'] ?? '';

$where = ['1=1'];
$p = [];
if ($status === 'active') $where[] = "o.status IN ('matched','picked_up','en_route','arrived')";
elseif ($status !== '' && isset(Orders::LABELS[$status])) { $where[] = 'o.status = ?'; $p[] = $status; }
if ($zone) { $where[] = 'o.zone_id = ?'; $p[] = $zone; }
if ($q !== '') {
    $where[] = '(o.track_id LIKE ? OR o.order_no LIKE ? OR o.recipient_name LIKE ? OR o.recipient_phone LIKE ? OR o.sender_phone LIKE ? OR u.phone LIKE ? OR EXISTS (SELECT 1 FROM order_items i WHERE i.order_id = o.id AND i.item_code LIKE ?))';
    array_push($p, ...array_fill(0, 7, "%$q%"));
}
if ($from) { $where[] = 'DATE(o.created_at) >= ?'; $p[] = $from; }
if ($to) { $where[] = 'DATE(o.created_at) <= ?'; $p[] = $to; }

$sql = 'SELECT o.*, r.first_name rf, r.last_name rl, u.first_name uf, u.last_name ul, u.phone up, z.name zone_name,
        (SELECT COALESCE(SUM(quantity),0) FROM order_items i WHERE i.order_id = o.id) items
        FROM orders o LEFT JOIN riders r ON r.id = o.rider_id LEFT JOIN users u ON u.id = o.user_id LEFT JOIN zones z ON z.id = o.zone_id
        WHERE ' . implode(' AND ', $where) . ' ORDER BY o.id DESC';

if (($_GET['export'] ?? '') === 'csv') {
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment; filename="dyspatch-orders-' . date('Ymd-His') . '.csv"');
    $out = fopen('php://output', 'w');
    fputcsv($out, ['Order', 'Track ID', 'Status', 'Zone', 'Customer', 'Customer phone', 'Pickup', 'Drop-off', 'Recipient', 'Recipient phone', 'Rider', 'Items', 'Distance km', 'Fee NGN', 'Commission NGN', 'Payment', 'Created', 'Delivered']);
    foreach (DB::all($sql . ' LIMIT 20000', $p) as $o) {
        fputcsv($out, [$o['order_no'], $o['track_id'], $o['status'], $o['zone_name'], trim($o['uf'] . ' ' . $o['ul']), $o['up'], $o['pickup_address'], $o['dropoff_address'],
            $o['recipient_name'], $o['recipient_phone'], trim($o['rf'] . ' ' . $o['rl']), $o['items'], $o['distance_km'], $o['fee_kobo'] / 100, $o['commission_kobo'] / 100,
            $o['payment_method'] . '/' . $o['payment_status'], $o['created_at'], $o['delivered_at']]);
    }
    exit;
}

[$rows, $pager, $total] = paginate($sql, $p, 25);
$counts = [];
foreach (DB::all('SELECT status, COUNT(*) n FROM orders GROUP BY status') as $r) $counts[$r['status']] = (int) $r['n'];
$activeCount = array_sum(array_intersect_key($counts, array_flip(Orders::ACTIVE)));
$zones = DB::all('SELECT id, name FROM zones ORDER BY name');
$qs = fn(array $over) => '?' . http_build_query(array_merge($_GET, $over, ['page' => null]));

layout_start('Orders', 'orders', number_format($total) . ' deliveries match your filters.', '<a class="btn" href="order_new.php">' . icon('plus') . ' New delivery</a>');
?>
<div class="chips">
  <a class="chip <?= $status === '' ? 'on' : '' ?>" href="<?= e($qs(['status' => null])) ?>">All<span class="n"><?= array_sum($counts) ?></span></a>
  <a class="chip <?= $status === 'active' ? 'on' : '' ?>" href="<?= e($qs(['status' => 'active'])) ?>">Active<span class="n"><?= $activeCount ?></span></a>
  <?php foreach (Orders::LABELS as $k => $l): ?><a class="chip <?= $status === $k ? 'on' : '' ?>" href="<?= e($qs(['status' => $k])) ?>"><?= e($l) ?><span class="n"><?= $counts[$k] ?? 0 ?></span></a><?php endforeach; ?>
</div>

<div class="card">
  <div class="card-h">
    <form class="filters" method="get" style="flex:1">
      <input type="hidden" name="status" value="<?= e($status) ?>">
      <input class="input" name="q" value="<?= e($q) ?>" placeholder="Track ID, item code, name or phone" style="min-width:240px">
      <select class="input" name="zone"><option value="">All zones</option><?php foreach ($zones as $z): ?><option value="<?= $z['id'] ?>" <?= $zone === (int) $z['id'] ? 'selected' : '' ?>><?= e($z['name']) ?></option><?php endforeach; ?></select>
      <input class="input" type="date" name="from" value="<?= e($from) ?>" title="From">
      <input class="input" type="date" name="to" value="<?= e($to) ?>" title="To">
      <button class="btn sm">Filter</button>
      <?php if ($q || $zone || $from || $to): ?><a class="btn ghost sm" href="<?= e('?status=' . urlencode($status)) ?>">Clear</a><?php endif; ?>
    </form>
    <a class="btn ghost sm" href="<?= e($qs(['export' => 'csv'])) ?>">Export CSV</a>
  </div>
  <div class="table-wrap">
    <table class="t">
      <thead><tr><th>Track ID</th><th>Route</th><th>Customer</th><th>Rider</th><th>Items</th><th>Status</th><th class="right">Fee</th><th>Created</th></tr></thead>
      <tbody>
      <?php foreach ($rows as $o): ?>
        <tr class="link" data-href="order.php?id=<?= $o['id'] ?>">
          <td><?= tid($o['track_id']) ?><div class="sub"><?= e($o['order_no']) ?> · <?= e($o['zone_name'] ?? '—') ?></div></td>
          <td style="max-width:280px"><div class="strong"><?= e(Orders::shortRoute($o)) ?></div><div class="sub">To <?= e($o['recipient_name']) ?> · <?= e($o['recipient_phone']) ?></div></td>
          <td><?= $o['user_id'] ? '<a class="strong" href="customer.php?id=' . $o['user_id'] . '">' . e(trim($o['uf'] . ' ' . $o['ul']) ?: $o['up']) . '</a>' : '<span class="muted">' . e($o['sender_name'] ?: 'Walk-in') . '</span>' ?><div class="sub"><?= e(ucfirst($o['channel'])) ?></div></td>
          <td><?= $o['rf'] ? '<a href="rider.php?id=' . $o['rider_id'] . '">' . e($o['rf'] . ' ' . $o['rl']) . '</a>' : '<span class="faint">—</span>' ?></td>
          <td><?= (int) $o['items'] ?></td>
          <td><?= badge($o['status']) ?></td>
          <td class="right"><span class="strong"><?= naira($o['fee_kobo'], false) ?></span><div class="sub"><?= e($o['payment_method']) ?> · <?= e($o['payment_status']) ?></div></td>
          <td class="muted nowrap"><?= date('j M, H:i', strtotime($o['created_at'])) ?></td>
        </tr>
      <?php endforeach; ?>
      <?php if (!$rows): ?><tr><td colspan="8"><div class="empty"><?= icon('search') ?><div>No orders match these filters.</div></div></td></tr><?php endif; ?>
      </tbody>
    </table>
  </div>
  <?= $pager ?>
</div>
<?php layout_end();
