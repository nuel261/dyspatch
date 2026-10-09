<?php
declare(strict_types=1);

/**
 * Firebase Cloud Messaging (HTTP v1). Paste the Firebase service-account JSON
 * in Admin → Settings → Push notifications. Invalid device tokens are pruned.
 */
final class Push
{
    public static function enabled(): bool
    {
        return Settings::get('push_enabled', '1') === '1' && self::serviceAccount() !== null;
    }

    private static function serviceAccount(): ?array
    {
        $raw = (string) Settings::get('fcm_service_account', '');
        if ($raw === '') return null;
        $sa = json_decode($raw, true);
        return (is_array($sa) && !empty($sa['private_key']) && !empty($sa['client_email'])) ? $sa : null;
    }

    private static function b64url(string $s): string { return rtrim(strtr(base64_encode($s), '+/', '-_'), '='); }

    private static function accessToken(): ?string
    {
        $cacheFile = BASE_PATH . '/storage/cache/fcm_token.json';
        if (is_file($cacheFile)) {
            $c = json_decode((string) file_get_contents($cacheFile), true);
            if (($c['exp'] ?? 0) > time() + 60 && ($c['sa'] ?? '') === md5((string) Settings::get('fcm_service_account'))) return $c['token'];
        }
        $sa = self::serviceAccount();
        if (!$sa) return null;
        $now = time();
        $jwt = self::b64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT'])) . '.' . self::b64url(json_encode([
            'iss' => $sa['client_email'], 'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token', 'iat' => $now, 'exp' => $now + 3600,
        ]));
        if (!openssl_sign($jwt, $sig, $sa['private_key'], OPENSSL_ALGO_SHA256)) {
            log_line('push', 'Could not sign FCM JWT — check the service account private key');
            return null;
        }
        $jwt .= '.' . self::b64url($sig);
        $r = http_request('POST', 'https://oauth2.googleapis.com/token', ['Content-Type' => 'application/x-www-form-urlencoded'],
            http_build_query(['grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion' => $jwt]));
        $token = $r['json']['access_token'] ?? null;
        if (!$token) { log_line('push', 'FCM auth failed: ' . $r['body']); return null; }
        @mkdir(dirname($cacheFile), 0775, true);
        file_put_contents($cacheFile, json_encode(['token' => $token, 'exp' => $now + (int) ($r['json']['expires_in'] ?? 3500), 'sa' => md5((string) Settings::get('fcm_service_account'))]));
        return $token;
    }

    /** Sends to every registered device of an owner. Returns number delivered. */
    public static function toOwner(string $ownerType, int $ownerId, string $title, string $body, array $data = []): int
    {
        if (!self::enabled()) return 0;
        $tokens = DB::all('SELECT id, fcm_token FROM device_tokens WHERE owner_type = ? AND owner_id = ?', [$ownerType, $ownerId]);
        $sent = 0;
        foreach ($tokens as $t) if (self::toToken($t['fcm_token'], $title, $body, $data)) $sent++;
        return $sent;
    }

    public static function toToken(string $fcmToken, string $title, string $body, array $data = []): bool
    {
        $access = self::accessToken();
        $sa = self::serviceAccount();
        if (!$access || !$sa) return false;
        $project = $sa['project_id'] ?? Settings::get('firebase_project_id');
        $payload = ['message' => [
            'token' => $fcmToken,
            'notification' => ['title' => $title, 'body' => $body],
            'data' => array_map('strval', $data),
            'android' => ['priority' => 'HIGH', 'notification' => ['channel_id' => 'dyspatch_updates', 'color' => '#34A853', 'sound' => 'default']],
            'apns' => ['payload' => ['aps' => ['sound' => 'default', 'badge' => 1]]],
        ]];
        $r = http_request('POST', "https://fcm.googleapis.com/v1/projects/$project/messages:send", ['Authorization' => "Bearer $access"], $payload);
        if ($r['status'] === 200) return true;
        $err = $r['json']['error']['status'] ?? '';
        if (in_array($err, ['NOT_FOUND', 'UNREGISTERED', 'INVALID_ARGUMENT'], true) || $r['status'] === 404) {
            DB::query('DELETE FROM device_tokens WHERE fcm_token = ?', [$fcmToken]);
        }
        log_line('push', "FCM send failed ({$r['status']}): " . $r['body']);
        return false;
    }
}
