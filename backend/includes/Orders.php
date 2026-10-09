<?php
declare(strict_types=1);

/**
 * Order lifecycle + parcel/item tracking.
 * pending → matched → picked_up → en_route → arrived → delivered   (+ cancelled / failed)
 */
final class Orders
{
    public const ACTIVE = ['matched', 'picked_up', 'en_route', 'arrived'];
    public const LABELS = [
        'pending' => 'Finding rider', 'matched' => 'Rider assigned', 'picked_up' => 'Picked up', 'en_route' => 'In transit',
        'arrived' => 'Arrived', 'delivered' => 'Delivered', 'cancelled' => 'Cancelled', 'failed' => 'Failed',
    ];
    public const ITEM_LABELS = [
        'pending' => 'Awaiting pickup', 'picked_up' => 'Picked up', 'in_transit' => 'In transit', 'delivered' => 'Delivered',
        'returned' => 'Returned to sender', 'lost' => 'Lost', 'damaged' => 'Damaged',
    ];
    private const FLOW = [
        'pending' => ['matched', 'cancelled'],
        'matched' => ['picked_up', 'pending', 'cancelled'],
        'picked_up' => ['en_route', 'arrived', 'failed'],
        'en_route' => ['arrived', 'failed'],
        'arrived' => ['delivered', 'failed'],
        'delivered' => [], 'cancelled' => [], 'failed' => [],
    ];
    private const ITEM_FOR_ORDER = ['picked_up' => 'picked_up', 'en_route' => 'in_transit', 'arrived' => 'in_transit', 'delivered' => 'delivered', 'failed' => 'returned'];

    public static function find(int $id): ?array { return DB::row('SELECT * FROM orders WHERE id = ?', [$id]); }

    /** Accepts a Track ID (BEN-48213), order no (DY-00012) or an item code (BEN-48213-02). */
    public static function lookup(string $code): ?array
    {
        $code = strtoupper(trim($code));
        if ($code === '') return null;
        $o = DB::row('SELECT * FROM orders WHERE track_id = ? OR order_no = ?', [$code, $code]);
        if ($o) return $o;
        $item = DB::row('SELECT order_id FROM order_items WHERE item_code = ?', [$code]);
        return $item ? self::find((int) $item['order_id']) : null;
    }

    /* ───────────── Quote & create ───────────── */

    public static function resolvePoint(array $d, string $prefix): array
    {
        $addr = trim((string) ($d[$prefix . '_address'] ?? ''));
        $lat = isset($d[$prefix . '_lat']) && $d[$prefix . '_lat'] !== '' ? (float) $d[$prefix . '_lat'] : null;
        $lng = isset($d[$prefix . '_lng']) && $d[$prefix . '_lng'] !== '' ? (float) $d[$prefix . '_lng'] : null;
        if ($addr === '') throw new ApiException(ucfirst($prefix) . ' address is required', 422);
        if ($lat === null || $lng === null) {
            $hit = Geo::search($addr)[0] ?? null;
            if (!$hit) throw new ApiException("We couldn't locate the $prefix address. Pick it from the suggestions.", 422);
            [$lat, $lng] = [(float) $hit['lat'], (float) $hit['lng']];
        }
        return [$addr, $lat, $lng];
    }

    public static function quote(array $d): array
    {
        [$pa, $plat, $plng] = self::resolvePoint($d, 'pickup');
        [$da, $dlat, $dlng] = self::resolvePoint($d, 'dropoff');
        $zone = Geo::zoneFor($plat, $plng);
        $route = Geo::route($plat, $plng, $dlat, $dlng);
        $pkg = self::packageType($d['package_type'] ?? 'medium');
        $type = ($d['delivery_type'] ?? 'standard') === 'express' ? 'express' : 'standard';
        $q = Pricing::quote($zone, $route['km'], $pkg, $type);
        return $q + [
            'zone' => $zone ? ['id' => (int) $zone['id'], 'name' => $zone['name'], 'code' => $zone['code'], 'is_live' => (bool) $zone['is_live']] : null,
            'serviceable' => $zone && $zone['is_live'],
            'duration_minutes' => $route['minutes'],
            'pickup' => ['address' => $pa, 'lat' => $plat, 'lng' => $plng],
            'dropoff' => ['address' => $da, 'lat' => $dlat, 'lng' => $dlng],
            'package_type' => $pkg, 'delivery_type' => $type,
        ];
    }

    public static function packageType(string $s): string
    {
        $s = strtolower($s);
        foreach (['small', 'medium', 'large'] as $t) if (str_contains($s, $t)) return $t;
        return 'medium';
    }

    public static function create(array $d, ?array $user, string $channel = 'app', ?int $adminId = null): array
    {
        $q = self::quote($d);
        if (!$q['zone']) throw new ApiException("Pickup location is outside our service area.", 422);
        if (!$q['serviceable'] && !$adminId) throw new ApiException("We're not live in {$q['zone']['name']} yet. Coming soon!", 422);

        $recName = trim((string) ($d['recipient_name'] ?? ''));
        $recPhone = trim((string) ($d['recipient_phone'] ?? ''));
        if ($recName === '' || $recPhone === '') throw new ApiException('Recipient name and phone are required', 422);
        $recPhone = normalize_phone($recPhone);
        if (!preg_match('/^\+\d{10,15}$/', $recPhone)) throw new ApiException('Recipient phone number is invalid', 422);

        $method = in_array($d['payment_method'] ?? 'wallet', ['wallet', 'cash', 'card'], true) ? ($d['payment_method'] ?? 'wallet') : 'wallet';
        if (isset($d['fee_override_kobo']) && $adminId) {
            $q['fee_kobo'] = max(0, (int) $d['fee_override_kobo']);
            $q['commission_kobo'] = (int) round($q['fee_kobo'] * $q['commission_pct'] / 100);
            $q['rider_earning_kobo'] = $q['fee_kobo'] - $q['commission_kobo'];
        }

        $items = array_values(array_filter((array) ($d['items'] ?? []), fn($i) => trim((string) ($i['description'] ?? '')) !== ''));
        if (!$items) {
            $items = [['description' => trim((string) ($d['package_description'] ?? '')) ?: ucfirst($q['package_type']) . ' package', 'quantity' => 1]];
        }

        return DB::tx(function () use ($d, $q, $user, $channel, $adminId, $recName, $recPhone, $method, $items) {
            $trackId = self::newTrackId($q['zone']['code']);
            $id = DB::insert('orders', [
                'order_no' => 'TMP-' . bin2hex(random_bytes(5)), 'track_id' => $trackId,
                'user_id' => $user['id'] ?? null, 'created_by_admin' => $adminId, 'zone_id' => $q['zone']['id'], 'channel' => $channel,
                'sender_name' => trim((string) ($d['sender_name'] ?? '')) ?: ($user ? trim(($user['first_name'] ?? '') . ' ' . ($user['last_name'] ?? '')) : null),
                'sender_phone' => !empty($d['sender_phone']) ? normalize_phone((string) $d['sender_phone']) : ($user['phone'] ?? null),
                'pickup_address' => $q['pickup']['address'], 'pickup_lat' => $q['pickup']['lat'], 'pickup_lng' => $q['pickup']['lng'],
                'dropoff_address' => $q['dropoff']['address'], 'dropoff_lat' => $q['dropoff']['lat'], 'dropoff_lng' => $q['dropoff']['lng'],
                'recipient_name' => $recName, 'recipient_phone' => $recPhone,
                'package_type' => $q['package_type'], 'package_description' => mb_substr(trim((string) ($d['package_description'] ?? '')), 0, 255) ?: null,
                'delivery_type' => $q['delivery_type'], 'distance_km' => $q['distance_km'],
                'fee_kobo' => $q['fee_kobo'], 'commission_pct' => $q['commission_pct'], 'commission_kobo' => $q['commission_kobo'],
                'rider_earning_kobo' => $q['rider_earning_kobo'], 'payment_method' => $method,
                'eta_minutes' => $q['duration_minutes'], 'pickup_code' => digits(4), 'delivery_code' => digits(4),
            ]);
            $orderNo = 'DY-' . str_pad((string) $id, 5, '0', STR_PAD_LEFT);
            DB::update('orders', ['order_no' => $orderNo], 'id = ?', [$id]);

            foreach ($items as $n => $it) {
                DB::insert('order_items', [
                    'order_id' => $id, 'item_code' => $trackId . '-' . str_pad((string) ($n + 1), 2, '0', STR_PAD_LEFT),
                    'description' => mb_substr(trim((string) $it['description']), 0, 255), 'quantity' => max(1, (int) ($it['quantity'] ?? 1)),
                    'weight_kg' => isset($it['weight_kg']) && $it['weight_kg'] !== '' ? (float) $it['weight_kg'] : null,
                    'value_kobo' => isset($it['value']) && $it['value'] !== '' ? to_kobo($it['value']) : null,
                ]);
            }

            if ($method === 'wallet') {
                if (!$user) throw new ApiException('Wallet payment requires a customer account', 422);
                Wallet::debit('user', (int) $user['id'], (int) $q['fee_kobo'], 'delivery_payment', "Delivery payment · $orderNo", $id, "PAY-$orderNo");
                DB::update('orders', ['payment_status' => 'paid'], 'id = ?', [$id]);
            }

            self::event($id, null, 'pending', 'Order created', ($channel === 'admin' ? 'Created by dispatch team' : null), $adminId ? 'admin' : ($user ? 'user' : 'system'), $adminId ?: ($user['id'] ?? null));
            $order = self::find($id);
            return $order;
        });
    }

    private static function newTrackId(string $prefix): string
    {
        for ($i = 0; $i < 20; $i++) {
            $t = strtoupper($prefix) . '-' . random_int(10000, 99999);
            if (!DB::value('SELECT 1 FROM orders WHERE track_id = ?', [$t])) return $t;
        }
        return strtoupper($prefix) . '-' . random_int(100000, 999999);
    }

    /* ───────────── Status & events ───────────── */

    public static function event(int $orderId, ?int $itemId, string $status, string $title, ?string $note = null, string $actorType = 'system', ?int $actorId = null, ?float $lat = null, ?float $lng = null): void
    {
        DB::insert('tracking_events', [
            'order_id' => $orderId, 'item_id' => $itemId, 'status' => $status, 'title' => $title,
            'note' => $note ? mb_substr($note, 0, 255) : null, 'actor_type' => $actorType, 'actor_id' => $actorId, 'lat' => $lat, 'lng' => $lng,
        ]);
    }

    public static function setStatus(int $orderId, string $status, string $actorType, ?int $actorId, ?string $note = null, bool $force = false, ?float $lat = null, ?float $lng = null): array
    {
        $order = DB::tx(function () use ($orderId, $status, $actorType, $actorId, $note, $force, $lat, $lng) {
            $o = DB::row('SELECT * FROM orders WHERE id = ? FOR UPDATE', [$orderId]);
            if (!$o) throw new ApiException('Order not found', 404);
            if (!isset(self::LABELS[$status])) throw new ApiException('Unknown status', 422);
            if ($o['status'] === $status) return $o;
            if (!$force && !in_array($status, self::FLOW[$o['status']] ?? [], true)) {
                throw new ApiException("Cannot move order from {$o['status']} to $status", 409);
            }
            if (in_array($status, self::ACTIVE, true) && $status !== 'matched' && !$o['rider_id']) throw new ApiException('Assign a rider first', 409);

            $upd = ['status' => $status];
            $ts = ['matched' => 'matched_at', 'picked_up' => 'picked_up_at', 'arrived' => 'arrived_at', 'delivered' => 'delivered_at', 'cancelled' => 'cancelled_at'];
            if (isset($ts[$status])) $upd[$ts[$status]] = now();
            if ($status === 'cancelled' || $status === 'failed') $upd['cancel_reason'] = $note;
            if ($status === 'pending') { $upd['rider_id'] = null; $upd['matched_at'] = null; }
            if ($status === 'arrived') {
                $upd['delivery_code_expires_at'] = date('Y-m-d H:i:s', time() + Settings::int('otp_expiry_minutes', 30) * 60);
                $upd['delivery_code_attempts'] = 0;
            }
            DB::update('orders', $upd, 'id = ?', [$orderId]);

            if (isset(self::ITEM_FOR_ORDER[$status])) {
                $from = $status === 'delivered' ? "status IN ('pending','picked_up','in_transit')" : ($status === 'failed' ? "status IN ('pending','picked_up','in_transit')" : "status IN ('pending','picked_up')");
                DB::query("UPDATE order_items SET status = ? WHERE order_id = ? AND $from", [self::ITEM_FOR_ORDER[$status], $orderId]);
            }
            self::event($orderId, null, $status, self::LABELS[$status], $note, $actorType, $actorId, $lat, $lng);

            if ($status === 'delivered') self::settle(array_merge($o, $upd));
            if ($status === 'cancelled') self::refund($o, $note ?: 'Order cancelled');
            if (in_array($status, ['cancelled', 'pending', 'failed'], true)) {
                DB::query("UPDATE order_offers SET status = 'withdrawn', responded_at = NOW() WHERE order_id = ? AND status = 'offered'", [$orderId]);
            }
            return self::find($orderId);
        });

        Notifier::orderStatus($order, $status);
        if ($status === 'arrived') {
            Sms::send($order['recipient_phone'], "Your Dyspatch rider has arrived with package {$order['track_id']}. Give the rider this delivery code: {$order['delivery_code']}");
        }
        if ($status === 'matched' && $order['rider_id']) {
            Notifier::notify('rider', (int) $order['rider_id'], 'delivery', 'New delivery assigned', "Pickup: {$order['pickup_address']}", ['type' => 'order', 'order_id' => (string) $order['id']], ['send' => false]);
        }
        return $order;
    }

    public static function assignRider(int $orderId, int $riderId, string $actorType, ?int $actorId): array
    {
        $rider = DB::row("SELECT * FROM riders WHERE id = ? AND status = 'active'", [$riderId]);
        if (!$rider) throw new ApiException('Rider is not active', 422);
        DB::tx(function () use ($orderId, $riderId) {
            $o = DB::row('SELECT * FROM orders WHERE id = ? FOR UPDATE', [$orderId]);
            if (!$o || !in_array($o['status'], ['pending', 'matched'], true)) throw new ApiException('Order can no longer be reassigned', 409);
            DB::update('orders', ['rider_id' => $riderId, 'status' => 'pending'], 'id = ?', [$orderId]);
            DB::query("UPDATE order_offers SET status = 'withdrawn', responded_at = NOW() WHERE order_id = ? AND status = 'offered'", [$orderId]);
        });
        $name = trim($rider['first_name'] . ' ' . $rider['last_name']);
        return self::setStatus($orderId, 'matched', $actorType, $actorId, "Assigned to $name");
    }

    public static function setItemStatus(int $itemId, string $status, string $actorType, ?int $actorId, ?string $note = null): array
    {
        if (!isset(self::ITEM_LABELS[$status])) throw new ApiException('Unknown item status', 422);
        $item = DB::row('SELECT * FROM order_items WHERE id = ?', [$itemId]);
        if (!$item) throw new ApiException('Item not found', 404);
        DB::update('order_items', ['status' => $status], 'id = ?', [$itemId]);
        self::event((int) $item['order_id'], $itemId, 'item_' . $status, $item['item_code'] . ' · ' . self::ITEM_LABELS[$status], $note, $actorType, $actorId);
        return DB::row('SELECT * FROM order_items WHERE id = ?', [$itemId]);
    }

    /** Rider/admin enters the 4-digit code from the recipient. 3 tries, 30-min expiry. */
    public static function verifyDeliveryCode(int $orderId, string $code, int $riderId, ?float $lat = null, ?float $lng = null): array
    {
        $o = self::find($orderId);
        if (!$o || (int) $o['rider_id'] !== $riderId) throw new ApiException('Order not found', 404);
        if ($o['status'] !== 'arrived') throw new ApiException('Mark arrival before completing delivery', 409);
        $max = Settings::int('otp_max_attempts', 3);
        if ((int) $o['delivery_code_attempts'] >= $max) throw new ApiException('Code locked after too many attempts. Ask the sender to regenerate it.', 423);
        if ($o['delivery_code_expires_at'] && strtotime($o['delivery_code_expires_at']) < time()) throw new ApiException('Delivery code expired. Ask the sender to regenerate it.', 422);
        if (!hash_equals((string) $o['delivery_code'], trim($code))) {
            DB::query('UPDATE orders SET delivery_code_attempts = delivery_code_attempts + 1 WHERE id = ?', [$orderId]);
            $left = $max - (int) $o['delivery_code_attempts'] - 1;
            throw new ApiException($left > 0 ? "Wrong code. $left attempt(s) left." : 'Code locked after too many attempts.', $left > 0 ? 422 : 423);
        }
        return self::setStatus($orderId, 'delivered', 'rider', $riderId, 'Delivery code verified', false, $lat, $lng);
    }

    public static function regenerateDeliveryCode(int $orderId): array
    {
        $code = digits(4);
        DB::update('orders', [
            'delivery_code' => $code, 'delivery_code_attempts' => 0,
            'delivery_code_expires_at' => date('Y-m-d H:i:s', time() + Settings::int('otp_expiry_minutes', 30) * 60),
        ], 'id = ?', [$orderId]);
        $o = self::find($orderId);
        Sms::send($o['recipient_phone'], "Your new Dyspatch delivery code for {$o['track_id']} is $code.");
        return $o;
    }

    /* ───────────── Money ───────────── */

    private static function settle(array $o): void
    {
        if (!$o['rider_id']) return;
        $rider = (int) $o['rider_id'];
        if ($o['payment_method'] === 'cash') {
            // Rider collected the full fee in cash → platform takes its commission from the rider wallet.
            if ((int) $o['commission_kobo'] > 0) Wallet::debit('rider', $rider, (int) $o['commission_kobo'], 'commission', "Commission · {$o['order_no']} (cash)", (int) $o['id'], "COM-{$o['order_no']}");
            DB::update('orders', ['payment_status' => 'paid'], 'id = ?', [$o['id']]);
        } else {
            Wallet::credit('rider', $rider, (int) $o['rider_earning_kobo'], 'delivery_earning', "Earning · {$o['order_no']}", (int) $o['id'], "ERN-{$o['order_no']}");
        }
        if ((int) $o['commission_kobo'] > 0) Wallet::credit('platform', 0, (int) $o['commission_kobo'], 'commission', "Commission · {$o['order_no']}", (int) $o['id'], "PLT-{$o['order_no']}");
    }

    private static function refund(array $o, string $reason): void
    {
        if ($o['payment_status'] !== 'paid' || !$o['user_id'] || $o['payment_method'] === 'cash') return;
        Wallet::credit('user', (int) $o['user_id'], (int) $o['fee_kobo'], 'refund', "Refund · {$o['order_no']}", (int) $o['id'], "REF-{$o['order_no']}");
        DB::update('orders', ['payment_status' => 'refunded'], 'id = ?', [$o['id']]);
    }

    /* ───────────── Sharing ───────────── */

    public static function shareLink(int $orderId): string
    {
        $o = self::find($orderId);
        $token = $o['share_token'] ?: rand_code(16, 'abcdefghijkmnpqrstuvwxyz23456789');
        DB::update('orders', ['share_token' => $token, 'share_expires_at' => null], 'id = ?', [$orderId]);
        return app_url('t/' . $token);
    }

    /** Link stays valid while active, then for N hours after completion (configurable, open decision #7). */
    public static function shareValid(array $o): bool
    {
        $done = $o['delivered_at'] ?? $o['cancelled_at'];
        if (!in_array($o['status'], ['delivered', 'cancelled', 'failed'], true) || !$done) return true;
        return strtotime($done) + Settings::int('tracking_link_expiry_hours', 24) * 3600 > time();
    }

    /* ───────────── Presenters ───────────── */

    public static function riderPublic(?int $riderId): ?array
    {
        if (!$riderId) return null;
        $r = DB::row('SELECT * FROM riders WHERE id = ?', [$riderId]);
        if (!$r) return null;
        return [
            'id' => (int) $r['id'], 'name' => trim($r['first_name'] . ' ' . $r['last_name']),
            'photo_url' => public_file($r['photo']) ?: 'https://ui-avatars.com/api/?background=34A853&color=fff&name=' . urlencode($r['first_name'] . ' ' . $r['last_name']),
            'rating' => (float) $r['rating'], 'plate' => (string) $r['plate'], 'phone' => $r['phone'], 'vehicle_type' => $r['vehicle_type'],
            'lat' => $r['lat'] !== null ? (float) $r['lat'] : null, 'lng' => $r['lng'] !== null ? (float) $r['lng'] : null,
            'location_updated_at' => iso($r['location_updated_at']),
        ];
    }

    public static function liveEta(array $o, ?array $rider): ?int
    {
        if (in_array($o['status'], ['arrived', 'delivered', 'cancelled', 'failed'], true)) return 0;
        if (!$rider || $rider['lat'] === null) return $o['eta_minutes'] !== null ? (int) $o['eta_minutes'] : null;
        $toPickup = $o['status'] === 'matched';
        $tLat = (float) ($toPickup ? $o['pickup_lat'] : $o['dropoff_lat']);
        $tLng = (float) ($toPickup ? $o['pickup_lng'] : $o['dropoff_lng']);
        $km = haversine_km((float) $rider['lat'], (float) $rider['lng'], $tLat, $tLng) * Settings::float('road_factor', 1.3);
        $eta = Geo::etaMinutes($km);
        if ($toPickup) $eta += Geo::etaMinutes((float) $o['distance_km']);
        return $eta;
    }

    public static function items(int $orderId): array
    {
        return array_map(fn($i) => [
            'id' => (int) $i['id'], 'item_code' => $i['item_code'], 'description' => $i['description'], 'quantity' => (int) $i['quantity'],
            'weight_kg' => $i['weight_kg'] !== null ? (float) $i['weight_kg'] : null, 'status' => $i['status'],
            'status_label' => self::ITEM_LABELS[$i['status']] ?? $i['status'], 'updated_at' => iso($i['updated_at']),
        ], DB::all('SELECT * FROM order_items WHERE order_id = ? ORDER BY id', [$orderId]));
    }

    public static function timeline(int $orderId): array
    {
        return array_map(fn($e) => [
            'status' => $e['status'], 'label' => $e['title'], 'note' => $e['note'], 'item_id' => $e['item_id'] ? (int) $e['item_id'] : null,
            'time' => iso($e['created_at']), 'lat' => $e['lat'] !== null ? (float) $e['lat'] : null, 'lng' => $e['lng'] !== null ? (float) $e['lng'] : null,
        ], DB::all('SELECT * FROM tracking_events WHERE order_id = ? ORDER BY created_at, id', [$orderId]));
    }

    /** Full payload for the owner (customer app). Shape matches the app's RideModel. */
    public static function present(array $o, bool $owner = true): array
    {
        $rider = self::riderPublic($o['rider_id'] ? (int) $o['rider_id'] : null);
        $itemsCount = (int) DB::value('SELECT COALESCE(SUM(quantity),0) FROM order_items WHERE order_id = ?', [$o['id']]);
        $out = [
            'id' => (int) $o['id'],
            'order_id' => $o['track_id'],
            'order_no' => $o['order_no'],
            'track_id' => $o['track_id'],
            'status' => $o['status'],
            'status_label' => self::LABELS[$o['status']] ?? $o['status'],
            'pickup' => ['address' => $o['pickup_address'], 'lat' => (float) $o['pickup_lat'], 'lng' => (float) $o['pickup_lng']],
            'dropoff' => ['address' => $o['dropoff_address'], 'lat' => (float) $o['dropoff_lat'], 'lng' => (float) $o['dropoff_lng']],
            'route' => self::shortRoute($o),
            'eta_minutes' => self::liveEta($o, $rider) ?? 0,
            'rider' => $rider,
            'package_type' => $o['package_type'],
            'package_description' => $o['package_description'],
            'delivery_type' => $o['delivery_type'],
            'items_count' => $itemsCount,
            'items' => self::items((int) $o['id']),
            'timeline' => self::timeline((int) $o['id']),
            'distance_km' => (float) $o['distance_km'],
            'created_at' => iso($o['created_at']),
            'arrived_at' => iso($o['arrived_at']),
            'delivered_at' => iso($o['delivered_at']),
        ];
        if ($owner) {
            $out += [
                'recipient_name' => $o['recipient_name'], 'recipient_phone' => $o['recipient_phone'],
                'fee_kobo' => (int) $o['fee_kobo'], 'fee' => naira($o['fee_kobo'], false),
                'payment_method' => $o['payment_method'], 'payment_status' => $o['payment_status'],
                'pickup_code' => in_array($o['status'], ['pending', 'matched'], true) ? $o['pickup_code'] : null,
                'delivery_code' => in_array($o['status'], self::ACTIVE, true) ? $o['delivery_code'] : null,
                'cancel_reason' => $o['cancel_reason'],
                'can_cancel' => in_array($o['status'], ['pending', 'matched'], true),
            ];
        } else {
            if ($out['rider']) { unset($out['rider']['phone']); }
        }
        return $out;
    }

    public static function shortRoute(array $o): string
    {
        $f = fn($a) => trim(explode(',', (string) $a)[0]);
        return $f($o['pickup_address']) . ' → ' . $f($o['dropoff_address']);
    }

    /** Breadcrumb trail of the rider for this order (for maps). */
    public static function trail(int $orderId, int $limit = 300): array
    {
        $rows = DB::all('SELECT lat, lng FROM rider_locations WHERE order_id = ? ORDER BY id DESC LIMIT ' . $limit, [$orderId]);
        return array_reverse(array_map(fn($r) => [(float) $r['lat'], (float) $r['lng']], $rows));
    }
}
