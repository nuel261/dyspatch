<?php
declare(strict_types=1);

/** 4-digit OTPs · 30-minute expiry · locked after 3 failed attempts (all configurable). */
final class Otp
{
    public static function issue(string $phone, string $purpose = 'login', ?string $email = null): array
    {
        $resend = Settings::int('otp_resend_seconds', 60);
        $last = DB::row('SELECT created_at FROM otps WHERE phone = ? AND purpose = ? ORDER BY id DESC LIMIT 1', [$phone, $purpose]);
        if ($last && time() - strtotime($last['created_at']) < $resend) {
            throw new ApiException('Please wait ' . ($resend - (time() - strtotime($last['created_at']))) . 's before requesting another code.', 429);
        }
        // Invalidate any outstanding codes — a new request is the recovery path from lockout.
        DB::query('UPDATE otps SET consumed_at = NOW() WHERE phone = ? AND purpose = ? AND consumed_at IS NULL', [$phone, $purpose]);

        $len = Settings::int('otp_length', 4);
        $mins = Settings::int('otp_expiry_minutes', 30);
        $code = digits($len);
        DB::insert('otps', [
            'phone' => $phone, 'purpose' => $purpose, 'code_hash' => password_hash($code, PASSWORD_DEFAULT),
            'expires_at' => date('Y-m-d H:i:s', time() + $mins * 60),
        ]);
        Sms::send($phone, "Your Dyspatch code is $code. It expires in $mins minutes. Never share it with anyone.");
        if ($email) {
            Mailer::send($email, 'Your Dyspatch verification code', Mailer::template('Your verification code',
                "Use this code to continue. It expires in $mins minutes. If you didn't request it, you can ignore this email.", null, null, $code));
        }
        return ['expires_in' => $mins * 60, 'length' => $len, 'resend_in' => $resend, 'debug_code' => Sms::isLive() ? null : $code];
    }

    public static function verify(string $phone, string $code, string $purpose = 'login'): void
    {
        $max = Settings::int('otp_max_attempts', 3);
        $otp = DB::row('SELECT * FROM otps WHERE phone = ? AND purpose = ? AND consumed_at IS NULL ORDER BY id DESC LIMIT 1', [$phone, $purpose]);
        if (!$otp) throw new ApiException('No active code. Request a new one.', 422);
        if ($otp['is_locked']) throw new ApiException('Too many wrong attempts. Request a new code.', 423);
        if (strtotime($otp['expires_at']) < time()) throw new ApiException('This code has expired. Request a new one.', 422);

        if (!password_verify($code, $otp['code_hash'])) {
            $attempts = (int) $otp['attempts'] + 1;
            DB::update('otps', ['attempts' => $attempts, 'is_locked' => $attempts >= $max ? 1 : 0], 'id = ?', [$otp['id']]);
            $left = $max - $attempts;
            throw new ApiException($left > 0 ? "Incorrect code. $left attempt" . ($left === 1 ? '' : 's') . ' left.' : 'Too many wrong attempts. Request a new code.', $left > 0 ? 422 : 423);
        }
        DB::update('otps', ['consumed_at' => now()], 'id = ?', [$otp['id']]);
    }
}
