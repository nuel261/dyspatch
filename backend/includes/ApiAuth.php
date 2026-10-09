<?php
declare(strict_types=1);

final class ApiAuth
{
    public static function issueToken(string $ownerType, int $ownerId, ?string $device = null): string
    {
        $token = bin2hex(random_bytes(32));
        DB::insert('api_tokens', [
            'owner_type' => $ownerType, 'owner_id' => $ownerId, 'token_hash' => hash('sha256', $token),
            'device' => $device ? mb_substr($device, 0, 120) : null,
            'expires_at' => date('Y-m-d H:i:s', time() + (int) config('token_ttl_days', 60) * 86400),
        ]);
        return $token;
    }

    public static function bearer(): ?string
    {
        $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        if ($h === '' && function_exists('getallheaders')) {
            foreach (getallheaders() as $k => $v) if (strtolower($k) === 'authorization') $h = $v;
        }
        return preg_match('/Bearer\s+(\S+)/i', $h, $m) ? $m[1] : null;
    }

    /** @return array{type:string,id:int,row:array}|null */
    public static function current(): ?array
    {
        static $cached = false;
        if ($cached !== false) return $cached;
        $cached = null;
        $t = self::bearer();
        if (!$t) return null;
        $tok = DB::row('SELECT * FROM api_tokens WHERE token_hash = ? AND expires_at > NOW()', [hash('sha256', $t)]);
        if (!$tok) return null;
        $table = $tok['owner_type'] === 'rider' ? 'riders' : 'users';
        $row = DB::row("SELECT * FROM $table WHERE id = ?", [$tok['owner_id']]);
        if (!$row) return null;
        if ($row['status'] === 'suspended') throw new ApiException('This account is suspended. Contact support.', 403);
        if (!$tok['last_used_at'] || strtotime($tok['last_used_at']) < time() - 300) DB::update('api_tokens', ['last_used_at' => now()], 'id = ?', [$tok['id']]);
        return $cached = ['type' => $tok['owner_type'], 'id' => (int) $tok['owner_id'], 'row' => $row, 'token_id' => (int) $tok['id']];
    }

    public static function requireUser(): array
    {
        $a = self::current();
        if (!$a || $a['type'] !== 'user') throw new ApiException('Unauthenticated', 401);
        return $a['row'];
    }

    public static function requireRider(): array
    {
        $a = self::current();
        if (!$a || $a['type'] !== 'rider') throw new ApiException('Unauthenticated', 401);
        return $a['row'];
    }

    public static function revokeCurrent(): void
    {
        $a = self::current();
        if ($a) DB::query('DELETE FROM api_tokens WHERE id = ?', [$a['token_id']]);
    }

    /** Verifies a Firebase ID token (RS256) issued for this Firebase project. */
    public static function verifyFirebaseToken(string $idToken): array
    {
        $parts = explode('.', $idToken);
        if (count($parts) !== 3) throw new ApiException('Invalid Google token', 401);
        $dec = fn($s) => json_decode(base64_decode(strtr($s, '-_', '+/') . str_repeat('=', (4 - strlen($s) % 4) % 4)), true);
        $header = $dec($parts[0]);
        $claims = $dec($parts[1]);
        $project = (string) Settings::get('firebase_project_id', 'dyspatch-bc9cc');
        if (($claims['aud'] ?? '') !== $project || ($claims['iss'] ?? '') !== "https://securetoken.google.com/$project"
            || ($claims['exp'] ?? 0) < time() || empty($claims['sub'])) throw new ApiException('Google sign-in token is invalid or expired', 401);

        $cacheFile = BASE_PATH . '/storage/cache/firebase_certs.json';
        $certs = is_file($cacheFile) && filemtime($cacheFile) > time() - 3600 ? json_decode((string) file_get_contents($cacheFile), true) : null;
        if (!$certs || !isset($certs[$header['kid'] ?? ''])) {
            $r = http_request('GET', 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
            $certs = $r['json'] ?? [];
            @mkdir(dirname($cacheFile), 0775, true);
            file_put_contents($cacheFile, json_encode($certs));
        }
        $cert = $certs[$header['kid'] ?? ''] ?? null;
        if (!$cert) throw new ApiException('Unknown signing key', 401);
        $sig = base64_decode(strtr($parts[2], '-_', '+/') . str_repeat('=', (4 - strlen($parts[2]) % 4) % 4));
        if (openssl_verify($parts[0] . '.' . $parts[1], $sig, $cert, OPENSSL_ALGO_SHA256) !== 1) throw new ApiException('Invalid token signature', 401);
        return $claims;
    }
}
