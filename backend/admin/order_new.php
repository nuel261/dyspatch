<?php
/** Web dispatch: create an order on behalf of a customer / walk-in business. */
require __DIR__ . '/_init.php';
$admin = require_admin(['super', 'ops']);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $in = $_POST;
    try {
        $user = null;
        $phone = trim((string) ($in['customer_phone'] ?? ''));
        if ($phone !== '') {
            $phone = normalize_phone($phone);
            $user = DB::row('SELECT * FROM users WHERE phone = ?', [$phone]);
            if (!$user && !empty($in['create_customer'])) {
                $names = explode(' ', trim((string) ($in['sender_name'] ?? '')), 2);
                $uid = DB::insert('users', ['phone' => $phone, 'first_name' => $names[0] ?: null, 'last_name' => $names[1] ?? null,
                    'email' => filter_var($in['customer_email'] ?? '', FILTER_VALIDATE_EMAIL) ?: null]);
                Wallet::get('user', $uid);
                $user = DB::row('SELECT * FROM users WHERE id = ?', [$uid]);
            }
        }
        $items = [];
        foreach ((array) ($in['items'] ?? []) as $it) if (trim((string) ($it['description'] ?? '')) !== '') $items[] = $it;
        $data = $in + ['items' => $items];
        $data['sender_phone'] = $in['sender_phone'] ?: ($phone ?: null);
        if (trim((string) ($in['fee_override'] ?? '')) !== '') $data['fee_override_kobo'] = to_kobo($in['fee_override']);
        if (($data['payment_method'] ?? '') === 'wallet' && !$user) throw new ApiException('Wallet payment needs an existing customer phone number.');

        $o = Orders::create($data, $user, 'admin', (int) $admin['id']);
        audit((int) $admin['id'], 'order.create', 'order', (int) $o['id'], $o['track_id']);
        Notifier::orderStatus($o, 'pending');
        if (!empty($in['rider_id'])) {
            Orders::assignRider((int) $o['id'], (int) $in['rider_id'], 'admin', (int) $admin['id']);
        } elseif (!empty($in['auto_match'])) {
            Matching::dispatch((int) $o['id']);
        }
        flash("Order {$o['track_id']} created. Pickup code {$o['pickup_code']} · delivery code {$o['delivery_code']}.");
        redirect('order.php?id=' . $o['id']);
    } catch (ApiException $e) {
        flash($e->getMessage(), 'err');
        $_SESSION['order_form'] = $in;
        redirect('order_new.php');
    }
}
$old = $_SESSION['order_form'] ?? [];
unset($_SESSION['order_form']);
$v = fn($k, $d = '') => e($old[$k] ?? $d);

layout_start('New delivery', 'orders', 'Web dispatch — create a delivery for a customer or walk-in business.', '<a class="btn ghost" href="orders.php">Cancel</a>');
?>
<form method="post" id="orderForm" class="grid g-main" autocomplete="off">
  <?= csrf_field() ?>
  <div class="stack" style="gap:20px">
    <div class="card">
      <div class="card-h"><h2>Customer</h2><span class="muted small">Optional — links the order to their app account</span></div>
      <div class="card-b form-grid">
        <label class="f">Customer phone<input class="input" name="customer_phone" id="custPhone" value="<?= $v('customer_phone') ?>" placeholder="08012345678"><span class="hint" id="custHint">Leave empty for a walk-in sender.</span></label>
        <label class="f">Customer email<input class="input" name="customer_email" type="email" value="<?= $v('customer_email') ?>" placeholder="For delivery emails"></label>
        <label class="switch full" id="createWrap" style="display:none"><input type="checkbox" name="create_customer" value="1" checked> Create a customer account for this number</label>
        <label class="f">Sender name<input class="input" name="sender_name" value="<?= $v('sender_name') ?>" placeholder="e.g. Mama Nkechi Restaurant"></label>
        <label class="f">Sender phone<input class="input" name="sender_phone" value="<?= $v('sender_phone') ?>" placeholder="Rider calls this number at pickup"></label>
      </div>
    </div>

    <div class="card">
      <div class="card-h"><h2>Route</h2></div>
      <div class="card-b stack">
        <label class="f">Pickup address *<div><input class="input" name="pickup_address" data-geo="pickup" value="<?= $v('pickup_address') ?>" placeholder="Start typing… e.g. Ring Road, Benin City" required></div></label>
        <input type="hidden" name="pickup_lat" value="<?= $v('pickup_lat') ?>"><input type="hidden" name="pickup_lng" value="<?= $v('pickup_lng') ?>">
        <label class="f">Drop-off address *<div><input class="input" name="dropoff_address" data-geo="dropoff" value="<?= $v('dropoff_address') ?>" placeholder="e.g. University of Benin" required></div></label>
        <input type="hidden" name="dropoff_lat" value="<?= $v('dropoff_lat') ?>"><input type="hidden" name="dropoff_lng" value="<?= $v('dropoff_lng') ?>">
        <div class="form-grid">
          <label class="f">Recipient name *<input class="input" name="recipient_name" value="<?= $v('recipient_name') ?>" required></label>
          <label class="f">Recipient phone *<input class="input" name="recipient_phone" value="<?= $v('recipient_phone') ?>" placeholder="Gets the delivery code by SMS" required></label>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-h"><h2>Parcels</h2><span class="muted small">Each line gets its own tracking code (e.g. BEN-48213-01)</span><button type="button" class="btn ghost sm" id="addItem"><?= icon('plus') ?> Add parcel</button></div>
      <div class="card-b stack items-editor" id="items">
        <div class="it muted small" style="font-weight:600"><span>Description</span><span>Qty</span><span class="hide-sm">Weight (kg)</span><span class="hide-sm">Value (₦)</span><span></span></div>
      </div>
      <div class="card-b" style="border-top:1px solid var(--border)">
        <div class="form-grid">
          <label class="f">Package size<select class="input" name="package_type"><?php foreach (['small' => 'Small package', 'medium' => 'Medium package', 'large' => 'Large package'] as $k => $l): ?><option value="<?= $k ?>" <?= ($old['package_type'] ?? 'medium') === $k ? 'selected' : '' ?>><?= $l ?></option><?php endforeach; ?></select></label>
          <label class="f">Delivery type<select class="input" name="delivery_type"><option value="standard">Standard · 60–120 mins</option><option value="express" <?= ($old['delivery_type'] ?? '') === 'express' ? 'selected' : '' ?>>Express · 20–40 mins</option></select></label>
          <label class="f full">Note for rider<input class="input" name="package_description" value="<?= $v('package_description') ?>" placeholder="e.g. Fragile — glass items"></label>
        </div>
      </div>
    </div>
  </div>

  <div class="stack" style="gap:20px">
    <div class="card"><div id="map" class="map short" style="border-radius:20px 20px 0 0"></div>
      <div class="card-b stack">
        <div class="row between"><span class="muted">Distance</span><b id="qDist">—</b></div>
        <div class="row between"><span class="muted">Zone</span><b id="qZone">—</b></div>
        <div class="row between"><span class="muted">Commission / rider</span><b id="qSplit" class="small">—</b></div>
        <div class="divider"></div>
        <div class="row between"><span style="font-weight:600">Delivery fee</span><b id="qFee" style="font-size:22px;letter-spacing:-.03em">—</b></div>
        <label class="f">Override fee (₦)<input class="input" name="fee_override" value="<?= $v('fee_override') ?>" placeholder="Leave empty to use pricing engine"></label>
      </div>
    </div>
    <div class="card"><div class="card-h"><h3>Payment & dispatch</h3></div>
      <div class="card-b stack">
        <label class="f">Payment<select class="input" name="payment_method" id="payMethod"><option value="cash">Cash — rider collects</option><option value="wallet">Customer wallet</option></select></label>
        <label class="f">Assign rider<select class="input" name="rider_id" id="riderSel"><option value="">Auto-match nearest rider</option></select><span class="hint">Riders sorted by online status and distance to pickup.</span></label>
        <label class="switch"><input type="checkbox" name="auto_match" value="1" checked> Offer to nearby riders if none selected</label>
        <button class="btn block" style="padding:14px"><?= icon('check') ?> Create delivery</button>
      </div>
    </div>
  </div>
</form>
<?php
$oldItems = json_encode(array_values($old['items'] ?? []));
layout_end(<<<JS
<script>
(function(){
  const f = document.getElementById('orderForm');
  const items = document.getElementById('items');
  let n = 0;
  function addItem(v){ v = v || {}; const i = n++; const d = document.createElement('div'); d.className = 'it';
    d.innerHTML = '<input class="input" name="items['+i+'][description]" placeholder="e.g. Phone in box" value="'+esc(v.description||'')+'">'
      + '<input class="input" name="items['+i+'][quantity]" type="number" min="1" value="'+esc(v.quantity||1)+'">'
      + '<input class="input hide-sm" name="items['+i+'][weight_kg]" type="number" step="0.1" placeholder="—" value="'+esc(v.weight_kg||'')+'">'
      + '<input class="input hide-sm" name="items['+i+'][value]" placeholder="—" value="'+esc(v.value||'')+'">'
      + '<button type="button" class="btn ghost sm" title="Remove">✕</button>';
    d.querySelector('button').onclick = () => d.remove(); items.appendChild(d); }
  document.getElementById('addItem').onclick = () => addItem();
  const old = $oldItems; (old.length ? old : [{}]).forEach(addItem);

  const map = DMap.create('map', [6.335, 5.6037], 12); let mk = {}, line;
  async function quote(){
    const g = k => f.querySelector('[name="'+k+'"]').value;
    ['pickup','dropoff'].forEach(p => { if (mk[p]) { map.removeLayer(mk[p]); delete mk[p]; } if (g(p+'_lat')) mk[p] = L.marker([+g(p+'_lat'), +g(p+'_lng')], {icon: DMap.icon(p==='pickup'?'pick':'drop')}).addTo(map); });
    if (line) map.removeLayer(line);
    const pts = Object.values(mk).map(m => m.getLatLng()); if (pts.length) map.fitBounds(L.latLngBounds(pts).pad(.3), {maxZoom: 15});
    if (pts.length === 2) line = L.polyline(pts, {color:'#34A853', weight:4, dashArray:'6 8'}).addTo(map);
    if (!g('pickup_lat') || !g('dropoff_lat')) return;
    const qs = new URLSearchParams({a:'quote', pickup_address:g('pickup_address'), pickup_lat:g('pickup_lat'), pickup_lng:g('pickup_lng'), dropoff_address:g('dropoff_address'), dropoff_lat:g('dropoff_lat'), dropoff_lng:g('dropoff_lng'), package_type:g('package_type'), delivery_type:g('delivery_type')});
    const r = await fetch('ajax.php?'+qs).then(r=>r.json());
    if (!r.success) { document.getElementById('qFee').textContent = '—'; document.getElementById('qZone').textContent = r.message; return; }
    const d = r.data;
    document.getElementById('qFee').textContent = d.fee;
    document.getElementById('qDist').textContent = d.distance_km + ' km · ~' + d.minutes + ' min';
    document.getElementById('qZone').innerHTML = d.zone ? esc(d.zone.name) + (d.serviceable ? ' <span class="badge b-live">Live</span>' : ' <span class="badge b-gated">Gated</span>') : '<span style="color:var(--err)">Outside service area</span>';
    document.getElementById('qSplit').textContent = d.commission + ' / ' + d.rider_earning;
    loadRiders(g('pickup_lat'), g('pickup_lng'));
  }
  async function loadRiders(lat, lng){
    const r = await fetch('ajax.php?a=riders&lat='+lat+'&lng='+lng).then(r=>r.json()); const s = document.getElementById('riderSel'); const cur = s.value;
    s.innerHTML = '<option value="">Auto-match nearest rider</option>' + (r.data||[]).filter(x=>x.kyc==='verified').map(x => '<option value="'+x.id+'"'+(x.busy?' disabled':'')+'>'+esc(x.name)+' · '+(x.online?'online':'offline')+(x.km!=null?' · '+x.km+' km':'')+(x.busy?' · busy':'')+'</option>').join('');
    s.value = cur;
  }
  f.addEventListener('geo:set', quote);
  f.querySelectorAll('[name=package_type],[name=delivery_type]').forEach(el => el.addEventListener('change', quote));
  quote();

  const cp = document.getElementById('custPhone'), hint = document.getElementById('custHint'), cw = document.getElementById('createWrap'); let t;
  cp.addEventListener('input', () => { clearTimeout(t); t = setTimeout(async () => {
    const v = cp.value.trim(); if (v.length < 10) { hint.textContent = 'Leave empty for a walk-in sender.'; cw.style.display='none'; return; }
    const r = await fetch('ajax.php?a=customer&phone='+encodeURIComponent(v)).then(r=>r.json());
    if (r.data) { hint.innerHTML = '<span class="pill-ok">'+esc(r.data.name||'Customer')+'</span> · wallet '+esc(r.data.wallet); cw.style.display='none'; }
    else { hint.textContent = 'No account with this number.'; cw.style.display='flex'; }
  }, 400); });
})();
</script>
JS);
