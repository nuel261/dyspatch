<?php
declare(strict_types=1);

/** Admin-configurable business rules. Nothing here requires a redeploy to change. */
final class Settings
{
    private static ?array $cache = null;

    public static function all(): array
    {
        if (self::$cache === null) {
            self::$cache = [];
            foreach (DB::all('SELECT `key`, `value` FROM settings') as $r) self::$cache[$r['key']] = $r['value'];
        }
        return self::$cache;
    }

    public static function get(string $key, $default = null)
    {
        $all = self::all();
        return (array_key_exists($key, $all) && $all[$key] !== null && $all[$key] !== '') ? $all[$key] : $default;
    }

    public static function int(string $key, int $default = 0): int { return (int) self::get($key, $default); }
    public static function float(string $key, float $default = 0): float { return (float) self::get($key, $default); }

    public static function set(string $key, ?string $value): void
    {
        DB::query('INSERT INTO settings (`key`,`value`) VALUES (?,?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)', [$key, $value]);
        self::$cache = null;
    }
}
