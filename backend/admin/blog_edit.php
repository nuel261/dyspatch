<?php
/** Admin → Website → Blog → new / edit post. */
require __DIR__ . '/_init.php';
$admin = require_admin(['super', 'ops']);

$id = (int) ($_GET['id'] ?? 0);
$post = $id ? DB::row('SELECT * FROM blog_posts WHERE id = ?', [$id]) : null;
if ($id && !$post) { flash('Post not found', 'err'); redirect('blog.php'); }

handle_post(function ($in) use ($admin, $post) {
    $title = trim((string) ($in['title'] ?? ''));
    if (mb_strlen($title) < 4) throw new ApiException('Give the post a title (at least 4 characters).');
    $status = ($in['status'] ?? 'draft') === 'published' ? 'published' : 'draft';
    $excerpt = trim((string) ($in['excerpt'] ?? ''));
    $body = trim((string) ($in['body'] ?? ''));
    if ($status === 'published' && $excerpt === '') throw new ApiException('Add a short summary before publishing — it’s shown on the blog cards.');

    $slugIn = trim((string) ($in['slug'] ?? ''));
    $slug = Blog::uniqueSlug($slugIn !== '' ? $slugIn : $title, $post ? (int) $post['id'] : null);

    $cover = $post['cover_image'] ?? null;
    if (!empty($_FILES['cover_file']['name'])) {
        $up = save_upload($_FILES['cover_file'], 'blog');
        if (!$up || str_ends_with($up, '.pdf')) throw new ApiException('Cover must be a JPG, PNG or WebP image under 8 MB.');
        if ($cover && str_starts_with($cover, 'storage/uploads/blog/')) @unlink(BASE_PATH . '/' . $cover);
        $cover = $up;
    } elseif (isset($in['cover_path'])) {
        $path = trim((string) $in['cover_path']);
        if ($path !== '' && !preg_match('#^(https?://|/|storage/uploads/)#', $path)) throw new ApiException('Cover image must be an upload, a full https:// link, or a website path like /images/photo.webp');
        $cover = $path !== '' ? $path : null;
    }

    $when = trim((string) ($in['published_at'] ?? ''));
    $publishedAt = $when !== '' ? date('Y-m-d H:i:s', strtotime($when) ?: time()) : ($status === 'published' ? ($post['published_at'] ?? now()) : ($post['published_at'] ?? null));

    $data = [
        'title' => mb_substr($title, 0, 200), 'slug' => $slug,
        'category' => mb_substr(trim((string) ($in['category'] ?? '')) ?: 'News', 0, 40),
        'excerpt' => mb_substr($excerpt, 0, 400) ?: null, 'body' => $body !== '' ? $body : null,
        'cover_image' => $cover, 'author' => mb_substr(trim((string) ($in['author'] ?? '')), 0, 120) ?: null,
        'is_featured' => !empty($in['is_featured']) ? 1 : 0, 'status' => $status, 'published_at' => $publishedAt,
    ];
    if ($post) {
        DB::update('blog_posts', $data, 'id = ?', [$post['id']]);
        audit((int) $admin['id'], 'blog.update', 'blog_post', (int) $post['id'], $data['title']);
        $pid = (int) $post['id'];
    } else {
        $pid = DB::insert('blog_posts', $data + ['created_by' => (int) $admin['id']]);
        audit((int) $admin['id'], 'blog.create', 'blog_post', $pid, $data['title']);
    }
    flash($status === 'published' ? 'Saved and published — live on the website within a minute.' : 'Draft saved. It isn’t visible on the website until you publish it.');
    redirect('blog_edit.php?id=' . $pid);
});

$p = $post ?? ['title' => '', 'slug' => '', 'category' => 'News', 'excerpt' => '', 'body' => '', 'cover_image' => '', 'author' => $admin['name'], 'is_featured' => 0, 'status' => 'draft', 'published_at' => null];
$coverUrl = Blog::imageUrl($p['cover_image']);
if ($coverUrl && str_starts_with($coverUrl, '/')) $coverUrl = site_url($coverUrl);
$cats = array_values(array_unique(array_merge(Blog::CATEGORIES, array_column(DB::all('SELECT DISTINCT category FROM blog_posts'), 'category'))));
$liveUrl = $post && $post['status'] === 'published' ? site_url('blog/post?slug=' . urlencode($post['slug'])) : null;

layout_start($post ? 'Edit post' : 'New post', 'blog', $post ? ($post['status'] === 'published' ? 'Published' : 'Draft') . ' · last saved ' . date('d M Y, H:i', strtotime($post['updated_at'])) : 'Write in plain text — simple formatting is shown under the editor.',
    '<a class="btn ghost" href="blog.php">All posts</a>' . ($liveUrl ? ' <a class="btn ghost" target="_blank" rel="noopener" href="' . e($liveUrl) . '">' . icon('eye') . ' View on website</a>' : ''), false);
?>
<form method="post" enctype="multipart/form-data" class="grid g-main" style="align-items:start"><?= csrf_field() ?>
  <div class="stack" style="gap:16px">
    <div class="card"><div class="card-b form-grid">
      <label class="f full">Title<input class="input" name="title" value="<?= e($p['title']) ?>" required maxlength="200" style="font-size:18px;font-weight:600"></label>
      <label class="f full">Summary<textarea class="input" name="excerpt" rows="2" maxlength="400" placeholder="One or two sentences shown on the blog cards and at the top of the article."><?= e($p['excerpt']) ?></textarea></label>
      <label class="f full">Article
        <textarea class="input" name="body" id="body" rows="20" style="font-family:inherit;line-height:1.6" placeholder="Write the article here. Leave a blank line between paragraphs."><?= e($p['body']) ?></textarea>
        <span class="hint">Formatting: <b>## Heading</b> · <b>**bold**</b> · <i>*italic*</i> · <b>- list item</b> · <b>1. numbered</b> · <b>&gt; quote</b> · <b>[link text](https://…)</b> · <b>![caption](https://…image.jpg)</b> on its own line · <b>---</b> divider</span>
      </label>
    </div></div>
    <div class="card"><div class="card-h"><h2>Preview</h2><span class="muted small">How the article text will look on the website</span></div>
      <div class="card-b blog-preview" id="preview"><?= Blog::render((string) $p['body']) ?: '<p class="muted">Start typing to see the preview.</p>' ?></div></div>
  </div>

  <div class="stack" style="gap:16px">
    <div class="card"><div class="card-b stack" style="gap:12px">
      <label class="f">Status<select class="input" name="status"><option value="draft" <?= $p['status'] === 'draft' ? 'selected' : '' ?>>Draft — hidden</option><option value="published" <?= $p['status'] === 'published' ? 'selected' : '' ?>>Published — on the website</option></select></label>
      <label class="f">Publish date<input class="input" type="datetime-local" name="published_at" value="<?= $p['published_at'] ? date('Y-m-d\TH:i', strtotime($p['published_at'])) : '' ?>"><span class="hint">Leave empty for now. A future date schedules the post.</span></label>
      <label class="switch"><input type="checkbox" name="is_featured" value="1" <?= $p['is_featured'] ? 'checked' : '' ?>> Featured</label>
      <div class="row"><button class="btn" style="flex:1">Save</button></div>
    </div></div>

    <div class="card"><div class="card-h"><h2>Cover image</h2></div><div class="card-b stack" style="gap:12px">
      <div id="coverBox" style="aspect-ratio:4/3;border-radius:12px;background:var(--surface-2) center/cover no-repeat<?= $coverUrl ? ';background-image:url(' . e($coverUrl) . ')' : '' ?>"></div>
      <label class="f">Upload<input class="input" type="file" name="cover_file" accept="image/jpeg,image/png,image/webp" id="coverFile"><span class="hint">JPG, PNG or WebP, under 8 MB. Landscape works best.</span></label>
      <label class="f">…or image link / website path<input class="input mono" name="cover_path" value="<?= e($p['cover_image']) ?>" placeholder="/images/blog-featured-1.webp"></label>
    </div></div>

    <div class="card"><div class="card-h"><h2>Details</h2></div><div class="card-b stack" style="gap:12px">
      <label class="f">Category<input class="input" name="category" list="cats" value="<?= e($p['category']) ?>" maxlength="40"><datalist id="cats"><?php foreach ($cats as $c): ?><option value="<?= e($c) ?>"><?php endforeach; ?></datalist></label>
      <label class="f">Author<input class="input" name="author" value="<?= e($p['author']) ?>" maxlength="120"></label>
      <label class="f">Web address<input class="input mono" name="slug" value="<?= e($p['slug']) ?>" placeholder="made from the title"><span class="hint"><?= e(parse_url(site_url(), PHP_URL_HOST)) ?>/blog/post?slug=<b><?= e($p['slug'] ?: '…') ?></b></span></label>
    </div></div>
  </div>
</form>

<?php if ($post): ?>
<form method="post" action="blog.php" class="card" data-confirm="Delete “<?= e($post['title']) ?>” for good? This can’t be undone."><?= csrf_field() ?><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<?= $post['id'] ?>">
  <div class="card-b row between"><span class="muted small">Delete this post from the website and admin.</span><button class="btn danger ghost sm">Delete post</button></div></form>
<?php endif; ?>

<style>
.blog-preview { font-size: 15px; line-height: 1.7; max-width: 68ch; }
.blog-preview h2 { font-size: 22px; margin: 22px 0 8px; } .blog-preview h3 { font-size: 18px; margin: 18px 0 6px; } .blog-preview h4 { font-size: 16px; margin: 16px 0 6px; }
.blog-preview p, .blog-preview ul, .blog-preview ol { margin: 0 0 12px; } .blog-preview ul, .blog-preview ol { padding-left: 22px; }
.blog-preview blockquote { margin: 0 0 12px; padding: 4px 14px; border-left: 3px solid var(--brand); color: var(--muted); }
.blog-preview img { max-width: 100%; border-radius: 10px; } .blog-preview figcaption { font-size: 12.5px; color: var(--muted); margin-top: 6px; }
.blog-preview a { color: var(--brand-600); text-decoration: underline; } .blog-preview code { font-family: 'JetBrains Mono', monospace; font-size: .9em; background: var(--surface-2); padding: 1px 5px; border-radius: 4px; }
.blog-preview hr { border: 0; border-top: 1px solid var(--border); margin: 18px 0; }
</style>
<?php
layout_end(<<<'JS'
<script>
(function () {
  var body = document.getElementById('body'), out = document.getElementById('preview'), t;
  var csrf = document.querySelector('input[name=_csrf]').value;
  body.addEventListener('input', function () {
    clearTimeout(t);
    t = setTimeout(function () {
      var fd = new FormData(); fd.append('body', body.value);
      fetch('ajax.php?a=blog_preview', { method: 'POST', body: fd, headers: { 'X-CSRF': csrf } })
        .then(function (r) { return r.json(); })
        .then(function (j) { if (j.success) out.innerHTML = j.data.html || '<p class="muted">Start typing to see the preview.</p>'; });
    }, 350);
  });
  var f = document.getElementById('coverFile'), box = document.getElementById('coverBox');
  f.addEventListener('change', function () { if (f.files[0]) box.style.backgroundImage = 'url(' + URL.createObjectURL(f.files[0]) + ')'; });
})();
</script>
JS);
