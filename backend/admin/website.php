<?php
/** Admin → Website content: what https://dyspatch.com.ng shows (contact, socials, store links). */
require __DIR__ . '/_init.php';
$admin = require_admin(['super', 'ops']);

handle_post(function ($in) use ($admin) {
    $changed = [];
    foreach (Website::flat() as $key => [$label, $type]) {
        if (!array_key_exists($key, $in)) continue;
        $v = trim((string) $in[$key]);
        if ($v !== '' && $type === 'url' && !filter_var($v, FILTER_VALIDATE_URL)) throw new ApiException("$label must be a full link starting with https://");
        if ($v !== '' && $type === 'email' && !filter_var($v, FILTER_VALIDATE_EMAIL)) throw new ApiException("$label must be a valid email address");
        if ($key === 'site_url') {
            if ($v === '') throw new ApiException('Website address is required');
            $v = rtrim($v, '/');
        }
        if ((string) Settings::get($key, '') !== $v) { Settings::set($key, $v); $changed[] = $label; }
    }
    if ($changed) audit((int) $admin['id'], 'website.update', 'settings', null, implode(', ', $changed));
    return $changed ? 'Saved. The website picks up the change within a minute.' : 'Nothing changed.';
});

$posts = DB::row("SELECT SUM(status='published') p, SUM(status='draft') d FROM blog_posts");
layout_start('Website content', 'website', 'Contact details, social links and app store links shown on ' . e(parse_url(site_url(), PHP_URL_HOST)) . '. Changes appear without rebuilding the site.',
    '<a class="btn ghost" target="_blank" rel="noopener" href="' . e(site_url()) . '">' . icon('globe') . ' Open website</a>', false);
?>
<div class="grid g3" style="margin-bottom:16px">
  <a class="card" href="blog.php"><div class="card-b"><div class="muted small">Blog</div><h3 style="margin-top:4px"><?= (int) $posts['p'] ?> published · <?= (int) $posts['d'] ?> drafts</h3><div class="small" style="color:var(--brand-600);margin-top:6px">Manage posts →</div></div></a>
  <a class="card" href="<?= e(site_url('track')) ?>" target="_blank" rel="noopener"><div class="card-b"><div class="muted small">Public tracking</div><h3 style="margin-top:4px"><?= e(parse_url(site_url(), PHP_URL_HOST)) ?>/track</h3><div class="small muted" style="margin-top:6px">Reads orders live from this database</div></div></a>
  <a class="card" href="settings.php"><div class="card-b"><div class="muted small">Mobile app</div><h3 style="margin-top:4px">Pricing, OTP, payments…</h3><div class="small" style="color:var(--brand-600);margin-top:6px">App settings →</div></div></a>
</div>

<form method="post"><?= csrf_field() ?>
<?php foreach (Website::FIELDS as $group => $fields): ?>
  <div class="card">
    <div class="card-h"><h2><?= e($group) ?></h2><button class="btn sm">Save</button></div>
    <div class="card-b form-grid">
    <?php foreach ($fields as $key => [$label, $type, $default, $hint]): $v = (string) Settings::get($key, $default); ?>
      <?php if ($type === 'textarea'): ?>
        <label class="f full"><?= e($label) ?><textarea class="input" name="<?= $key ?>" rows="2"><?= e($v) ?></textarea><?php if ($hint): ?><span class="hint"><?= e($hint) ?></span><?php endif; ?></label>
      <?php else: ?>
        <label class="f<?= $key === 'site_announcement' ? ' full' : '' ?>"><?= e($label) ?><input class="input<?= $type === 'url' ? ' mono' : '' ?>" name="<?= $key ?>" value="<?= e($v) ?>" <?= $type === 'email' ? 'type="email"' : ($type === 'url' ? 'type="url" placeholder="https://"' : '') ?>><?php if ($hint): ?><span class="hint"><?= e($hint) ?></span><?php endif; ?></label>
      <?php endif; ?>
    <?php endforeach; ?>
    </div>
  </div>
<?php endforeach; ?>
</form>
<?php layout_end();
