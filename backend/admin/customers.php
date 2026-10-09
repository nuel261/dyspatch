<?php
require __DIR__ . '/_init.php';
require_admin();
$q = trim((string) ($_GET['q'] ?? ''));
$f = $_GET['f'] ?? '';
$where = ['1=1'];
$p = [];
if ($q !== '') { $where[] = '(u.first_name LIKE ? OR u.last_name LIKE ? OR u.phone LIKE ? OR u.email LIKE ?)'; array_push($p, "%$q%", "%$q%", "%$q%", "%$q%"); }
if ($f === 'business') $where[] = 'u.business_verified = 1';
if ($f === 'suspended') $where[] = "u.status = 'suspended'";

[$rows, $pager, $total] = paginate("SELECT u.*, w.balance_kobo,
    (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) orders,
    (SELECT COALESCE(SUM(fee_kobo),0) FROM orders o WHERE o.user_id = u.id AND o.status = 'delivered') spent,
    (SELECT MAX(created_at) FROM orders o WHERE o.user_id = u.id) last_order
    FROM users u LEFT JOIN wallets w ON w.owner_type = 'user' AND w.owner_id = u.id
    WHERE " . implode(' AND ', $where) . ' ORDER BY u.id DESC', $p);
$c = DB::row("SELECT COUNT(*) total, SUM(business_verified=1) biz, SUM(status='suspended') sus, SUM(DATE(created_at)=CURDATE()) today FROM users");

layout_start('Customers', 'customers', number_format((int) $c['total']) . ' customers · ' . (int) $c['today'] . ' joined today');
?>
<div class="row between">
  <div class="chips"><?php foreach (['' => ['All', $c['total']], 'business' => ['Verified businesses', $c['biz']], 'suspended' => ['Suspended', $c['sus']]] as $k => [$l, $n]): ?><a class="chip <?= $f === $k ? 'on' : '' ?>" href="?f=<?= $k ?>"><?= $l ?><span class="n"><?= (int) $n ?></span></a><?php endforeach; ?></div>
  <form class="filters"><input type="hidden" name="f" value="<?= e($f) ?>"><input class="input" name="q" value="<?= e($q) ?>" placeholder="Name, phone or email"><button class="btn ghost sm">Search</button></form>
</div>
<div class="card"><div class="table-wrap"><table class="t"><thead><tr><th>Customer</th><th>Email</th><th>Orders</th><th class="right">Spent</th><th class="right">Wallet</th><th>Last order</th><th>Joined</th></tr></thead><tbody>
<?php foreach ($rows as $u): $name = trim($u['first_name'] . ' ' . $u['last_name']) ?: 'New customer'; ?>
  <tr class="link" data-href="customer.php?id=<?= $u['id'] ?>">
    <td><div class="who"><?= avatar($name, $u['avatar']) ?><div><div class="strong"><?= e($name) ?> <?= $u['business_verified'] ? badge('verified', 'Business') : '' ?><?= $u['status'] === 'suspended' ? badge('suspended', 'Suspended') : '' ?></div><div class="sub"><?= e($u['phone'] ?: '—') ?></div></div></div></td>
    <td class="small"><?= e($u['email'] ?: '—') ?></td><td><?= number_format((int) $u['orders']) ?></td>
    <td class="right nowrap"><?= naira($u['spent'], false) ?></td><td class="right nowrap"><?= naira($u['balance_kobo'] ?? 0) ?></td>
    <td class="muted small nowrap"><?= time_ago($u['last_order']) ?></td><td class="muted small nowrap"><?= date('j M Y', strtotime($u['created_at'])) ?></td>
  </tr>
<?php endforeach; ?>
<?php if (!$rows): ?><tr><td colspan="7"><div class="empty"><?= icon('users') ?><div>No customers found.</div></div></td></tr><?php endif; ?>
</tbody></table></div><?= $pager ?></div>
<?php layout_end();
