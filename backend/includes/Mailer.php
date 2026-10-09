<?php
declare(strict_types=1);

/**
 * Dependency-free SMTP mailer (SSL on 465, STARTTLS on 587, or plain).
 * Falls back to PHP mail() when no SMTP host is configured.
 * All settings come from Admin → Settings → Email.
 */
final class Mailer
{
    public static function enabled(): bool { return Settings::get('email_enabled', '1') === '1'; }

    public static function send(string $to, string $subject, string $html, ?string $text = null): bool
    {
        if (!self::enabled() || !filter_var($to, FILTER_VALIDATE_EMAIL)) return false;
        $text ??= trim(html_entity_decode(strip_tags(preg_replace('#<br\s*/?>|</p>|</tr>#i', "\n", $html))));
        $fromEmail = (string) Settings::get('mail_from_email', 'no-reply@' . (parse_url(app_url(), PHP_URL_HOST) ?: 'localhost'));
        $fromName = (string) Settings::get('mail_from_name', 'Dyspatch');

        $boundary = 'b' . bin2hex(random_bytes(8));
        $headers = [
            'MIME-Version: 1.0',
            'Date: ' . date('r'),
            'From: ' . self::encodeHeader($fromName) . " <$fromEmail>",
            "Reply-To: $fromEmail",
            'Message-ID: <' . bin2hex(random_bytes(12)) . '@' . (explode('@', $fromEmail)[1] ?? 'localhost') . '>',
            "Content-Type: multipart/alternative; boundary=\"$boundary\"",
        ];
        $body = "--$boundary\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
            . chunk_split(base64_encode($text))
            . "--$boundary\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
            . chunk_split(base64_encode($html)) . "--$boundary--\r\n";

        $host = (string) Settings::get('smtp_host', '');
        try {
            if ($host === '') {
                $ok = mail($to, self::encodeHeader($subject), $body, implode("\r\n", array_slice($headers, 2)), '-f' . $fromEmail);
            } else {
                $ok = self::smtp($host, (int) Settings::get('smtp_port', 587), (string) Settings::get('smtp_encryption', 'tls'),
                    (string) Settings::get('smtp_username', ''), (string) Settings::get('smtp_password', ''),
                    $fromEmail, $to, array_merge(["To: $to", 'Subject: ' . self::encodeHeader($subject)], $headers), $body);
            }
        } catch (Throwable $e) {
            log_line('mail', "Send to $to failed: " . $e->getMessage());
            return false;
        }
        log_line('mail', ($ok ? 'SENT' : 'FAILED') . " to $to: $subject");
        return $ok;
    }

    private static function encodeHeader(string $s): string
    {
        return preg_match('/[^\x20-\x7E]/', $s) ? '=?UTF-8?B?' . base64_encode($s) . '?=' : $s;
    }

    private static function smtp(string $host, int $port, string $enc, string $user, string $pass, string $from, string $to, array $headers, string $body): bool
    {
        $remote = ($enc === 'ssl' ? 'ssl://' : 'tcp://') . $host . ':' . $port;
        $ctx = stream_context_create(['ssl' => ['verify_peer' => true, 'verify_peer_name' => true, 'SNI_enabled' => true, 'peer_name' => $host]]);
        $fp = @stream_socket_client($remote, $errno, $errstr, 20, STREAM_CLIENT_CONNECT, $ctx);
        if (!$fp) throw new RuntimeException("SMTP connect failed: $errstr ($errno)");
        stream_set_timeout($fp, 20);

        $read = function () use ($fp): string {
            $data = '';
            while (($line = fgets($fp, 515)) !== false) {
                $data .= $line;
                if (isset($line[3]) && $line[3] === ' ') break;
            }
            return $data;
        };
        $cmd = function (string $c, array $expect) use ($fp, $read): string {
            fwrite($fp, $c . "\r\n");
            $r = $read();
            if (!in_array((int) substr($r, 0, 3), $expect, true)) throw new RuntimeException('SMTP error on ' . explode(' ', $c)[0] . ': ' . trim($r));
            return $r;
        };

        $read();
        $ehloHost = parse_url(app_url(), PHP_URL_HOST) ?: 'localhost';
        $cmd("EHLO $ehloHost", [250]);
        if ($enc === 'tls') {
            $cmd('STARTTLS', [220]);
            if (!stream_socket_enable_crypto($fp, true, STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT | STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT)) throw new RuntimeException('STARTTLS failed');
            $cmd("EHLO $ehloHost", [250]);
        }
        if ($user !== '') {
            $cmd('AUTH LOGIN', [334]);
            $cmd(base64_encode($user), [334]);
            $cmd(base64_encode($pass), [235]);
        }
        $cmd("MAIL FROM:<$from>", [250]);
        $cmd("RCPT TO:<$to>", [250, 251]);
        $cmd('DATA', [354]);
        $msg = implode("\r\n", $headers) . "\r\n\r\n" . $body;
        $msg = preg_replace('/^\./m', '..', $msg);
        $cmd($msg . "\r\n.", [250]);
        @fwrite($fp, "QUIT\r\n");
        fclose($fp);
        return true;
    }

    /** Branded HTML email matching dyspatch.com.ng (Montserrat, #34A853, rounded cards). */
    public static function template(string $heading, string $bodyHtml, ?string $ctaLabel = null, ?string $ctaUrl = null, ?string $code = null): string
    {
        $cta = $ctaLabel && $ctaUrl
            ? '<tr><td style="padding:8px 32px 8px"><a href="' . e($ctaUrl) . '" style="display:inline-block;background:#34A853;color:#fff;text-decoration:none;font-weight:600;font-size:15px;padding:14px 26px;border-radius:12px">' . e($ctaLabel) . '</a></td></tr>'
            : '';
        $codeBlock = $code
            ? '<tr><td style="padding:8px 32px 8px"><div style="display:inline-block;background:#EEF1F4;border-radius:12px;padding:14px 22px;font-size:30px;letter-spacing:10px;font-weight:700;color:#0E0F10">' . e($code) . '</div></td></tr>'
            : '';
        $year = date('Y');
        $logo = e(app_url('assets/img/logo-mark.png'));
        return <<<HTML
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;background:#EEF1F4;font-family:Montserrat,Segoe UI,Helvetica,Arial,sans-serif;color:#0E0F10">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#EEF1F4;padding:32px 12px"><tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#fff;border-radius:24px;overflow:hidden">
<tr><td style="padding:28px 32px 8px"><table role="presentation" cellpadding="0" cellspacing="0"><tr>
<td><img src="$logo" width="32" height="32" alt="" style="display:block;border:0"></td>
<td style="padding-left:10px;font-size:20px;font-weight:600;letter-spacing:-0.4px">Dyspatch</td></tr></table></td></tr>
<tr><td style="padding:16px 32px 4px;font-size:22px;font-weight:600;letter-spacing:-0.6px">{$heading}</td></tr>
<tr><td style="padding:4px 32px 12px;font-size:15px;line-height:1.6;color:#5F6368">{$bodyHtml}</td></tr>
{$codeBlock}{$cta}
<tr><td style="padding:24px 32px 28px;font-size:12px;color:#A0A4AB;border-top:1px solid #E3E7EB">
Move everything. Trust every rider.<br>&copy; {$year} Dyspatch. You are receiving this because you use Dyspatch.</td></tr>
</table></td></tr></table></body></html>
HTML;
    }
}
