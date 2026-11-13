<?php
declare(strict_types=1);

/**
 * Rider matching engine. Admin → Settings → Dispatch chooses how a job is offered:
 *   nearest   — to the single nearest eligible rider, then the next one if they
 *               decline or the accept window runs out (default)
 *   nearest_n — to the nearest `dispatch_batch_size` riders at once
 *   broadcast — to every eligible rider within `matching_radius_km`
 * In every mode the FIRST rider to accept gets the job (the accept is a locked,
 * conditional update, so two riders can never win the same job); everyone else's
 * offer is withdrawn and their app is told to close it.
 * Offers are pushed with a high-priority "new job" alert (see Push).
 */
final class Matching
{
    public static function eligibleRiders(array $order, int $limit = 10): array
    {
        $radius = Settings::float('matching_radius_km', 5);
        $lat = (float) $order['pickup_lat'];
        $lng = (float) $order['pickup_lng'];
        $dLat = $radius / 111.0;
        $dLng = $radius / (111.0 * max(0.2, cos(deg2rad($lat))));
        $rows = DB::all(
            "SELECT r.* FROM riders r
             WHERE r.status = 'active' AND r.kyc_status = 'verified' AND r.is_online = 1
               AND r.lat BETWEEN ? AND ? AND r.lng BETWEEN ? AND ?
               AND r.location_updated_at > (NOW() - INTERVAL 10 MINUTE)
               AND NOT EXISTS (SELECT 1 FROM orders o WHERE o.rider_id = r.id AND o.status IN ('matched','picked_up','en_route','arrived'))
               AND NOT EXISTS (SELECT 1 FROM order_offers f WHERE f.order_id = ? AND f.rider_id = r.id)
               AND NOT EXISTS (SELECT 1 FROM order_offers f2 WHERE f2.rider_id = r.id AND f2.status = 'offered' AND f2.expires_at > NOW())",
            [$lat - $dLat, $lat + $dLat, $lng - $dLng, $lng + $dLng, $order['id']]
        );
        foreach ($rows as &$r) $r['distance_km'] = haversine_km($lat, $lng, (float) $r['lat'], (float) $r['lng']);
        unset($r);
        $rows = array_values(array_filter($rows, fn($r) => $r['distance_km'] <= $radius));
        usort($rows, fn($a, $b) => $a['distance_km'] <=> $b['distance_km']);
        return array_slice($rows, 0, $limit);
    }

    public const MODES = ['nearest', 'nearest_n', 'broadcast'];

    /** How many riders one wave of offers goes to, from Admin → Settings → Dispatch. */
    public static function waveSize(): int
    {
        $mode = Settings::get('dispatch_mode', 'nearest');
        if ($mode === 'broadcast') return 50;
        if ($mode === 'nearest_n') return max(2, min(20, Settings::int('dispatch_batch_size', 3)));
        return 1;
    }

    /** Offers a pending order to the next wave of riders. Returns the first new offer row or null. */
    public static function dispatch(int $orderId): ?array
    {
        $o = Orders::find($orderId);
        if (!$o || $o['status'] !== 'pending' || $o['rider_id']) return null;
        if (DB::value("SELECT 1 FROM order_offers WHERE order_id = ? AND status = 'offered' AND expires_at > NOW()", [$orderId])) return null;
        // a "round" is one wave of offers (they share an expiry time)
        $rounds = (int) DB::value('SELECT COUNT(DISTINCT expires_at) FROM order_offers WHERE order_id = ?', [$orderId]);
        if ($rounds >= Settings::int('max_offer_rounds', 10)) return null;

        $riders = self::eligibleRiders($o, self::waveSize());
        if (!$riders) return null;
        $window = Settings::int('accept_window_seconds', 45);
        $expires = date('Y-m-d H:i:s', time() + $window);
        $first = null;
        foreach ($riders as $rider) {
            $id = DB::insert('order_offers', [
                'order_id' => $orderId, 'rider_id' => $rider['id'], 'distance_km' => round($rider['distance_km'], 2), 'expires_at' => $expires,
            ]);
            $first ??= $id;
            Notifier::notify('rider', (int) $rider['id'], 'delivery', 'New delivery request',
                'Pickup ' . round($rider['distance_km'], 1) . 'km away · Earn ' . naira($o['rider_earning_kobo'], false) . ". Accept within {$window}s.",
                ['type' => 'offer', 'offer_id' => (string) $id, 'order_id' => (string) $orderId, 'expires_in' => (string) $window], ['send' => false]);
        }
        return DB::row('SELECT * FROM order_offers WHERE id = ?', [$first]);
    }

    /** Withdraws every other open offer for an order and tells those riders' apps to close it. */
    public static function withdrawOthers(int $orderId, ?int $keepOfferId = null): void
    {
        $open = DB::all("SELECT id, rider_id FROM order_offers WHERE order_id = ? AND status = 'offered'" . ($keepOfferId ? ' AND id <> ?' : ''),
            $keepOfferId ? [$orderId, $keepOfferId] : [$orderId]);
        if (!$open) return;
        DB::query("UPDATE order_offers SET status = 'withdrawn', responded_at = NOW() WHERE order_id = ? AND status = 'offered'" . ($keepOfferId ? ' AND id <> ?' : ''),
            $keepOfferId ? [$orderId, $keepOfferId] : [$orderId]);
        foreach ($open as $f) {
            try { Push::silentToOwner('rider', (int) $f['rider_id'], ['type' => 'offer_closed', 'offer_id' => (string) $f['id'], 'order_id' => (string) $orderId]); }
            catch (Throwable $e) { log_line('push', $e->getMessage()); }
        }
    }

    /** Expire stale offers and re-offer. Safe to call often (cron + on API polls). */
    public static function tick(): array
    {
        $expired = DB::query("UPDATE order_offers SET status = 'expired', responded_at = NOW() WHERE status = 'offered' AND expires_at <= NOW()")->rowCount();
        $offered = 0;
        foreach (DB::all("SELECT id FROM orders WHERE status = 'pending' AND rider_id IS NULL AND created_at > (NOW() - INTERVAL 1 DAY) ORDER BY id LIMIT 100") as $o) {
            if (self::dispatch((int) $o['id'])) $offered++;
        }
        return ['expired' => $expired, 'offered' => $offered];
    }

    public static function accept(int $offerId, int $riderId): array
    {
        $order = DB::tx(function () use ($offerId, $riderId) {
            $f = DB::row('SELECT * FROM order_offers WHERE id = ? AND rider_id = ? FOR UPDATE', [$offerId, $riderId]);
            if (!$f || $f['status'] !== 'offered') throw new ApiException('This request is no longer available', 409);
            if (strtotime($f['expires_at']) < time()) {
                DB::update('order_offers', ['status' => 'expired', 'responded_at' => now()], 'id = ?', [$offerId]);
                throw new ApiException('This request has expired', 410);
            }
            if (DB::value("SELECT 1 FROM orders WHERE rider_id = ? AND status IN ('matched','picked_up','en_route','arrived')", [$riderId])) {
                throw new ApiException('Finish your current delivery first', 409);
            }
            $n = DB::query("UPDATE orders SET rider_id = ? WHERE id = ? AND status = 'pending' AND rider_id IS NULL", [$riderId, $f['order_id']])->rowCount();
            if ($n === 0) {
                DB::update('order_offers', ['status' => 'withdrawn', 'responded_at' => now()], 'id = ?', [$offerId]);
                throw new ApiException('Another rider accepted this job first', 409);
            }
            DB::update('order_offers', ['status' => 'accepted', 'responded_at' => now()], 'id = ?', [$offerId]);
            return (int) $f['order_id'];
        });
        self::withdrawOthers($order, $offerId);
        return Orders::setStatus($order, 'matched', 'rider', $riderId, 'Rider accepted');
    }

    public static function decline(int $offerId, int $riderId): void
    {
        $f = DB::row("SELECT * FROM order_offers WHERE id = ? AND rider_id = ? AND status = 'offered'", [$offerId, $riderId]);
        if (!$f) return;
        DB::update('order_offers', ['status' => 'declined', 'responded_at' => now()], 'id = ?', [$offerId]);
        self::dispatch((int) $f['order_id']);
    }
}
