<?php
require __DIR__ . '/_init.php';
require_admin();
header('Content-Type: application/json');
Matching::tick();

$riders = array_map(fn($r) => [
    'id' => (int) $r['id'], 'name' => trim($r['first_name'] . ' ' . $r['last_name']), 'phone' => $r['phone'], 'plate' => $r['plate'],
    'vehicle' => $r['vehicle_type'], 'lat' => (float) $r['lat'], 'lng' => (float) $r['lng'], 'busy' => (bool) $r['busy'],
    'seen' => time_ago($r['location_updated_at']),
], DB::all("SELECT r.*, EXISTS(SELECT 1 FROM orders o WHERE o.rider_id = r.id AND o.status IN ('matched','picked_up','en_route','arrived')) busy
    FROM riders r WHERE r.is_online = 1 AND r.lat IS NOT NULL AND r.location_updated_at > NOW() - INTERVAL 30 MINUTE"));

$orders = array_map(fn($o) => [
    'id' => (int) $o['id'], 'track_id' => $o['track_id'], 'status' => $o['status'], 'label' => Orders::LABELS[$o['status']],
    'route' => Orders::shortRoute($o), 'rider_id' => $o['rider_id'] ? (int) $o['rider_id'] : null,
    'pickup' => [(float) $o['pickup_lat'], (float) $o['pickup_lng']], 'dropoff' => [(float) $o['dropoff_lat'], (float) $o['dropoff_lng']],
], DB::all("SELECT * FROM orders WHERE status IN ('pending','matched','picked_up','en_route','arrived') ORDER BY id DESC LIMIT 300"));

echo json_encode(['riders' => $riders, 'orders' => $orders, 'at' => date('H:i:s')]);
