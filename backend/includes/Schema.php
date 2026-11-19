<?php
declare(strict_types=1);

/**
 * Brings an existing database up to date (fresh installs get the same from
 * database/schema.sql). Runs once per version; a flag file in storage/cache
 * stops it from touching the database on every request.
 */
final class Schema
{
    private const VERSION = 4;

    public static function ensure(): void
    {
        $flag = BASE_PATH . '/storage/cache/schema-v' . self::VERSION . '.flag';
        if (is_file($flag)) return;
        try {
            DB::query("CREATE TABLE IF NOT EXISTS blog_posts (
                id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                slug VARCHAR(160) NOT NULL UNIQUE,
                title VARCHAR(200) NOT NULL,
                category VARCHAR(40) NOT NULL DEFAULT 'News',
                excerpt VARCHAR(400) NULL,
                body MEDIUMTEXT NULL,
                cover_image VARCHAR(255) NULL,
                author VARCHAR(120) NULL,
                is_featured TINYINT(1) NOT NULL DEFAULT 0,
                status ENUM('draft','published') NOT NULL DEFAULT 'draft',
                published_at DATETIME NULL,
                created_by INT UNSIGNED NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                KEY idx_blog_pub (status, published_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
            // v3: rider app profile fields (join type + extra profile JSON).
            $cols = array_column(DB::all('SHOW COLUMNS FROM riders'), 'Field');
            if (!in_array('join_type', $cols, true)) DB::query("ALTER TABLE riders ADD COLUMN join_type ENUM('individual','student','fleet') NOT NULL DEFAULT 'individual' AFTER rating_count");
            if (!in_array('profile_extra', $cols, true)) DB::query('ALTER TABLE riders ADD COLUMN profile_extra JSON NULL AFTER join_type');
            // v4: landmark / directions notes for addresses maps can't find.
            $oc = array_column(DB::all('SHOW COLUMNS FROM orders'), 'Field');
            if (!in_array('pickup_note', $oc, true)) DB::query('ALTER TABLE orders ADD COLUMN pickup_note VARCHAR(255) NULL AFTER pickup_lng');
            if (!in_array('dropoff_note', $oc, true)) DB::query('ALTER TABLE orders ADD COLUMN dropoff_note VARCHAR(255) NULL AFTER dropoff_lng');
            Website::seedDefaults();
            Blog::seed();
            @mkdir(dirname($flag), 0775, true);
            @file_put_contents($flag, date(DATE_ATOM));
        } catch (Throwable $e) {
            log_line('schema', $e->getMessage());
        }
    }
}
