<?php
/** Printable parcel labels — one per item, with a scannable QR linking to public tracking. */
require __DIR__ . '/_init.php';
require_admin();
$o = Orders::find((int) ($_GET['id'] ?? 0));
if (!$o) { http_response_code(404); exit('Order not found'); }
$items = DB::all('SELECT * FROM order_items WHERE order_id = ? ORDER BY id', [$o['id']]);
$total = count($items);
?>
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Labels · <?= e($o['track_id']) ?></title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700&family=JetBrains+Mono:wght@600&display=swap" rel="stylesheet">
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
<style>
  body { font-family: Montserrat, sans-serif; margin: 0; background: #EEF1F4; color: #0E0F10; }
  .bar { padding: 14px 20px; display: flex; gap: 10px; align-items: center; background: #fff; border-bottom: 1px solid #E3E7EB; }
  .bar button { background: #34A853; color: #fff; border: 0; border-radius: 12px; padding: 10px 18px; font: inherit; font-weight: 600; cursor: pointer; }
  .sheet { display: flex; flex-wrap: wrap; gap: 16px; padding: 20px; }
  .label { width: 100mm; height: 150mm; background: #fff; border-radius: 6px; padding: 7mm; box-sizing: border-box; display: flex; flex-direction: column; gap: 4mm; page-break-after: always; border: 1px solid #E3E7EB; }
  .hd { display: flex; align-items: center; gap: 8px; font-weight: 700; font-size: 18px; letter-spacing: -.5px; }
  .hd img { width: 26px; } .hd span { margin-left: auto; font-size: 11px; font-weight: 600; background: #0E0F10; color: #fff; padding: 3px 8px; border-radius: 4px; text-transform: uppercase; letter-spacing: 1px; }
  .code { font-family: 'JetBrains Mono', monospace; font-size: 26px; font-weight: 600; letter-spacing: 1px; }
  .k { font-size: 9px; text-transform: uppercase; letter-spacing: 1.4px; color: #5F6368; font-weight: 600; }
  .v { font-size: 13px; font-weight: 600; line-height: 1.35; }
  .box { border: 1.5px solid #0E0F10; border-radius: 4px; padding: 3mm; }
  .row { display: flex; gap: 4mm; align-items: flex-start; } .row > div { flex: 1; min-width: 0; }
  .qr { width: 32mm; height: 32mm; } .qr img, .qr canvas { width: 100% !important; height: auto !important; }
  .ft { margin-top: auto; display: flex; justify-content: space-between; font-size: 10px; color: #5F6368; }
  @media print { body { background: #fff; } .bar { display: none; } .sheet { padding: 0; gap: 0; } .label { border: 0; border-radius: 0; } @page { size: 100mm 150mm; margin: 0; } }
</style></head><body>
<div class="bar"><b><?= e($o['track_id']) ?></b> · <?= $total ?> label<?= $total === 1 ? '' : 's' ?><span style="flex:1"></span><button onclick="print()">Print labels</button></div>
<div class="sheet">
<?php foreach ($items as $n => $it): ?>
  <div class="label">
    <div class="hd"><img src="../assets/img/logo-mark.svg" alt=""> Dyspatch <span><?= e($o['delivery_type']) ?></span></div>
    <div class="row"><div><div class="k">Item code</div><div class="code"><?= e($it['item_code']) ?></div><div class="k" style="margin-top:2mm">Order · <?= e($o['order_no']) ?> · parcel <?= $n + 1 ?> of <?= $total ?></div></div>
      <div class="qr" data-qr="<?= e(app_url('track?id=' . urlencode($it['item_code']))) ?>"></div></div>
    <div class="box"><div class="k">Deliver to</div><div class="v" style="font-size:15px"><?= e($o['recipient_name']) ?> · <?= e($o['recipient_phone']) ?></div><div class="v" style="font-weight:500"><?= e($o['dropoff_address']) ?></div></div>
    <div><div class="k">From</div><div class="v" style="font-weight:500"><?= e(($o['sender_name'] ?: 'Sender') . ' · ' . $o['pickup_address']) ?></div></div>
    <div class="row"><div><div class="k">Contents</div><div class="v"><?= e($it['description']) ?> × <?= (int) $it['quantity'] ?></div></div><div style="flex:0 0 auto"><div class="k">Weight</div><div class="v"><?= $it['weight_kg'] !== null ? e($it['weight_kg']) . ' kg' : '—' ?></div></div></div>
    <div class="ft"><span>Track at <?= e(parse_url(app_url(), PHP_URL_HOST)) ?>/track</span><span><?= date('d M Y', strtotime($o['created_at'])) ?></span></div>
  </div>
<?php endforeach; ?>
</div>
<script>document.querySelectorAll('[data-qr]').forEach(el => new QRCode(el, { text: el.dataset.qr, width: 240, height: 240, correctLevel: QRCode.CorrectLevel.M }));</script>
</body></html>
