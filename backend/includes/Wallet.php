<?php
declare(strict_types=1);

/** Kobo-only ledger. Every balance change writes a wallet_transactions row with the resulting balance. */
final class Wallet
{
    public static function get(string $ownerType, int $ownerId, bool $lock = false): array
    {
        $w = DB::row('SELECT * FROM wallets WHERE owner_type = ? AND owner_id = ?' . ($lock ? ' FOR UPDATE' : ''), [$ownerType, $ownerId]);
        if ($w) return $w;
        DB::query('INSERT IGNORE INTO wallets (owner_type, owner_id, balance_kobo) VALUES (?,?,0)', [$ownerType, $ownerId]);
        return DB::row('SELECT * FROM wallets WHERE owner_type = ? AND owner_id = ?' . ($lock ? ' FOR UPDATE' : ''), [$ownerType, $ownerId]);
    }

    public static function balance(string $ownerType, int $ownerId): int
    {
        return (int) self::get($ownerType, $ownerId)['balance_kobo'];
    }

    public static function ref(string $prefix = 'TX'): string
    {
        return $prefix . '-' . date('ymd') . '-' . rand_code(6);
    }

    public static function credit(string $ownerType, int $ownerId, int $amount, string $category, string $description, ?int $orderId = null, ?string $reference = null, array $meta = []): array
    {
        return self::move('credit', $ownerType, $ownerId, $amount, $category, $description, $orderId, $reference, $meta);
    }

    public static function debit(string $ownerType, int $ownerId, int $amount, string $category, string $description, ?int $orderId = null, ?string $reference = null, array $meta = []): array
    {
        return self::move('debit', $ownerType, $ownerId, $amount, $category, $description, $orderId, $reference, $meta);
    }

    private static function move(string $type, string $ownerType, int $ownerId, int $amount, string $category, string $description, ?int $orderId, ?string $reference, array $meta): array
    {
        if ($amount <= 0) throw new ApiException('Amount must be greater than zero');
        return DB::tx(function () use ($type, $ownerType, $ownerId, $amount, $category, $description, $orderId, $reference, $meta) {
            $w = self::get($ownerType, $ownerId, true);
            $new = (int) $w['balance_kobo'] + ($type === 'credit' ? $amount : -$amount);
            if ($new < 0 && $ownerType !== 'platform') throw new ApiException('Insufficient wallet balance', 402);
            DB::update('wallets', ['balance_kobo' => $new], 'id = ?', [$w['id']]);
            $ref = $reference ?: self::ref($type === 'credit' ? 'CR' : 'DR');
            DB::insert('wallet_transactions', [
                'wallet_id' => $w['id'], 'type' => $type, 'category' => $category, 'amount_kobo' => $amount,
                'balance_after_kobo' => $new, 'reference' => $ref, 'description' => $description, 'order_id' => $orderId,
                'meta' => $meta ? json_encode($meta) : null,
            ]);
            return ['reference' => $ref, 'balance_kobo' => $new];
        });
    }

    public static function transactions(string $ownerType, int $ownerId, int $limit = 50, ?string $category = null): array
    {
        $w = self::get($ownerType, $ownerId);
        $sql = 'SELECT t.*, o.track_id, o.order_no FROM wallet_transactions t LEFT JOIN orders o ON o.id = t.order_id WHERE t.wallet_id = ?';
        $p = [$w['id']];
        if ($category) { $sql .= ' AND t.category = ?'; $p[] = $category; }
        $sql .= ' ORDER BY t.id DESC LIMIT ' . max(1, min(200, $limit));
        return DB::all($sql, $p);
    }

    /** Payout date: before cutoff (17:00 WAT) on a business day → today, else next business day. */
    public static function payoutDate(?int $ts = null): string
    {
        $ts ??= time();
        $cutoff = Settings::int('withdrawal_cutoff_hour', 17);
        $d = new DateTime('@' . $ts);
        $d->setTimezone(new DateTimeZone('Africa/Lagos'));
        $isBiz = fn(DateTime $x) => (int) $x->format('N') <= 5;
        if (!($isBiz($d) && (int) $d->format('G') < $cutoff)) {
            do { $d->modify('+1 day'); } while (!$isBiz($d));
        }
        return $d->format('Y-m-d');
    }

    /** Creates a withdrawal request and holds the funds (amount + fee) immediately. */
    public static function requestWithdrawal(string $ownerType, int $ownerId, int $bankAccountId, int $amountKobo): array
    {
        $min = Settings::int('withdrawal_min_kobo', 50000);
        if ($amountKobo < $min) throw new ApiException('Minimum withdrawal is ' . naira($min, false), 422);
        $acct = DB::row('SELECT * FROM bank_accounts WHERE id = ? AND owner_type = ? AND owner_id = ?', [$bankAccountId, $ownerType, $ownerId]);
        if (!$acct) throw new ApiException('Bank account not found', 404);
        $fee = Pricing::withdrawalFee($amountKobo);

        return DB::tx(function () use ($ownerType, $ownerId, $acct, $amountKobo, $fee) {
            $ref = 'WD-' . date('ymd') . '-' . rand_code(6);
            $bal = self::balance($ownerType, $ownerId);
            if ($bal < $amountKobo + $fee) throw new ApiException('Insufficient balance. You need ' . naira($amountKobo + $fee) . ' including the ' . naira($fee) . ' fee.', 402);
            self::debit($ownerType, $ownerId, $amountKobo, 'withdrawal', 'Transfer to ' . $acct['bank_name'] . ' •••' . substr($acct['account_number'], -4), null, $ref);
            if ($fee > 0) self::debit($ownerType, $ownerId, $fee, 'withdrawal_fee', 'Withdrawal fee', null, $ref . '-FEE');
            $id = DB::insert('withdrawals', [
                'reference' => $ref, 'owner_type' => $ownerType, 'owner_id' => $ownerId, 'bank_account_id' => $acct['id'],
                'amount_kobo' => $amountKobo, 'fee_kobo' => $fee, 'net_kobo' => $amountKobo, 'scheduled_for' => self::payoutDate(),
                'provider' => Settings::get('withdrawal_provider', 'manual'),
            ]);
            return DB::row('SELECT * FROM withdrawals WHERE id = ?', [$id]);
        });
    }

    /** Pays a withdrawal via the configured provider; falls back to manual when disbursement isn't available. */
    public static function processWithdrawal(int $id, ?int $adminId = null, bool $markPaidManually = false, ?string $note = null): array
    {
        $w = DB::row('SELECT * FROM withdrawals WHERE id = ?', [$id]);
        if (!$w || !in_array($w['status'], ['pending', 'processing'], true)) throw new ApiException('Withdrawal not pending');
        $acct = DB::row('SELECT * FROM bank_accounts WHERE id = ?', [$w['bank_account_id']]);
        $provider = Settings::get('withdrawal_provider', 'manual');

        if ($markPaidManually || $provider === 'manual' || !Payments::configured($provider)) {
            DB::update('withdrawals', ['status' => 'paid', 'provider' => 'manual', 'admin_id' => $adminId, 'note' => $note, 'processed_at' => now()], 'id = ?', [$id]);
        } else {
            $res = Payments::provider($provider)->transfer($acct, (int) $w['net_kobo'], $w['reference'], 'Dyspatch payout ' . $w['reference']);
            DB::update('withdrawals', [
                'status' => $res['ok'] ? ($res['status'] === 'success' ? 'paid' : 'processing') : 'failed',
                'provider' => $provider, 'provider_ref' => $res['provider_ref'], 'admin_id' => $adminId,
                'note' => $res['ok'] ? $note : mb_substr($res['message'], 0, 250), 'processed_at' => now(),
            ], 'id = ?', [$id]);
            if (!$res['ok']) {
                // Funds stay held; admin can retry, pay manually, or reject (which refunds).
                throw new ApiException('Provider transfer failed: ' . $res['message']);
            }
        }
        $w = DB::row('SELECT * FROM withdrawals WHERE id = ?', [$id]);
        if ($w['status'] === 'paid') self::notifyWithdrawal($w, 'paid');
        return $w;
    }

    public static function rejectWithdrawal(int $id, ?int $adminId, string $reason): void
    {
        DB::tx(function () use ($id, $adminId, $reason) {
            $w = DB::row('SELECT * FROM withdrawals WHERE id = ? FOR UPDATE', [$id]);
            if (!$w || !in_array($w['status'], ['pending', 'processing', 'failed'], true)) throw new ApiException('Withdrawal cannot be rejected');
            self::credit($w['owner_type'], (int) $w['owner_id'], (int) $w['amount_kobo'] + (int) $w['fee_kobo'], 'refund', 'Withdrawal reversed: ' . $reason, null, $w['reference'] . '-REV');
            DB::update('withdrawals', ['status' => 'rejected', 'admin_id' => $adminId, 'note' => $reason, 'processed_at' => now()], 'id = ?', [$id]);
            self::notifyWithdrawal(array_merge($w, ['note' => $reason]), 'rejected');
        });
    }

    private static function notifyWithdrawal(array $w, string $state): void
    {
        $amt = naira($w['amount_kobo']);
        if ($state === 'paid') {
            Notifier::notify($w['owner_type'], (int) $w['owner_id'], 'payment', 'Withdrawal paid', "$amt has been sent to your bank account. Ref {$w['reference']}.", ['type' => 'withdrawal', 'reference' => $w['reference']]);
        } else {
            Notifier::notify($w['owner_type'], (int) $w['owner_id'], 'payment', 'Withdrawal reversed', "Your withdrawal of $amt was reversed and refunded to your wallet. {$w['note']}", ['type' => 'withdrawal', 'reference' => $w['reference']]);
        }
    }
}
