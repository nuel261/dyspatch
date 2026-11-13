<?php
declare(strict_types=1);

/**
 * Blog posts for the public website. Admin writes them in Admin → Website → Blog;
 * the website reads them through GET /api/blog and /api/blog/{slug}.
 *
 * Post bodies are Markdown. They are rendered to HTML here (one renderer for the
 * admin preview and the website), with every piece of text escaped, so writers
 * can't inject scripts.
 */
final class Blog
{
    public const CATEGORIES = ['Product', 'Guide', 'Business', 'Riders’ Stories', 'Tips', 'Company', 'News'];

    public static function slugify(string $s): string
    {
        $s = strtolower(trim(preg_replace('/[^A-Za-z0-9]+/', '-', iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $s) ?: $s), '-'));
        return substr($s, 0, 150) ?: 'post';
    }

    public static function uniqueSlug(string $base, ?int $exceptId = null): string
    {
        $slug = self::slugify($base);
        for ($i = 2; ; $i++) {
            $hit = DB::value('SELECT id FROM blog_posts WHERE slug = ?' . ($exceptId ? ' AND id <> ?' : ''), $exceptId ? [$slug, $exceptId] : [$slug]);
            if (!$hit) return $slug;
            $slug = self::slugify($base) . '-' . $i;
        }
    }

    /** Cover image URL: uploads live on the backend; "/images/..." paths live on the website. */
    public static function imageUrl(?string $path): ?string
    {
        if (!$path) return null;
        if (preg_match('#^https?://#', $path)) return $path;
        if (str_starts_with($path, 'storage/')) return app_url($path);
        return $path; // website-relative, e.g. /images/blog-featured-1.webp
    }

    public static function minutesToRead(?string $body): int
    {
        return max(1, (int) ceil(str_word_count(strip_tags((string) $body)) / 220));
    }

    public static function payload(array $p, bool $full = false): array
    {
        $out = [
            'id' => (int) $p['id'],
            'slug' => $p['slug'],
            'title' => $p['title'],
            'category' => $p['category'],
            'excerpt' => (string) $p['excerpt'],
            'image' => self::imageUrl($p['cover_image']),
            'author' => $p['author'] ?: 'Dyspatch Team',
            'featured' => (bool) $p['is_featured'],
            'published_at' => $p['published_at'] ? date(DATE_ATOM, strtotime($p['published_at'])) : null,
            'read_minutes' => self::minutesToRead($p['body'] ?? $p['excerpt']),
            'has_body' => trim((string) ($p['body'] ?? '')) !== '',
        ];
        if ($full) $out['body_html'] = self::render((string) $p['body']);
        return $out;
    }

    public static function published(int $limit = 50, ?string $category = null): array
    {
        $sql = "SELECT * FROM blog_posts WHERE status = 'published' AND (published_at IS NULL OR published_at <= NOW())";
        $args = [];
        if ($category) { $sql .= ' AND category = ?'; $args[] = $category; }
        $sql .= ' ORDER BY is_featured DESC, COALESCE(published_at, created_at) DESC LIMIT ' . max(1, min(100, $limit));
        return DB::all($sql, $args);
    }

    // ── Markdown → safe HTML ─────────────────────────────────────────────
    // Supports: # ## ### headings, paragraphs, **bold**, *italic*, `code`,
    // [links](https://…), ![images](https://…), - / 1. lists, > quotes, ---.
    public static function render(string $md): string
    {
        $md = str_replace(["\r\n", "\r"], "\n", trim($md));
        if ($md === '') return '';
        $html = [];
        $para = [];
        $list = null; // ['ul'|'ol', items[]]
        $flushPara = function () use (&$para, &$html) {
            if ($para) { $html[] = '<p>' . self::inline(implode(' ', $para)) . '</p>'; $para = []; }
        };
        $flushList = function () use (&$list, &$html) {
            if ($list) {
                $html[] = "<{$list[0]}>" . implode('', array_map(fn($i) => '<li>' . self::inline($i) . '</li>', $list[1])) . "</{$list[0]}>";
                $list = null;
            }
        };
        foreach (explode("\n", $md) as $line) {
            $t = trim($line);
            if ($t === '') { $flushPara(); $flushList(); continue; }
            if (preg_match('/^(#{1,3})\s+(.+)$/', $t, $m)) {
                $flushPara(); $flushList();
                $lvl = max(2, strlen($m[1])); // # and ## → h2, ### → h3 (the page title is the h1)
                $html[] = "<h$lvl>" . self::inline($m[2]) . "</h$lvl>";
            } elseif (preg_match('/^(-{3,}|\*{3,})$/', $t)) {
                $flushPara(); $flushList(); $html[] = '<hr>';
            } elseif (preg_match('/^>\s?(.*)$/', $t, $m)) {
                $flushPara(); $flushList(); $html[] = '<blockquote><p>' . self::inline($m[1]) . '</p></blockquote>';
            } elseif (preg_match('/^[-*]\s+(.+)$/', $t, $m)) {
                $flushPara();
                if (!$list || $list[0] !== 'ul') { $flushList(); $list = ['ul', []]; }
                $list[1][] = $m[1];
            } elseif (preg_match('/^\d+[.)]\s+(.+)$/', $t, $m)) {
                $flushPara();
                if (!$list || $list[0] !== 'ol') { $flushList(); $list = ['ol', []]; }
                $list[1][] = $m[1];
            } elseif (preg_match('/^!\[([^\]]*)\]\((\S+?)\)$/', $t, $m) && self::safeUrl($m[2])) {
                $flushPara(); $flushList();
                $html[] = '<figure><img src="' . e(self::imageUrl($m[2])) . '" alt="' . e($m[1]) . '" loading="lazy">' . ($m[1] !== '' ? '<figcaption>' . e($m[1]) . '</figcaption>' : '') . '</figure>';
            } else {
                $flushList(); $para[] = $t;
            }
        }
        $flushPara(); $flushList();
        return implode("\n", $html);
    }

    private static function safeUrl(string $u): bool
    {
        return (bool) preg_match('#^(https?://|mailto:|tel:|/|storage/)#i', $u);
    }

    private static function inline(string $s): string
    {
        $s = e($s);
        // links [text](url) — url was escaped too, so &amp; etc. are fine in href
        $s = preg_replace_callback('/\[([^\]]+)\]\(([^)\s]+)\)/', function ($m) {
            $url = html_entity_decode($m[2], ENT_QUOTES);
            if (!self::safeUrl($url)) return $m[1];
            $ext = preg_match('#^https?://#i', $url) ? ' target="_blank" rel="noopener"' : '';
            return '<a href="' . e($url) . '"' . $ext . '>' . $m[1] . '</a>';
        }, $s);
        $s = preg_replace('/`([^`]+)`/', '<code>$1</code>', $s);
        $s = preg_replace('/\*\*(.+?)\*\*/', '<strong>$1</strong>', $s);
        $s = preg_replace('/(?<![*\w])\*(?!\s)(.+?)(?<!\s)\*(?![*\w])/', '<em>$1</em>', $s);
        return $s;
    }

    /** First-run content: the posts the website launched with (images ship with the website). */
    public static function seed(): void
    {
        if ((int) DB::value('SELECT COUNT(*) FROM blog_posts') > 0) return;
        $posts = [
            ['introducing-dyspatch', 'Product', 'Introducing Dyspatch: Last-mile delivery built for Nigeria', 'We’re building the most trusted delivery infrastructure in West Africa.', '/images/blog-featured-1.webp', 1],
            ['otp-verification', 'Guide', 'How OTP verification makes every delivery secure', 'A deep dive into our 4-digit handover system.', '/images/blog-featured-2.webp', 1],
            ['scaling-ecommerce-api', 'Business', 'Scaling delivery for e-commerce: API', 'Which approach is right for your business?', '/images/blog-featured-3.webp', 1],
            ['meet-musa', 'Riders’ Stories', 'Meet Musa: From okada to Dyspatch Pro in 3 months', 'How one rider built a structured earning platform.', '/images/blog-featured-4.webp', 1],
            ['reduce-delivery-costs', 'Tips', '5 ways to reduce delivery costs for your small business', 'Practical strategies for Lagos-based businesses.', '/images/blog-featured-5.webp', 1],
            ['our-roadmap', 'Company', 'Our roadmap: From Lagos to West Africa', 'The three-phase plan to scale Dyspatch.', '/images/blog-featured-6.webp', 1],
            ['small-business-shipping', 'Product', 'Shipping made simple for small businesses', 'Send one package or a thousand — same dashboard, same speed.', '/images/blog-latest-1.webp', 0],
            ['student-riders-campus', 'Riders’ Stories', 'Why students are the backbone of campus delivery', 'Flexible hours, verified routes, and instant payouts.', '/images/blog-latest-2.webp', 0],
            ['fashion-fulfilment-lagos', 'Business', 'How Lagos fashion sellers fulfil orders in hours', 'Same-day dispatch is changing what customers expect.', '/images/blog-latest-3.webp', 0],
            ['inside-90s-matching', 'Guide', 'Inside 90-second matching', 'The routing that puts the nearest rider on your package.', '/images/blog-latest-4.webp', 0],
            ['peak-hours-earnings', 'Tips', 'Earning more in peak windows', 'When and where riders make the most on the platform.', '/images/blog-latest-5.webp', 0],
            ['trust-and-safety', 'Company', 'Trust & safety, by design', 'Verification, OTP handover, and package protection explained.', '/images/blog-latest-6.webp', 0],
        ];
        $t = time();
        foreach ($posts as $i => [$slug, $cat, $title, $excerpt, $img, $featured]) {
            DB::insert('blog_posts', [
                'slug' => $slug, 'title' => $title, 'category' => $cat, 'excerpt' => $excerpt, 'body' => null,
                'cover_image' => $img, 'author' => 'Dyspatch Team', 'is_featured' => $featured, 'status' => 'published',
                'published_at' => date('Y-m-d H:i:s', $t - ($i + 1) * 86400 * 3),
            ]);
        }
    }
}
