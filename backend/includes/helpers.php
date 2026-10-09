<?php
declare(strict_types=1);

class ApiException extends RuntimeException
{
    public int $status;
    public array $errors;
    public function __construct(string $message, int $status = 400, array $errors = [])
    {
        parent::__construct($message);
        $this->status = $status;
        $this->errors = $errors;
    }
}

function config(string $key, $default = null)
{
    $v = $GLOBALS['CONFIG'];
    foreach (explode('.', $key) as $k) {
        if (!is_array($v) || !array_key_exists($k, $v)) return $default;
        $v = $v[$k];
    }
    return $v;
}

function app_url(string $path = ''): string
{
    return rtrim((string) config('app_url', ''), '/') . '/' . ltrim($path, '/');
}

function e($v): string { return htmlspecialchars((string) ($v ?? ''), ENT_QUOTES, 'UTF-8'); }

function now(): string { return date('Y-m-d H:i:s'); }

/** kobo (int) → "₦4,200.00" */
function naira($kobo, bool $decimals = true): string
{
    $n = ((int) $kobo) / 100;
    return '₦' . number_format($n, $decimals ? 2 : 0);
}

/** naira input (string/float) → kobo int, without float rounding drift */
function to_kobo($naira): int
{
    $s = trim(str_replace([',', '₦', ' '], '', (string) $naira));
    if ($s === '' || !preg_match('/^-?\d+(\.\d{1,2})?$/', $s)) return 0;
    [$whole, $frac] = array_pad(explode('.', $s), 2, '0');
    $frac = str_pad(substr($frac, 0, 2), 2, '0');
    $neg = str_starts_with($whole, '-');
    $k = abs((int) $whole) * 100 + (int) $frac;
    return $neg ? -$k : $k;
}

/** Normalises Nigerian numbers to E.164 (+234...) */
function normalize_phone(string $phone): string
{
    $p = preg_replace('/[^\d+]/', '', $phone);
    if (str_starts_with($p, '+')) return $p;
    if (str_starts_with($p, '234')) return '+' . $p;
    if (str_starts_with($p, '0')) return '+234' . substr($p, 1);
    if (strlen($p) === 10) return '+234' . $p;
    return '+' . $p;
}

function digits(int $len): string
{
    $s = '';
    for ($i = 0; $i < $len; $i++) $s .= (string) random_int(0, 9);
    return $s;
}

function rand_code(int $len, string $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'): string
{
    $s = '';
    $max = strlen($alphabet) - 1;
    for ($i = 0; $i < $len; $i++) $s .= $alphabet[random_int(0, $max)];
    return $s;
}

function haversine_km(float $lat1, float $lng1, float $lat2, float $lng2): float
{
    $r = 6371.0;
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
    return $r * 2 * atan2(sqrt($a), sqrt(1 - $a));
}

function point_in_polygon(float $lat, float $lng, array $poly): bool
{
    $inside = false;
    $n = count($poly);
    for ($i = 0, $j = $n - 1; $i < $n; $j = $i++) {
        [$yi, $xi] = $poly[$i];
        [$yj, $xj] = $poly[$j];
        if ((($yi > $lat) !== ($yj > $lat)) && ($lng < ($xj - $xi) * ($lat - $yi) / (($yj - $yi) ?: 1e-12) + $xi)) $inside = !$inside;
    }
    return $inside;
}

/** Minimal cURL wrapper. Returns ['status'=>int,'body'=>string,'json'=>?array] */
function http_request(string $method, string $url, array $headers = [], $body = null, int $timeout = 20): array
{
    $ch = curl_init($url);
    $h = [];
    foreach ($headers as $k => $v) $h[] = is_int($k) ? $v : "$k: $v";
    if (is_array($body)) {
        $body = json_encode($body);
        $h[] = 'Content-Type: application/json';
    }
    curl_setopt_array($ch, [
        CURLOPT_CUSTOMREQUEST => strtoupper($method),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => $timeout,
        CURLOPT_HTTPHEADER => $h,
        CURLOPT_USERAGENT => 'DyspatchBackend/1.0 (+' . app_url() . ')',
    ]);
    if ($body !== null) curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
    $resp = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);
    if ($resp === false) {
        log_line('http', "$method $url failed: $err");
        return ['status' => 0, 'body' => '', 'json' => null, 'error' => $err];
    }
    $json = json_decode((string) $resp, true);
    return ['status' => $status, 'body' => (string) $resp, 'json' => is_array($json) ? $json : null];
}

function log_line(string $channel, string $msg): void
{
    $dir = BASE_PATH . '/storage/logs';
    if (!is_dir($dir)) @mkdir($dir, 0775, true);
    @file_put_contents("$dir/$channel-" . date('Y-m-d') . '.log', '[' . now() . "] $msg\n", FILE_APPEND);
}

/** Saves an uploaded file (or base64 data URI) and returns its public relative path. */
function save_upload($file, string $folder): ?string
{
    $allowed = ['jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'png' => 'image/png', 'webp' => 'image/webp', 'pdf' => 'application/pdf'];
    $dir = BASE_PATH . '/storage/uploads/' . $folder;
    if (!is_dir($dir)) @mkdir($dir, 0775, true);

    if (is_string($file) && preg_match('#^data:(image/(?:png|jpe?g|webp)|application/pdf);base64,(.+)$#', $file, $m)) {
        $data = base64_decode($m[2], true);
        if ($data === false || strlen($data) > 8 * 1024 * 1024) return null;
        $ext = array_search($m[1], $allowed, true) ?: 'jpg';
        $name = bin2hex(random_bytes(12)) . '.' . $ext;
        file_put_contents("$dir/$name", $data);
        return "storage/uploads/$folder/$name";
    }
    if (is_array($file) && ($file['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK) {
        if ($file['size'] > 8 * 1024 * 1024) return null;
        $mime = (new finfo(FILEINFO_MIME_TYPE))->file($file['tmp_name']);
        $ext = array_search($mime, $allowed, true);
        if ($ext === false) return null;
        $name = bin2hex(random_bytes(12)) . '.' . $ext;
        if (!move_uploaded_file($file['tmp_name'], "$dir/$name")) return null;
        return "storage/uploads/$folder/$name";
    }
    return null;
}

function public_file(?string $path): ?string
{
    if (!$path) return null;
    return preg_match('#^https?://#', $path) ? $path : app_url($path);
}

function audit(?int $adminId, string $action, ?string $entity = null, ?int $entityId = null, ?string $details = null): void
{
    DB::insert('audit_logs', [
        'admin_id' => $adminId, 'action' => $action, 'entity' => $entity, 'entity_id' => $entityId,
        'details' => $details ? mb_substr($details, 0, 500) : null, 'ip' => $_SERVER['REMOTE_ADDR'] ?? null,
    ]);
}

function time_ago(?string $dt): string
{
    if (!$dt) return '—';
    $d = time() - strtotime($dt);
    if ($d < 60) return 'just now';
    if ($d < 3600) return floor($d / 60) . 'm ago';
    if ($d < 86400) return floor($d / 3600) . 'h ago';
    if ($d < 604800) return floor($d / 86400) . 'd ago';
    return date('j M Y', strtotime($dt));
}

function iso(?string $dt): ?string { return $dt ? date('c', strtotime($dt)) : null; }
