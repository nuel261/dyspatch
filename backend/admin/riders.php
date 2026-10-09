<?php
require __DIR__ . '/_init.php';
$admin = require_admin();

handle_post(function ($in) use ($admin) {
    if (($in['action'] ?? '') !== 'create') return null;
    $phone = normalize_phone((string) ($in['phone'] ?? ''));
    if (!preg_match('/^\+\d{10,15}$/', $phone)) throw new ApiException('Enter a valid phone number');
    if (DB::value('SELECT 1 FROM riders WHERE phone = ?', [$phone])) throw new ApiException('A rider with this phone already exists');
    $id = DB::insert('riders', [
        'first_name' => trim((string) $in['first_name']), 'last_name' => trim((string) $in['last_name']), 'phone' => $phone,
        'email' => filter_var($in['email'] ?? '', FILTER_VALIDATE_EMAIL) ?: null, 'vehicle_type' => $in['vehicle_type'] ?? 'bike',
        'plate' => strtoupper(trim((string) ($in['plate'] ?? ''))) ?: null, 'zone_id' => ((int) ($in['zone_id'] ?? 0)) ?: null,
    ]);
    Wallet::get('rider', $id);
    audit((int) $admin['id'], 'rider.create', 'rider', $id, $phone);
    redirect('rider.php?id=' . $id);
});

$f = $_GET['f'] ?? '';
$q = trim((string) ($_GET['q'] ?? ''));
$where = ['1=1'];
$p = [];
if ($f === 'online') $where[] = "r.is_online = 1 AND r.location_updated_at > NOW() - INTERVAL 10 MINUTE";
elseif ($f === 'kyc') $where[] = "r.kyc_status = 'submitted'";
elseif (in_array($f, ['pending', 'active', 'suspended'], true)) { $where[] = 'r.status = ?'; $p[] = $f; }
if ($q !== '') { $where[] = '(r.first_name LIKE ? OR r.last_name LIKE ? OR r.phone LIKE ? OR r.plate LIKE ?)'; array_push($p, "%$q%", "%$q%", "%$q%", "%$q%"); }

[$rows, $pager, $total] = paginate('SELECT r.*, z.name zone_name, w.balance_kobo,
    (SELECT COUNT(*) FROM orders o WHERE o.rider_id = r.id AND o.status = \'delivered\') delivered,
    (SELECT COUNT(*) FROM orders o WHERE o.rider_id = r.id AND o.status IN (\'matched\',\'picked_up\',\'en_route\',\'arrived\')) busy
    FROM riders r LEFT JOIN zones z ON z.id = r.zone_id LEFT JOIN wallets w ON w.owner_type = \'rider\' AND w.owner_id = r.id
    WHERE ' . implode(' AND ', $where) . ' ORDER BY r.is_online DESC, r.id DESC', $p);

$counts = DB::row("SELECT COUNT(*) total, SUM(status='active') active, SUM(status='pending') pending, SUM(status='suspended') suspended,
    SUM(kyc_status='submitted') kyc, SUM(is_online=1 AND location_updated_at > NOW() - INTERVAL 10 MINUTE) online FROM riders");
$zones = DB::all('SELECT id, name FROM zones ORDER BY name');

layout_start('Riders', 'riders', 'Independent riders on the platform. Suspensions are platform-policy actions, not employment decisions.',
    '<button class="btn" data-open="dlgRider">' . icon('plus') . ' Add rider</button>');
?>
<div class="row between">
  <div class="chips">
    <?php foreach (['' => ['All', $counts['total']], 'online' => ['Online now', $counts['online']], 'kyc' => ['Awaiting KYC', $counts['kyc']], 'active' => ['Active', $counts['active']], 'pending' => ['Pending', $counts['pending']], 'suspended' => ['Suspended', $counts['suspended']]] as $k => [$l, $n]): ?>
      <a class="chip <?= $f === $k ? 'on' : '' ?>" href="?f=<?= $k ?>"><?= $l ?><span class="n"><?= (int) $n ?></span></a>
    <?php endforeach; ?>
  </div>
  <form class="filters"><input type="hidden" name="f" value="<?= e($f) ?>"><input class="input" name="q" value="<?= e($q) ?>" placeholder="Name, phone or plate"><button class="btn ghost sm">Search</button></form>
</div>
<div class="card"><div class="table-wrap">
<table class="t"><thead><tr><th>Rider</th><th>Vehicle</th><th>Zone</th><th>Verification</th><th>Status</th><th>Deliveries</th><th>Rating</th><th class="right">Wallet</th><th>Last seen</th></tr></thead><tbody>
<?php foreach ($rows as $r): $name = trim($r['first_name'] . ' ' . $r['last_name']) ?: 'Unnamed rider'; $on = $r['is_online'] && $r['location_updated_at'] && strtotime($r['location_updated_at']) > time() - 600; ?>
  <tr class="link" data-href="rider.php?id=<?= $r['id'] ?>">
    <td><div class="who"><?= avatar($name, $r['photo']) ?><div><div class="strong"><?= e($name) ?></div><div class="sub"><?= e($r['phone']) ?></div></div></div></td>
    <td><?= e(ucfirst($r['vehicle_type'])) ?><div class="sub mono"><?= e($r['plate'] ?: '—') ?></div></td>
    <td><?= e($r['zone_name'] ?: '—') ?></td>
    <td><?= badge($r['kyc_status'], ['none' => 'Not submitted', 'submitted' => 'Awaiting review', 'verified' => 'Verified', 'rejected' => 'Rejected'][$r['kyc_status']]) ?></td>
    <td><?= badge($r['status'], ucfirst($r['status'])) ?> <?= $on ? badge($r['busy'] ? 'en_route' : 'online', $r['busy'] ? 'On delivery' : 'Online') : '' ?></td>
    <td><?= number_format((int) $r['delivered']) ?></td>
    <td>★ <?= number_format((float) $r['rating'], 1) ?> <span class="faint small">(<?= (int) $r['rating_count'] ?>)</span></td>
    <td class="right nowrap"><?= naira($r['balance_kobo'] ?? 0) ?></td>
    <td class="muted small nowrap"><?= time_ago($r['location_updated_at']) ?></td>
  </tr>
<?php endforeach; ?>
<?php if (!$rows): ?><tr><td colspan="9"><div class="empty"><?= icon('bike') ?><div>No riders match this view.</div></div></td></tr><?php endif; ?>
</tbody></table></div><?= $pager ?></div>

<dialog id="dlgRider"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="create">
  <div class="d-h"><h3>Add rider</h3><button type="button" class="x" data-close>×</button></div>
  <div class="d-b"><div class="form-grid">
    <label class="f">First name<input class="input" name="first_name" required></label>
    <label class="f">Last name<input class="input" name="last_name" required></label>
    <label class="f">Phone<input class="input" name="phone" required placeholder="0803…"></label>
    <label class="f">Email<input class="input" name="email" type="email"></label>
    <label class="f">Vehicle<select class="input" name="vehicle_type"><option value="bike">Motorbike</option><option value="bicycle">Bicycle</option><option value="car">Car</option><option value="truck">Truck</option></select></label>
    <label class="f">Plate number<input class="input" name="plate"></label>
    <label class="f full">Zone<select class="input" name="zone_id"><option value="">—</option><?php foreach ($zones as $z): ?><option value="<?= $z['id'] ?>"><?= e($z['name']) ?></option><?php endforeach; ?></select></label>
  </div><p class="muted small">The rider signs in to the Rider app with this phone number, then completes ID verification.</p></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Add rider</button></div></form></dialog>
<?php layout_end();
