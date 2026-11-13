<?php
/** Admin → Website → Blog posts. Published posts appear on https://dyspatch.com.ng/blog within a minute. */
require __DIR__ . '/_init.php';
$admin = require_admin(['super', 'ops']);

handle_post(function ($in) use ($admin) {
    $p = DB::row('SELECT * FROM blog_posts WHERE id = ?', [(int) ($in['id'] ?? 0)]);
    if (!$p) throw new ApiException('Post not found');
    $act = $in['action'] ?? '';
    if ($act === 'publish') {
        DB::update('blog_posts', ['status' => 'published', 'published_at' => $p['published_at'] ?: now()], 'id = ?', [$p['id']]);
        audit((int) $admin['id'], 'blog.publish', 'blog_post', (int) $p['id'], $p['title']);
        return 'Published. It’s live on the website.';
    }
    if ($act === 'unpublish') {
        DB::update('blog_posts', ['status' => 'draft'], 'id = ?', [$p['id']]);
        audit((int) $admin['id'], 'blog.unpublish', 'blog_post', (int) $p['id'], $p['title']);
        return 'Moved back to drafts — hidden from the website.';
    }
    if ($act === 'feature') {
        DB::update('blog_posts', ['is_featured' => $p['is_featured'] ? 0 : 1], 'id = ?', [$p['id']]);
        return $p['is_featured'] ? 'Removed from Featured.' : 'Added to Featured.';
    }
    if ($act === 'delete') {
        DB::query('DELETE FROM blog_posts WHERE id = ?', [$p['id']]);
        if ($p['cover_image'] && str_starts_with($p['cover_image'], 'storage/uploads/blog/')) @unlink(BASE_PATH . '/' . $p['cover_image']);
        audit((int) $admin['id'], 'blog.delete', 'blog_post', (int) $p['id'], $p['title']);
        return 'Post deleted.';
    }
    return null;
});

$f = $_GET['f'] ?? 'all';
$q = trim((string) ($_GET['q'] ?? ''));
$where = ['1=1'];
$args = [];
if ($f === 'published') $where[] = "status = 'published'";
if ($f === 'draft') $where[] = "status = 'draft'";
if ($f === 'featured') $where[] = 'is_featured = 1';
if ($f === 'empty') $where[] = "(body IS NULL OR body = '')";
if ($q !== '') { $where[] = '(title LIKE ? OR excerpt LIKE ? OR category LIKE ?)'; array_push($args, "%$q%", "%$q%", "%$q%"); }
[$rows, $pager, $total] = paginate('SELECT * FROM blog_posts WHERE ' . implode(' AND ', $where) . ' ORDER BY COALESCE(published_at, created_at) DESC', $args, 25);

$counts = DB::row("SELECT COUNT(*) a, SUM(status = 'published') p, SUM(status = 'draft') d, SUM(is_featured = 1) f, SUM(body IS NULL OR body = '') e FROM blog_posts");

layout_start('Blog posts', 'blog', 'Articles on the website’s Blog page. Featured posts show in the large scrolling row; the rest under Latest.',
    '<a class="btn" href="blog_edit.php">' . icon('plus') . ' New post</a>');
?>
<div class="row between">
  <div class="chips">
    <?php foreach (['all' => ['All', $counts['a']], 'published' => ['Published', $counts['p']], 'draft' => ['Drafts', $counts['d']], 'featured' => ['Featured', $counts['f']], 'empty' => ['No article text', $counts['e']]] as $k => [$label, $n]): ?>
      <a class="chip <?= $f === $k ? 'on' : '' ?>" href="?f=<?= $k ?>"><?= e($label) ?><span class="n"><?= (int) $n ?></span></a>
    <?php endforeach; ?>
  </div>
  <form class="filters"><input type="hidden" name="f" value="<?= e($f) ?>"><input class="input" name="q" value="<?= e($q) ?>" placeholder="Search title or category"><button class="btn ghost sm">Search</button></form>
</div>

<?php if ((int) $counts['e'] > 0 && $f !== 'empty'): ?>
<div class="flash warn"><?= icon('alert') ?><span><?= (int) $counts['e'] ?> post<?= (int) $counts['e'] === 1 ? ' has' : 's have' ?> only a summary. Readers see the summary and cover image until you add the article text. <a href="?f=empty">Show them</a></span></div>
<?php endif; ?>

<div class="card"><div class="table-wrap"><table class="t"><thead><tr><th>Post</th><th>Category</th><th>Status</th><th>Published</th><th>Updated</th><th class="right">Actions</th></tr></thead><tbody>
<?php foreach ($rows as $p): $img = Blog::imageUrl($p['cover_image']); $img = $img && str_starts_with($img, '/') ? site_url($img) : $img; ?>
  <tr>
    <td><a href="blog_edit.php?id=<?= $p['id'] ?>" class="row" style="gap:12px;align-items:center;color:inherit;flex-wrap:nowrap;min-width:320px">
      <span style="width:64px;height:44px;border-radius:8px;background:var(--surface-2) center/cover no-repeat;flex:none<?= $img ? ';background-image:url(' . e($img) . ')' : '' ?>"></span>
      <span><b><?= e($p['title']) ?></b><?= $p['is_featured'] ? ' <span class="badge b-active">Featured</span>' : '' ?><br><span class="muted small"><?= e(mb_strimwidth((string) $p['excerpt'], 0, 90, '…')) ?></span>
      <?php if (trim((string) $p['body']) === ''): ?><br><span class="small" style="color:#B7791F">Summary only — no article text yet</span><?php endif; ?></span></a></td>
    <td><?= e($p['category']) ?></td>
    <td><?= $p['status'] === 'published' ? (strtotime((string) $p['published_at']) > time() ? badge('pending', 'Scheduled') : badge('active', 'Published')) : badge('none', 'Draft') ?></td>
    <td class="small"><?= $p['published_at'] ? date('d M Y', strtotime($p['published_at'])) : '—' ?></td>
    <td class="small muted"><?= date('d M Y, H:i', strtotime($p['updated_at'])) ?></td>
    <td class="right"><div class="row" style="justify-content:flex-end;gap:6px">
      <a class="btn ghost sm" href="blog_edit.php?id=<?= $p['id'] ?>">Edit</a>
      <?php if ($p['status'] === 'published'): ?><a class="btn ghost sm" target="_blank" rel="noopener" href="<?= e(site_url('blog/post?slug=' . urlencode($p['slug']))) ?>" title="View on website"><?= icon('eye') ?></a><?php endif; ?>
      <form method="post"><?= csrf_field() ?><input type="hidden" name="id" value="<?= $p['id'] ?>"><input type="hidden" name="action" value="feature"><button class="btn ghost sm" title="<?= $p['is_featured'] ? 'Remove from Featured' : 'Add to Featured' ?>"><?= $p['is_featured'] ? '★' : '☆' ?></button></form>
      <form method="post"><?= csrf_field() ?><input type="hidden" name="id" value="<?= $p['id'] ?>"><input type="hidden" name="action" value="<?= $p['status'] === 'published' ? 'unpublish' : 'publish' ?>"><button class="btn <?= $p['status'] === 'published' ? 'ghost' : 'soft' ?> sm"><?= $p['status'] === 'published' ? 'Unpublish' : 'Publish' ?></button></form>
    </div></td>
  </tr>
<?php endforeach; ?>
<?php if (!$rows): ?><tr><td colspan="6"><div class="empty"><?= icon('pen') ?><div>No posts here yet. <a href="blog_edit.php">Write one</a>.</div></div></td></tr><?php endif; ?>
</tbody></table></div><?= $pager ?></div>
<?php layout_end();
