<?php
declare(strict_types=1);
/**
 * Provider abstractions. Business logic only talks to the interfaces; which
 * implementation is used is chosen in Admin → Settings (no redeploy needed).
 */

/* ───────────────────────────── SMS / OTP ───────────────────────────── */
interface SmsProvider { public function send(string $phone, string $message): bool; }

final class LogSms implements SmsProvider
{
    public function send(string $phone, string $message): bool
    {
        log_line('sms', "$phone: $message");
        return true;
    }
}

final class TermiiSms implements SmsProvider
{
    public function send(string $phone, string $message): bool
    {
        $r = http_request('POST', 'https://api.ng.termii.com/api/sms/send', [], [
            'to' => ltrim($phone, '+'),
            'from' => Settings::get('termii_sender_id', 'Dyspatch'),
            'sms' => $message,
            'type' => 'plain',
            'channel' => Settings::get('termii_channel', 'dnd'),
            'api_key' => Settings::get('termii_api_key'),
        ]);
        $ok = $r['status'] >= 200 && $r['status'] < 300;
        if (!$ok) log_line('sms', "Termii failed ($phone): " . $r['body']);
        return $ok;
    }
}

final class Sms
{
    public static function driver(): SmsProvider
    {
        return (Settings::get('sms_driver') === 'termii' && Settings::get('termii_api_key')) ? new TermiiSms() : new LogSms();
    }
    public static function send(string $phone, string $message): bool { return self::driver()->send($phone, $message); }
    public static function isLive(): bool { return self::driver() instanceof TermiiSms; }
}

/* ───────────────────────────── Payments ───────────────────────────── */
interface PaymentProvider
{
    /** @return array{authorization_url:string, reference:string} */
    public function initialize(string $email, int $amountKobo, string $reference, string $callbackUrl): array;
    /** @return array{paid:bool, amount_kobo:int} */
    public function verify(string $reference): array;
    /** @return array{ok:bool, provider_ref:?string, status:string, message:string} */
    public function transfer(array $bankAccount, int $amountKobo, string $reference, string $reason): array;
    public function verifyWebhook(string $rawBody, array $headers): bool;
    /** @return array<int,array{name:string,code:string}> */
    public function banks(): array;
}

final class PaystackProvider implements PaymentProvider
{
    private function h(): array { return ['Authorization' => 'Bearer ' . Settings::get('paystack_secret_key')]; }

    public function initialize(string $email, int $amountKobo, string $reference, string $callbackUrl): array
    {
        $r = http_request('POST', 'https://api.paystack.co/transaction/initialize', $this->h(), [
            'email' => $email, 'amount' => $amountKobo, 'reference' => $reference, 'callback_url' => $callbackUrl,
        ]);
        if (!($r['json']['status'] ?? false)) throw new ApiException($r['json']['message'] ?? 'Payment initialisation failed', 502);
        return ['authorization_url' => $r['json']['data']['authorization_url'], 'reference' => $reference];
    }

    public function verify(string $reference): array
    {
        $r = http_request('GET', 'https://api.paystack.co/transaction/verify/' . rawurlencode($reference), $this->h());
        $d = $r['json']['data'] ?? [];
        return ['paid' => ($d['status'] ?? '') === 'success', 'amount_kobo' => (int) ($d['amount'] ?? 0)];
    }

    public function transfer(array $acct, int $amountKobo, string $reference, string $reason): array
    {
        $code = $acct['recipient_code'] ?? null;
        if (!$code) {
            $r = http_request('POST', 'https://api.paystack.co/transferrecipient', $this->h(), [
                'type' => 'nuban', 'name' => $acct['account_name'], 'account_number' => $acct['account_number'],
                'bank_code' => $acct['bank_code'], 'currency' => 'NGN',
            ]);
            $code = $r['json']['data']['recipient_code'] ?? null;
            if (!$code) return ['ok' => false, 'provider_ref' => null, 'status' => 'failed', 'message' => $r['json']['message'] ?? 'Could not create recipient'];
            DB::update('bank_accounts', ['recipient_code' => $code], 'id = ?', [$acct['id']]);
        }
        $r = http_request('POST', 'https://api.paystack.co/transfer', $this->h(), [
            'source' => 'balance', 'amount' => $amountKobo, 'recipient' => $code, 'reason' => $reason, 'reference' => $reference,
        ]);
        $ok = (bool) ($r['json']['status'] ?? false);
        return ['ok' => $ok, 'provider_ref' => $r['json']['data']['transfer_code'] ?? null,
            'status' => $r['json']['data']['status'] ?? ($ok ? 'pending' : 'failed'), 'message' => $r['json']['message'] ?? ''];
    }

    public function verifyWebhook(string $rawBody, array $headers): bool
    {
        $sig = $headers['x-paystack-signature'] ?? '';
        return $sig !== '' && hash_equals(hash_hmac('sha512', $rawBody, (string) Settings::get('paystack_secret_key')), $sig);
    }

    public function banks(): array
    {
        $r = http_request('GET', 'https://api.paystack.co/bank?country=nigeria&perPage=200', $this->h());
        return array_map(fn($b) => ['name' => $b['name'], 'code' => $b['code']], $r['json']['data'] ?? []);
    }
}

final class FlutterwaveProvider implements PaymentProvider
{
    private function h(): array { return ['Authorization' => 'Bearer ' . Settings::get('flutterwave_secret_key')]; }

    public function initialize(string $email, int $amountKobo, string $reference, string $callbackUrl): array
    {
        $r = http_request('POST', 'https://api.flutterwave.com/v3/payments', $this->h(), [
            'tx_ref' => $reference, 'amount' => $amountKobo / 100, 'currency' => 'NGN', 'redirect_url' => $callbackUrl,
            'customer' => ['email' => $email],
        ]);
        if (($r['json']['status'] ?? '') !== 'success') throw new ApiException($r['json']['message'] ?? 'Payment initialisation failed', 502);
        return ['authorization_url' => $r['json']['data']['link'], 'reference' => $reference];
    }

    public function verify(string $reference): array
    {
        $r = http_request('GET', 'https://api.flutterwave.com/v3/transactions/verify_by_reference?tx_ref=' . rawurlencode($reference), $this->h());
        $d = $r['json']['data'] ?? [];
        return ['paid' => ($d['status'] ?? '') === 'successful', 'amount_kobo' => (int) round(((float) ($d['amount'] ?? 0)) * 100)];
    }

    public function transfer(array $acct, int $amountKobo, string $reference, string $reason): array
    {
        $r = http_request('POST', 'https://api.flutterwave.com/v3/transfers', $this->h(), [
            'account_bank' => $acct['bank_code'], 'account_number' => $acct['account_number'], 'amount' => $amountKobo / 100,
            'narration' => $reason, 'currency' => 'NGN', 'reference' => $reference,
        ]);
        $ok = ($r['json']['status'] ?? '') === 'success';
        return ['ok' => $ok, 'provider_ref' => isset($r['json']['data']['id']) ? (string) $r['json']['data']['id'] : null,
            'status' => $ok ? 'pending' : 'failed', 'message' => $r['json']['message'] ?? ''];
    }

    public function verifyWebhook(string $rawBody, array $headers): bool
    {
        $hash = $headers['verif-hash'] ?? '';
        return $hash !== '' && hash_equals((string) Settings::get('flutterwave_webhook_hash', ''), $hash);
    }

    public function banks(): array
    {
        $r = http_request('GET', 'https://api.flutterwave.com/v3/banks/NG', $this->h());
        return array_map(fn($b) => ['name' => $b['name'], 'code' => $b['code']], $r['json']['data'] ?? []);
    }
}

final class Payments
{
    public static function provider(?string $name = null): PaymentProvider
    {
        $name = $name ?: Settings::get('payment_provider', 'paystack');
        return $name === 'flutterwave' ? new FlutterwaveProvider() : new PaystackProvider();
    }
    public static function configured(?string $name = null): bool
    {
        $name = $name ?: Settings::get('payment_provider', 'paystack');
        return (bool) Settings::get($name === 'flutterwave' ? 'flutterwave_secret_key' : 'paystack_secret_key');
    }
}

/* ───────────────────────────── KYC / ID verification ───────────────────────────── */
interface KycProvider
{
    /** @return array{status:string, reference:?string, message:string} status: verified|failed|pending */
    public function verify(string $idType, string $idNumber, string $firstName, string $lastName): array;
}

final class ManualKyc implements KycProvider
{
    public function verify(string $idType, string $idNumber, string $firstName, string $lastName): array
    {
        return ['status' => 'pending', 'reference' => null, 'message' => 'Queued for manual review'];
    }
}

final class PremblyKyc implements KycProvider
{
    public function verify(string $idType, string $idNumber, string $firstName, string $lastName): array
    {
        $endpoints = ['nin' => 'nin_wo_face', 'bvn' => 'bvn_validation', 'drivers_license' => 'drivers_license', 'voters_card' => 'voters_card'];
        $ep = $endpoints[$idType] ?? 'nin_wo_face';
        $r = http_request('POST', "https://api.prembly.com/identitypass/verification/$ep", [
            'x-api-key' => Settings::get('prembly_api_key'), 'app-id' => Settings::get('prembly_app_id'),
        ], ['number' => $idNumber, 'first_name' => $firstName, 'last_name' => $lastName]);
        $ok = (bool) ($r['json']['status'] ?? false);
        return ['status' => $ok ? 'verified' : 'failed', 'reference' => $r['json']['verification']['reference'] ?? null, 'message' => $r['json']['detail'] ?? ''];
    }
}

final class SmileKyc implements KycProvider
{
    public function verify(string $idType, string $idNumber, string $firstName, string $lastName): array
    {
        $partner = (string) Settings::get('smile_partner_id');
        $ts = date('c');
        $sig = base64_encode(hash_hmac('sha256', $ts . $partner . 'sid_request', (string) Settings::get('smile_api_key'), true));
        $types = ['nin' => 'NIN_V2', 'bvn' => 'BVN', 'drivers_license' => 'DRIVERS_LICENSE', 'voters_card' => 'VOTER_ID'];
        $r = http_request('POST', 'https://api.smileidentity.com/v1/id_verification', [], [
            'partner_id' => $partner, 'timestamp' => $ts, 'signature' => $sig, 'country' => 'NG',
            'id_type' => $types[$idType] ?? 'NIN_V2', 'id_number' => $idNumber, 'first_name' => $firstName, 'last_name' => $lastName,
            'partner_params' => ['job_id' => uniqid('kyc', true), 'user_id' => $idNumber, 'job_type' => 5],
        ]);
        $code = $r['json']['ResultCode'] ?? '';
        return ['status' => $code === '1012' ? 'verified' : ($code === '' ? 'pending' : 'failed'),
            'reference' => $r['json']['SmileJobID'] ?? null, 'message' => $r['json']['ResultText'] ?? ''];
    }
}

final class Kyc
{
    public static function provider(): KycProvider
    {
        return match (Settings::get('kyc_provider', 'manual')) {
            'prembly' => Settings::get('prembly_api_key') ? new PremblyKyc() : new ManualKyc(),
            'smile' => Settings::get('smile_api_key') ? new SmileKyc() : new ManualKyc(),
            default => new ManualKyc(),
        };
    }
}
