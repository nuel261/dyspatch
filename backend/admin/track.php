<?php
require __DIR__ . '/_init.php';
require_admin();
$q = trim((string) ($_GET['q'] ?? ''));
if ($q === '') redirect('orders.php');
if ($o = Orders::lookup($q)) {
    $item = DB::row('SELECT id FROM order_items WHERE item_code = ?', [strtoupper($q)]);
    redirect('order.php?id=' . $o['id'] . ($item ? '#item-' . $item['id'] : ''));
}
$phone = normalize_phone($q);
if (preg_match('/^\+\d{10,15}$/', $phone)) {
    if ($u = DB::row('SELECT id FROM users WHERE phone = ?', [$phone])) redirect('customer.php?id=' . $u['id']);
    if ($r = DB::row('SELECT id FROM riders WHERE phone = ?', [$phone])) redirect('rider.php?id=' . $r['id']);
}
redirect('orders.php?q=' . urlencode($q));
