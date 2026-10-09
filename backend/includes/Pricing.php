<?php
declare(strict_types=1);

/**
 * Pricing engine. Supports both models behind a flag (open product decision #2):
 *  - distance_only: base + per_km × km
 *  - min_fare:      max(min_fare, base + per_km × km)
 * Zone values override global settings when set. Commission % is global or per-zone.
 */
final class Pricing
{
    public static function quote(?array $zone, float $km, string $packageType = 'medium', string $deliveryType = 'standard'): array
    {
        $model = $zone['pricing_model'] ?? null ?: Settings::get('pricing_model', 'min_fare');
        $base = (int) ($zone['base_fare_kobo'] ?? null ?? Settings::int('base_fare_kobo', 50000));
        $perKm = (int) ($zone['per_km_kobo'] ?? null ?? Settings::int('per_km_kobo', 15000));
        $minFare = (int) ($zone['min_fare_kobo'] ?? null ?? Settings::int('min_fare_kobo', 100000));

        $fee = $base + (int) round($perKm * $km);
        $fee = (int) round($fee * Settings::float('mult_' . $packageType, 1.0));
        if ($deliveryType === 'express') $fee = (int) round($fee * Settings::float('mult_express', 1.5));
        if ($model === 'min_fare') $fee = max($minFare, $fee);
        $fee = (int) (ceil($fee / 5000) * 5000); // round up to the nearest ₦50

        $pct = (float) ($zone['commission_pct'] ?? null ?? Settings::float('commission_pct', 20));
        $commission = (int) round($fee * $pct / 100);
        return [
            'fee_kobo' => $fee,
            'commission_pct' => $pct,
            'commission_kobo' => $commission,
            'rider_earning_kobo' => $fee - $commission,
            'pricing_model' => $model,
            'distance_km' => round($km, 2),
        ];
    }

    /** Withdrawal fee — pluggable (open product decision #3): flat | percent | tiered */
    public static function withdrawalFee(int $amountKobo): int
    {
        $type = Settings::get('withdrawal_fee_type', 'flat');
        $v = Settings::float('withdrawal_fee_value', 0);
        switch ($type) {
            case 'percent':
                return (int) round($amountKobo * $v / 100);
            case 'tiered':
                $tiers = json_decode((string) Settings::get('withdrawal_fee_tiers', '[]'), true) ?: [];
                foreach ($tiers as $t) if ($t['upto'] === null || $amountKobo <= (int) $t['upto']) return (int) $t['fee'];
                return 0;
            case 'none':
                return 0;
            default:
                return (int) $v;
        }
    }
}
