<?php
require __DIR__ . '/_init.php';
$me = require_admin(['super']);

handle_post(function ($in) use ($me) {
    $aid = (int) $me['id'];
    switch ($in['action'] ?? '') {
        case 'create':
            $email = strtolower(trim((string) $in['email']));
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) throw new ApiException('Enter a valid email');
            if (strlen((string) $in['password']) < 8) throw new ApiException('Password must be at least 8 characters');
            if (DB::value('SELECT 1 FROM admins WHERE email = ?', [$email])) throw new ApiException('An admin with that email exists');
            $id = DB::insert('admins', ['name' => trim((string) $in['name']), 'email' => $email, 'password_hash' => password_hash((string) $in['password'], PASSWORD_DEFAULT),
                'role' => in_array($in['role'], ['super', 'ops', 'support'], true) ? $in['role'] : 'support']);
            Mailer::send($email, 'Your Dyspatch admin access', Mailer::template('You have admin access', '<p>' . e($me['name']) . ' added you to the Dyspatch admin as <b>' . e($in['role']) . '</b>. Sign in with this email and the password they shared with you, then change it.</p>', 'Sign in', app_url('admin/login.php')));
            audit($aid, 'admin.create', 'admin', $id, $email);
            return 'Admin added.';
        case 'toggle':
            if ((int) $in['id'] === $aid) throw new ApiException("You can't deactivate yourself");
            DB::query('UPDATE admins SET is_active = 1 - is_active WHERE id = ?', [(int) $in['id']]);
            audit($aid, 'admin.toggle', 'admin', (int) $in['id']);
            return 'Admin updated.';
        case 'role':
            if ((int) $in['id'] === $aid) throw new ApiException("You can't change your own role");
            DB::update('admins', ['role' => $in['role']], 'id = ?', [(int) $in['id']]);
            audit($aid, 'admin.role', 'admin', (int) $in['id'], $in['role']);
            return 'Role updated.';
        case 'password':
            if (strlen((string) $in['password']) < 8) throw new ApiException('Password must be at least 8 characters');
            if (!password_verify((string) $in['current'], $me['password_hash'])) throw new ApiException('Current password is incorrect');
            DB::update('admins', ['password_hash' => password_hash((string) $in['password'], PASSWORD_DEFAULT)], 'id = ?', [$aid]);
            audit($aid, 'admin.password', 'admin', $aid);
            return 'Your password has been changed.';
    }
    return null;
});

$admins = DB::all('SELECT * FROM admins ORDER BY is_active DESC, id');
[$logs, $pager] = paginate('SELECT l.*, a.name FROM audit_logs l LEFT JOIN admins a ON a.id = l.admin_id ORDER BY l.id DESC', [], 30);
$links = ['order' => 'order.php?id=', 'rider' => 'rider.php?id=', 'user' => 'customer.php?id='];

layout_start('Admins & logs', 'admins', 'Super admins manage settings and people. Ops handle orders and money. Support can view and update orders.',
    '<button class="btn ghost" data-open="dlgPw">Change my password</button><button class="btn" data-open="dlgAdmin">' . icon('plus') . ' Add admin</button>');
?>
<div class="card"><div class="table-wrap"><table class="t"><thead><tr><th>Admin</th><th>Role</th><th>Status</th><th>Last sign-in</th><th></th></tr></thead><tbody>
<?php foreach ($admins as $a): ?>
<tr><td><div class="who"><?= avatar($a['name']) ?><div><div class="strong"><?= e($a['name']) ?><?= (int) $a['id'] === (int) $me['id'] ? ' <span class="faint small">(you)</span>' : '' ?></div><div class="sub"><?= e($a['email']) ?></div></div></div></td>
  <td><?php if ((int) $a['id'] !== (int) $me['id']): ?><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="role"><input type="hidden" name="id" value="<?= $a['id'] ?>"><select class="input" name="role" onchange="this.form.submit()" style="width:auto;padding:6px 10px"><?php foreach (['super' => 'Super admin', 'ops' => 'Operations', 'support' => 'Support'] as $k => $l): ?><option value="<?= $k ?>" <?= $a['role'] === $k ? 'selected' : '' ?>><?= $l ?></option><?php endforeach; ?></select></form><?php else: ?>Super admin<?php endif; ?></td>
  <td><?= badge($a['is_active'] ? 'active' : 'suspended', $a['is_active'] ? 'Active' : 'Deactivated') ?></td>
  <td class="muted small"><?= time_ago($a['last_login_at']) ?></td>
  <td class="right"><?php if ((int) $a['id'] !== (int) $me['id']): ?><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="toggle"><input type="hidden" name="id" value="<?= $a['id'] ?>"><button class="btn ghost sm"><?= $a['is_active'] ? 'Deactivate' : 'Reactivate' ?></button></form><?php endif; ?></td></tr>
<?php endforeach; ?>
</tbody></table></div></div>

<div class="card"><div class="card-h"><h2>Activity log</h2></div><div class="table-wrap"><table class="t"><thead><tr><th>When</th><th>Admin</th><th>Action</th><th>Target</th><th>Details</th><th>IP</th></tr></thead><tbody>
<?php foreach ($logs as $l): ?>
<tr><td class="muted small nowrap"><?= date('j M, H:i', strtotime($l['created_at'])) ?></td><td><?= e($l['name'] ?: 'System') ?></td><td class="mono small"><?= e($l['action']) ?></td>
  <td class="small"><?= $l['entity'] ? (isset($links[$l['entity']]) && $l['entity_id'] ? '<a class="green" href="' . $links[$l['entity']] . $l['entity_id'] . '">' . e($l['entity']) . ' #' . $l['entity_id'] . '</a>' : e($l['entity']) . ($l['entity_id'] ? ' #' . $l['entity_id'] : '')) : '—' ?></td>
  <td class="small"><?= e($l['details']) ?></td><td class="mono small faint"><?= e($l['ip']) ?></td></tr>
<?php endforeach; ?>
</tbody></table></div><?= $pager ?></div>

<dialog id="dlgAdmin"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="create">
  <div class="d-h"><h3>Add admin</h3><button type="button" class="x" data-close>×</button></div>
  <div class="d-b"><label class="f">Name<input class="input" name="name" required></label><label class="f">Email<input class="input" type="email" name="email" required></label>
    <label class="f">Temporary password<input class="input" name="password" required minlength="8"></label>
    <label class="f">Role<select class="input" name="role"><option value="support">Support</option><option value="ops">Operations</option><option value="super">Super admin</option></select></label></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Add admin</button></div></form></dialog>
<dialog id="dlgPw"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="password">
  <div class="d-h"><h3>Change password</h3><button type="button" class="x" data-close>×</button></div>
  <div class="d-b"><label class="f">Current password<input class="input" type="password" name="current" required></label><label class="f">New password<input class="input" type="password" name="password" required minlength="8"></label></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Update</button></div></form></dialog>
<?php layout_end();
