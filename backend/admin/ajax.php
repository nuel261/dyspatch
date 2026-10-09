<?php
/** Small JSON endpoints for admin pages (session-authenticated). */
require __DIR__ . '/_init.php';
header('Content-Type: application/json; charset=utf-8');
if (!admin()) { http_response_code(401); echo json_encode(['success' => false, 'message' => 'Signed out']); exit; }

try {
    switch ($_GET['a'] ?? '') {
        case 'quote':
            $q = Orders::quote($_GET);
            echo json_encode(['success' => true, 'data' => [
                'fee' => naira($q['fee_kobo']), 'fee_kobo' => $q['fee_kobo'], 'commission' => naira($q['commission_kobo']),
                'rider_earning' => naira($q['rider_earning_kobo']), 'distance_km' => $q['distance_km'], 'minutes' => $q['duration_minutes'],
                'zone' => $q['zone'], 'serviceable' => $q['serviceable'], 'pricing_model' => $q['pricing_model'],
            ]]);
            break;
        case 'customer':
            $phone = normalize_phone((string) ($_GET['phone'] ?? ''));
            $u = DB::row('SELECT * FROM users WHERE phone = ?', [$phone]);
            echo json_encode(['success' => true, 'data' => $u ? [
                'id' => (int) $u['id'], 'name' => trim($u['first_name'] . ' ' . $u['last_name']), 'email' => $u['email'],
                'wallet' => naira(Wallet::balance('user', (int) $u['id'])), 'wallet_kobo' => Wallet::balance('user', (int) $u['id']),
            ] : null]);
            break;
        case 'riders':
            $o = Orders::find((int) ($_GET['order'] ?? 0));
            $lat = (float) ($o['pickup_lat'] ?? $_GET['lat'] ?? 0);
            $lng = (float) ($o['pickup_lng'] ?? $_GET['lng'] ?? 0);
            $rows = DB::all("SELECT r.*, (SELECT COUNT(*) FROM orders x WHERE x.rider_id = r.id AND x.status IN ('matched','picked_up','en_route','arrived')) busy
                             FROM riders r WHERE r.status = 'active' ORDER BY r.is_online DESC, r.first_name LIMIT 300");
            $out = [];
            foreach ($rows as $r) {
                $d = ($r['lat'] !== null && $lat) ? round(haversine_km($lat, $lng, (float) $r['lat'], (float) $r['lng']), 1) : null;
                $out[] = ['id' => (int) $r['id'], 'name' => trim($r['first_name'] . ' ' . $r['last_name']), 'phone' => $r['phone'], 'vehicle' => $r['vehicle_type'],
                    'online' => (bool) $r['is_online'], 'busy' => (bool) $r['busy'], 'km' => $d, 'kyc' => $r['kyc_status']];
            }
            usort($out, fn($a, $b) => [$b['online'], !$b['busy'], -($b['km'] ?? 9999)] <=> [$a['online'], !$a['busy'], -($a['km'] ?? 9999)]);
            echo json_encode(['success' => true, 'data' => $out]);
            break;
        default:
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Unknown action']);
    }
} catch (ApiException $e) {
    http_response_code($e->status);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
} catch (Throwable $e) {
    log_line('admin', $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Something went wrong']);
}
