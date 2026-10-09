<?php
/** Public parcel tracking — styled after dyspatch.com.ng. /track?id=BEN-48213 · /t/{share-token} */
require __DIR__ . '/includes/bootstrap.php';
$id = strtoupper(trim((string) ($_GET['id'] ?? $_GET['q'] ?? '')));
$share = preg_replace('/[^a-z0-9]/i', '', (string) ($_GET['s'] ?? ''));
$order = null;
$error = null;
try {
    if ($share !== '') {
        $order = DB::row('SELECT * FROM orders WHERE share_token = ?', [$share]);
        if (!$order || !Orders::shareValid($order)) { $order = null; $error = 'This tracking link has expired.'; }
    } elseif ($id !== '') {
        $order = Orders::lookup($id);
        if (!$order) $error = "We couldn't find a package with Track ID “" . $id . "”. Check the ID and try again.";
    }
} catch (Throwable $e) { $error = 'Tracking is temporarily unavailable.'; }
$data = $order ? Orders::present($order, false) : null;
$item = $order && $id ? DB::row('SELECT * FROM order_items WHERE item_code = ?', [$id]) : null;
$steps = ['pending' => 'Created', 'matched' => 'Rider assigned', 'picked_up' => 'Picked up', 'en_route' => 'In transit', 'arrived' => 'Arrived', 'delivered' => 'Delivered'];
$order_idx = $order ? array_search($order['status'], array_keys($steps), true) : false;
$apiPath = $share !== '' ? 'api/shared/' . $share : ($order ? 'api/track/' . rawurlencode($id) : '');
$live = $order && in_array($order['status'], ['pending', 'matched', 'picked_up', 'en_route', 'arrived'], true);
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= $order ? e($order['track_id']) . ' · ' : '' ?>Track a package · Dyspatch</title>
<meta name="description" content="Track your Dyspatch delivery live.">
<meta name="theme-color" content="#0E120F">
<link rel="icon" href="assets/img/favicon.png">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css">
<style>
  :root { --brand:#34A853; --brand-600:#298341; --alpha:#34A8531A; --text:#0E0F10; --muted:#5F6368; --faint:#A0A4AB; --border:#E3E7EB; --surface:#fff; --surface-2:#EEF1F4; --bg:#fff; --dark:#0E120F; }
  @media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --text:#F2F4F5; --muted:#A0A4AB; --faint:#6B7078; --border:#262B30; --surface:#141816; --surface-2:#1B1F24; --bg:#0B0D0C; --alpha:#34A85326; } }
  * { box-sizing: border-box; } html, body { margin: 0; }
  body { font-family: Montserrat, system-ui, sans-serif; color: var(--text); background: var(--bg); -webkit-font-smoothing: antialiased; line-height: 1.5;
    background-image: radial-gradient(var(--border) 1px, transparent 1px); background-size: 18px 18px; min-height: 100vh; }
  a { color: inherit; text-decoration: none; }
  .wrap { width: min(1080px, 100% - 32px); margin: 0 auto; }
  header { height: 68px; display: flex; align-items: center; justify-content: space-between; }
  .logo { display: flex; align-items: center; gap: 10px; font-size: 21px; font-weight: 600; letter-spacing: -.04em; }
  .logo img { width: 30px; height: 30px; }
  header nav a { font-size: 13px; color: var(--muted); font-weight: 500; margin-left: 18px; }
  .ticker { font-family: 'JetBrains Mono', monospace; font-size: 11px; letter-spacing: .1em; text-transform: uppercase; color: var(--muted); text-align: center; padding: 10px 0 0; }
  .ticker b { color: var(--brand); font-weight: 600; }
  .hero { text-align: center; padding: 48px 0 28px; }
  h1 { font-size: clamp(30px, 5vw, 46px); font-weight: 600; letter-spacing: -.045em; line-height: 1.1; margin: 0; }
  h1 em { font-style: normal; color: var(--brand); }
  .lead { color: var(--muted); margin: 14px 0 26px; }
  .search { display: flex; gap: 8px; max-width: 520px; margin: 0 auto; background: var(--surface); border: 1px solid var(--border); border-radius: 32px; padding: 6px 6px 6px 20px; box-shadow: 0 8px 30px rgba(14,15,16,.06); }
  .search input { flex: 1; border: 0; outline: 0; font: inherit; font-size: 15px; background: transparent; color: var(--text); text-transform: uppercase; min-width: 0; }
  .search input::placeholder { text-transform: none; color: var(--faint); }
  .search button { background: var(--brand); color: #fff; border: 0; font: inherit; font-weight: 600; font-size: 14px; border-radius: 32px; padding: 12px 22px; cursor: pointer; }
  .search button:hover { background: #2E8E47; }
  .err { max-width: 520px; margin: 14px auto 0; background: #EA43351A; color: #D33426; border-radius: 12px; padding: 12px 16px; font-size: 14px; font-weight: 500; }
  .result { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); gap: 20px; padding-bottom: 60px; }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: 24px; overflow: hidden; }
  .pad { padding: 22px 24px; }
  .k { font-size: 11px; font-weight: 600; letter-spacing: .12em; text-transform: uppercase; color: var(--muted); }
  .tid { font-family: 'JetBrains Mono', monospace; font-size: 22px; font-weight: 600; letter-spacing: .04em; }
  .status { display: inline-flex; align-items: center; gap: 8px; border-radius: 99px; padding: 6px 12px; font-weight: 600; font-size: 13px; background: var(--alpha); color: var(--brand-600); }
  .status::before { content: ''; width: 8px; height: 8px; border-radius: 50%; background: currentColor; }
  .status.bad { background: #EA43351A; color: #D33426; } .status.wait { background: #FBBC0522; color: #B88704; }
  .head { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; flex-wrap: wrap; }
  .big { font-size: 26px; font-weight: 600; letter-spacing: -.04em; margin: 16px 0 4px; }
  .steps { display: grid; grid-template-columns: repeat(6, 1fr); gap: 6px; margin-top: 20px; }
  .steps div { font-size: 11px; font-weight: 600; color: var(--faint); display: flex; flex-direction: column; gap: 8px; }
  .steps div::before { content: ''; height: 5px; border-radius: 5px; background: var(--border); }
  .steps div.on { color: var(--text); } .steps div.on::before { background: var(--brand); }
  #map { height: 360px; background: var(--surface-2); }
  .route { display: grid; grid-template-columns: 14px 1fr; gap: 0 12px; margin-top: 4px; }
  .route .p { width: 12px; height: 12px; border-radius: 50%; margin-top: 4px; } .route .p.a { border: 2px solid var(--text); } .route .p.b { background: var(--brand); }
  .route .l { width: 2px; background: var(--border); margin-left: 5px; min-height: 22px; }
  .route .t { font-weight: 600; font-size: 14px; } .route .s { font-size: 12px; color: var(--muted); margin-bottom: 10px; }
  .rider { display: flex; align-items: center; gap: 12px; background: var(--surface-2); border-radius: 16px; padding: 12px 14px; margin-top: 16px; }
  .rider img { width: 42px; height: 42px; border-radius: 50%; object-fit: cover; }
  ul.tl { list-style: none; margin: 0; padding: 0; }
  ul.tl li { position: relative; padding: 0 0 18px 26px; }
  ul.tl li::before { content: ''; position: absolute; left: 6px; top: 16px; bottom: 0; width: 2px; background: var(--border); }
  ul.tl li:last-child::before { display: none; }
  ul.tl li i { position: absolute; left: 0; top: 4px; width: 14px; height: 14px; border-radius: 50%; border: 2px solid var(--brand); background: var(--brand); box-shadow: inset 0 0 0 3px var(--surface); }
  ul.tl li.it i { border-color: #2F6F73; background: var(--surface); width: 12px; height: 12px; left: 1px; }
  ul.tl b { font-weight: 600; font-size: 14px; } ul.tl time { float: right; font-size: 12px; color: var(--muted); } ul.tl p { margin: 2px 0 0; font-size: 12.5px; color: var(--muted); }
  .items { display: flex; flex-direction: column; gap: 8px; }
  .item { display: flex; justify-content: space-between; align-items: center; gap: 10px; border: 1px solid var(--border); border-radius: 12px; padding: 10px 12px; font-size: 13px; }
  .item.hl { border-color: var(--brand); background: var(--alpha); }
  .item .code { font-family: 'JetBrains Mono', monospace; font-weight: 600; font-size: 12px; }
  .pill { font-size: 11.5px; font-weight: 600; padding: 3px 9px; border-radius: 99px; background: var(--surface-2); color: var(--muted); white-space: nowrap; }
  .pill.ok { background: var(--alpha); color: var(--brand-600); }
  .cta { background: var(--dark); color: #fff; border-radius: 24px; padding: 24px; display: flex; flex-direction: column; gap: 12px; }
  .cta p { color: #A0A4AB; margin: 0; font-size: 14px; }
  .stores { display: flex; gap: 10px; flex-wrap: wrap; }
  .stores a { border: 1px solid #B5E8C3; background: #012109; color: #fff; border-radius: 14px; padding: 8px 14px; font-size: 13px; font-weight: 600; }
  .live { font-family: 'JetBrains Mono', monospace; font-size: 11px; color: var(--muted); letter-spacing: .08em; text-transform: uppercase; }
  .live::before { content: ''; display: inline-block; width: 7px; height: 7px; border-radius: 50%; background: var(--brand); margin-right: 6px; animation: p 2s infinite; }
  @keyframes p { 50% { opacity: .3; } }
  footer { text-align: center; color: var(--faint); font-size: 12px; padding: 30px 0 40px; }
  .mk { width: 30px; height: 30px; border-radius: 50%; border: 3px solid #fff; box-shadow: 0 2px 8px rgba(0,0,0,.3); display: grid; place-items: center; color: #fff; font-size: 13px; }
  @media (max-width: 820px) { .result { grid-template-columns: 1fr; } .steps div { font-size: 0; gap: 0; } header nav { display: none; } }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <a class="logo" href="https://www.dyspatch.com.ng"><img src="assets/img/logo-mark.svg" alt=""> Dyspatch</a>
    <nav><a href="https://www.dyspatch.com.ng/for-business">For Businesses</a><a href="https://www.dyspatch.com.ng/for-riders">For Riders</a></nav>
  </header>
  <div class="ticker">Track · <b>Live</b> · Benin City & Lagos</div>

  <section class="hero">
    <h1><?= $order ? 'Where’s my <em>package</em>?' : 'Track your <em>package</em> live.' ?></h1>
    <p class="lead">Enter the Track ID from your app, SMS or parcel label.</p>
    <form class="search" action="track" method="get" onsubmit="if(location.pathname.endsWith('.php')){this.action='track.php'}">
      <input name="id" value="<?= e($share ? '' : $id) ?>" placeholder="e.g. BEN-48213" autocomplete="off" aria-label="Track ID" required>
      <button>Track →</button>
    </form>
    <?php if ($error): ?><div class="err"><?= e($error) ?></div><?php endif; ?>
  </section>

  <?php if ($data): $st = $order['status']; $bad = in_array($st, ['cancelled', 'failed'], true); ?>
  <section class="result">
    <div style="display:flex;flex-direction:column;gap:20px">
      <div class="card"><div class="pad">
        <div class="head"><div><div class="k">Track ID</div><div class="tid"><?= e($data['track_id']) ?></div></div>
          <span class="status <?= $bad ? 'bad' : ($st === 'pending' ? 'wait' : '') ?>" id="stLabel"><?= e($data['status_label']) ?></span></div>
        <div class="big" id="headline"><?php
          if ($st === 'delivered') echo 'Delivered ' . e(date('D j M, g:ia', strtotime($order['delivered_at'])));
          elseif ($st === 'arrived') echo 'Your rider has arrived';
          elseif ($bad) echo 'This delivery was ' . e($st);
          elseif ($st === 'pending') echo 'Finding a nearby rider…';
          else echo 'Arriving in ~' . (int) $data['eta_minutes'] . ' min';
        ?></div>
        <?php if ($live): ?><div class="live" id="liveTag">Live · updates automatically</div><?php endif; ?>
        <?php if (!$bad): ?><div class="steps"><?php $i = 0; foreach ($steps as $k => $l): ?><div class="<?= $order_idx !== false && $i <= $order_idx ? 'on' : '' ?>"><?= e($l) ?></div><?php $i++; endforeach; ?></div><?php endif; ?>
      </div>
      <div id="map"></div>
      <div class="pad">
        <div class="route"><span class="p a"></span><div><div class="t"><?= e($data['pickup']['address']) ?></div><div class="s">Pickup</div></div>
          <span class="l"></span><span></span><span class="p b"></span><div><div class="t"><?= e($data['dropoff']['address']) ?></div><div class="s">Drop-off</div></div></div>
        <?php if ($data['rider']): ?><div class="rider"><img src="<?= e($data['rider']['photo_url']) ?>" alt=""><div style="flex:1"><b><?= e($data['rider']['name']) ?></b><div class="s" style="font-size:12px;color:var(--muted)">★ <?= number_format($data['rider']['rating'], 1) ?> · <?= e(ucfirst((string) $data['rider']['vehicle_type'])) ?> · <span style="font-family:'JetBrains Mono',monospace"><?= e($data['rider']['plate']) ?></span></div></div></div><?php endif; ?>
      </div></div>
    </div>
    <div style="display:flex;flex-direction:column;gap:20px">
      <div class="card pad"><div class="k" style="margin-bottom:12px">Parcels in this delivery</div><div class="items">
        <?php foreach ($data['items'] as $it): ?><div class="item <?= $item && (int) $item['id'] === $it['id'] ? 'hl' : '' ?>"><div><div class="code"><?= e($it['item_code']) ?></div><div><?= e($it['description']) ?><?= $it['quantity'] > 1 ? ' × ' . $it['quantity'] : '' ?></div></div><span class="pill <?= $it['status'] === 'delivered' ? 'ok' : '' ?>"><?= e($it['status_label']) ?></span></div><?php endforeach; ?>
      </div></div>
      <div class="card pad"><div class="k" style="margin-bottom:14px">Delivery timeline</div><ul class="tl" id="tl">
        <?php foreach (array_reverse($data['timeline']) as $ev): ?><li class="<?= $ev['item_id'] ? 'it' : '' ?>"><i></i><time><?= e(date('j M, g:ia', strtotime($ev['time']))) ?></time><b><?= e($ev['label']) ?></b><?= $ev['note'] ? '<p>' . e($ev['note']) . '</p>' : '' ?></li><?php endforeach; ?>
      </ul></div>
      <div class="cta"><b style="font-size:18px;letter-spacing:-.02em">Send a package in seconds.</b><p>Get live tracking, OTP-secured handover and wallet payments in the Dyspatch app.</p>
        <div class="stores"><a href="https://play.google.com/store/apps/details?id=com.dyspatch.delivery">Google Play</a><a href="https://apps.apple.com/">App Store</a></div></div>
    </div>
  </section>
  <?php endif; ?>
  <footer>© <?= date('Y') ?> Dyspatch. Move everything. Trust every rider.</footer>
</div>
<?php if ($data): ?>
<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js"></script>
<script>
(function(){
  let d = <?= json_encode($data + ['trail' => in_array($order['status'], Orders::ACTIVE, true) ? Orders::trail((int) $order['id'], 100) : []], JSON_UNESCAPED_SLASHES) ?>;
  const dark = matchMedia('(prefers-color-scheme: dark)').matches;
  const map = L.map('map', { zoomControl: false, attributionControl: true });
  L.tileLayer('https://{s}.basemaps.cartocdn.com/' + (dark ? 'dark_all' : 'light_all') + '/{z}/{x}/{y}{r}.png', { subdomains: 'abcd', maxZoom: 19, attribution: '&copy; OpenStreetMap &copy; CARTO' }).addTo(map);
  const ic = (bg, t) => L.divIcon({ className: '', html: '<div class="mk" style="background:' + bg + '">' + t + '</div>', iconSize: [30, 30], iconAnchor: [15, 15] });
  L.marker([d.pickup.lat, d.pickup.lng], { icon: ic('#0E0F10', '●') }).addTo(map);
  L.marker([d.dropoff.lat, d.dropoff.lng], { icon: ic('#34A853', '⚑') }).addTo(map);
  let rider = null, trail = null;
  function draw(){
    if (d.rider && d.rider.lat != null && ['matched','picked_up','en_route','arrived'].includes(d.status)) {
      const p = [d.rider.lat, d.rider.lng];
      if (!rider) rider = L.marker(p, { icon: ic('#1E88E5', '🛵'), zIndexOffset: 1000 }).addTo(map); else rider.setLatLng(p);
    }
    if (d.trail && d.trail.length > 1) { if (trail) trail.setLatLngs(d.trail); else trail = L.polyline(d.trail, { color: '#1E88E5', weight: 4, opacity: .7 }).addTo(map); }
  }
  draw();
  const pts = [[d.pickup.lat, d.pickup.lng], [d.dropoff.lat, d.dropoff.lng]]; if (rider) pts.push(rider.getLatLng());
  map.fitBounds(pts, { padding: [40, 40], maxZoom: 15 });
  L.polyline([[d.pickup.lat, d.pickup.lng], [d.dropoff.lat, d.dropoff.lng]], { color: '#34A853', weight: 3, dashArray: '6 8' }).addTo(map);
  <?php if ($live && $apiPath): ?>
  setInterval(async () => {
    try {
      const r = await fetch(<?= json_encode(app_url($apiPath)) ?>).then(r => r.json());
      if (!r.success) return;
      const prev = d.status; d = r.data; draw();
      if (d.status !== prev) location.reload();
      const h = document.getElementById('headline');
      if (['matched','picked_up','en_route'].includes(d.status)) h.textContent = 'Arriving in ~' + d.eta_minutes + ' min';
    } catch (e) {}
  }, 10000);
  <?php endif; ?>
})();
</script>
<?php endif; ?>
</body>
</html>
