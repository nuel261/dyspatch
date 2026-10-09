<?php
require __DIR__ . '/_init.php';
$admin = require_admin(['super', 'ops']);

handle_post(function ($in) use ($admin) {
    $aid = (int) $admin['id'];
    $id = (int) ($in['id'] ?? 0);
    $note = trim((string) ($in['note'] ?? ''));
    switch ($in['action'] ?? '') {
        case 'biz_approve':
            $b = DB::row('SELECT * FROM business_verifications WHERE id = ?', [$id]);
            if (!$b) throw new ApiException('Not found');
            DB::update('business_verifications', ['status' => 'verified', 'reviewed_at' => now(), 'note' => $note ?: null], 'id = ?', [$id]);
            DB::update('users', ['business_verified' => 1], 'id = ?', [$b['user_id']]);
            Notifier::notify('user', (int) $b['user_id'], 'system', 'Business verified', "{$b['business_name']} is now a verified business on Dyspatch.", ['type' => 'business_verification']);
            audit($aid, 'business.approve', 'user', (int) $b['user_id'], $b['business_name']);
            return 'Business verified.';
        case 'biz_reject':
            $b = DB::row('SELECT * FROM business_verifications WHERE id = ?', [$id]);
            if (!$b) throw new ApiException('Not found');
            DB::update('business_verifications', ['status' => 'rejected', 'reviewed_at' => now(), 'note' => $note ?: 'Documents could not be verified'], 'id = ?', [$id]);
            Notifier::notify('user', (int) $b['user_id'], 'system', 'Business verification unsuccessful', ($note ?: 'We could not verify your documents.') . ' You can resubmit from Settings.', ['type' => 'business_verification']);
            audit($aid, 'business.reject', 'user', (int) $b['user_id'], $note);
            return 'Verification rejected.';
        case 'rider_approve':
            DB::update('riders', ['kyc_status' => 'verified', 'status' => 'active'], "id = ? AND status <> 'suspended'", [$id]);
            Notifier::notify('rider', $id, 'system', "You're verified!", 'Your ID has been verified. Go online to start receiving delivery requests.', ['type' => 'kyc']);
            audit($aid, 'rider.kyc_approve', 'rider', $id);
            return 'Rider verified.';
        case 'rider_reject':
            DB::update('riders', ['kyc_status' => 'rejected'], 'id = ?', [$id]);
            Notifier::notify('rider', $id, 'system', 'Verification unsuccessful', ($note ?: 'We could not verify your ID.') . ' Please resubmit in the app.', ['type' => 'kyc']);
            audit($aid, 'rider.kyc_reject', 'rider', $id, $note);
            return 'Rider verification rejected.';
    }
    return null;
});

$tab = $_GET['tab'] ?? 'riders';
$riders = DB::all("SELECT r.*, z.name zone_name FROM riders r LEFT JOIN zones z ON z.id = r.zone_id WHERE r.kyc_status = 'submitted' ORDER BY r.id");
$biz = DB::all("SELECT b.*, u.first_name, u.last_name, u.phone, u.email FROM business_verifications b JOIN users u ON u.id = b.user_id WHERE b.status = 'pending' ORDER BY b.id");
$recent = DB::all("SELECT b.*, u.first_name, u.last_name FROM business_verifications b JOIN users u ON u.id = b.user_id WHERE b.status <> 'pending' ORDER BY b.reviewed_at DESC LIMIT 10");
$provider = Settings::get('kyc_provider', 'manual');

layout_start('Verifications', 'verifications', 'Rider ID checks (provider: <b>' . e(ucfirst($provider)) . '</b>) and business verifications awaiting review.');
?>
<div class="chips"><a class="chip <?= $tab === 'riders' ? 'on' : '' ?>" href="?tab=riders">Rider IDs<span class="n"><?= count($riders) ?></span></a><a class="chip <?= $tab === 'business' ? 'on' : '' ?>" href="?tab=business">Businesses<span class="n"><?= count($biz) ?></span></a></div>

<?php if ($tab === 'riders'): ?>
<div class="grid g2">
<?php foreach ($riders as $r): $name = trim($r['first_name'] . ' ' . $r['last_name']) ?: 'Unnamed rider'; ?>
  <div class="card">
    <div class="card-h"><div class="who"><?= avatar($name, $r['photo']) ?><div><a class="strong" href="rider.php?id=<?= $r['id'] ?>"><?= e($name) ?></a><div class="muted small"><?= e($r['phone']) ?> · <?= e(ucfirst($r['vehicle_type'])) ?> · <?= e($r['zone_name'] ?: 'No zone') ?></div></div></div></div>
    <div class="card-b grid g2">
      <dl class="kv" style="grid-template-columns:90px 1fr"><dt>ID type</dt><dd><?= e(strtoupper(str_replace('_', ' ', (string) $r['id_type']))) ?></dd><dt>Number</dt><dd class="mono"><?= e($r['id_number']) ?></dd><dt>Plate</dt><dd class="mono"><?= e($r['plate'] ?: '—') ?></dd></dl>
      <?php if ($r['id_document']): ?><a href="<?= e(public_file($r['id_document'])) ?>" target="_blank"><img src="<?= e(public_file($r['id_document'])) ?>" alt="ID" style="width:100%;height:130px;object-fit:cover;border-radius:12px;border:1px solid var(--border)"></a><?php else: ?><div class="callout">No document image.</div><?php endif; ?>
    </div>
    <form method="post" class="card-b row" style="border-top:1px solid var(--border)"><?= csrf_field() ?><input type="hidden" name="id" value="<?= $r['id'] ?>">
      <input class="input" name="note" placeholder="Reason if rejecting" style="flex:1;min-width:160px">
      <button class="btn danger ghost sm" name="action" value="rider_reject">Reject</button><button class="btn sm" name="action" value="rider_approve"><?= icon('check') ?> Approve</button>
    </form>
  </div>
<?php endforeach; ?>
</div>
<?php if (!$riders): ?><div class="card"><div class="empty"><?= icon('shield') ?><div>No rider IDs waiting for review.</div></div></div><?php endif; ?>

<?php else: ?>
<div class="grid g2">
<?php foreach ($biz as $b): ?>
  <div class="card">
    <div class="card-h"><div><h3><?= e($b['business_name']) ?></h3><a class="muted small" href="customer.php?id=<?= $b['user_id'] ?>"><?= e(trim($b['first_name'] . ' ' . $b['last_name'])) ?> · <?= e($b['phone'] ?: $b['email']) ?></a></div></div>
    <div class="card-b grid g2">
      <dl class="kv" style="grid-template-columns:90px 1fr"><dt>Reg. no.</dt><dd class="mono"><?= e($b['reg_number']) ?></dd><dt>Address</dt><dd><?= e($b['address']) ?></dd><dt>Submitted</dt><dd><?= time_ago($b['created_at']) ?></dd></dl>
      <?php if ($b['id_document']): ?><a href="<?= e(public_file($b['id_document'])) ?>" target="_blank"><img src="<?= e(public_file($b['id_document'])) ?>" alt="ID" style="width:100%;height:130px;object-fit:cover;border-radius:12px;border:1px solid var(--border)"></a><?php endif; ?>
    </div>
    <form method="post" class="card-b row" style="border-top:1px solid var(--border)"><?= csrf_field() ?><input type="hidden" name="id" value="<?= $b['id'] ?>">
      <input class="input" name="note" placeholder="Note / reason" style="flex:1;min-width:160px">
      <button class="btn danger ghost sm" name="action" value="biz_reject">Reject</button><button class="btn sm" name="action" value="biz_approve"><?= icon('check') ?> Verify</button>
    </form>
  </div>
<?php endforeach; ?>
</div>
<?php if (!$biz): ?><div class="card"><div class="empty"><?= icon('filecheck') ?><div>No business verifications pending.</div></div></div><?php endif; ?>
<?php if ($recent): ?><div class="card"><div class="card-h"><h3>Recently reviewed</h3></div><div class="table-wrap"><table class="t"><tbody>
<?php foreach ($recent as $b): ?><tr><td class="strong"><?= e($b['business_name']) ?></td><td class="muted small"><?= e(trim($b['first_name'] . ' ' . $b['last_name'])) ?></td><td><?= badge($b['status']) ?></td><td class="muted small"><?= e($b['note'] ?: '') ?></td><td class="muted small"><?= time_ago($b['reviewed_at']) ?></td></tr><?php endforeach; ?>
</tbody></table></div></div><?php endif; ?>
<?php endif; ?>
<?php layout_end();
