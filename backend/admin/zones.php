<?php
require __DIR__ . '/_init.php';
$admin = require_admin(['super', 'ops']);

handle_post(function ($in) use ($admin) {
    $aid = (int) $admin['id'];
    $act = $in['action'] ?? '';
    if ($act === 'toggle') {
        $z = DB::row('SELECT * FROM zones WHERE id = ?', [(int) $in['id']]);
        DB::update('zones', ['is_live' => $z['is_live'] ? 0 : 1], 'id = ?', [$z['id']]);
        audit($aid, $z['is_live'] ? 'zone.gate' : 'zone.launch', 'zone', (int) $z['id'], $z['name']);
        return $z['is_live'] ? "{$z['name']} is now gated." : "{$z['name']} is live! Customers there can now book deliveries.";
    }
    if ($act === 'save') {
        $nul = fn($k, $kobo = false) => trim((string) ($in[$k] ?? '')) === '' ? null : ($kobo ? to_kobo($in[$k]) : (float) $in[$k]);
        $poly = trim((string) ($in['polygon'] ?? ''));
        if ($poly !== '') { $pp = json_decode($poly, true); if (!is_array($pp) || count($pp) < 3) throw new ApiException('Polygon must be a JSON list of at least 3 [lat,lng] points'); }
        $data = [
            'name' => trim((string) $in['name']), 'code' => strtoupper(preg_replace('/[^A-Za-z]/', '', (string) $in['code'])), 'city' => trim((string) $in['city']),
            'center_lat' => (float) $in['center_lat'], 'center_lng' => (float) $in['center_lng'], 'radius_km' => max(0.5, (float) $in['radius_km']),
            'polygon' => $poly ?: null, 'commission_pct' => $nul('commission_pct'), 'pricing_model' => in_array($in['pricing_model'] ?? '', ['distance_only', 'min_fare'], true) ? $in['pricing_model'] : null,
            'base_fare_kobo' => $nul('base_fare', true), 'per_km_kobo' => $nul('per_km', true), 'min_fare_kobo' => $nul('min_fare', true),
        ];
        if ($data['name'] === '' || strlen($data['code']) < 2) throw new ApiException('Name and a 2–6 letter code are required');
        if (!empty($in['id'])) {
            DB::update('zones', $data, 'id = ?', [(int) $in['id']]);
            audit($aid, 'zone.update', 'zone', (int) $in['id'], $data['name']);
            return 'Zone saved.';
        }
        if (DB::value('SELECT 1 FROM zones WHERE code = ?', [$data['code']])) throw new ApiException('That code is already used');
        $id = DB::insert('zones', $data + ['is_live' => 0]);
        audit($aid, 'zone.create', 'zone', $id, $data['name']);
        return "Zone {$data['name']} created (gated). Launch it when ready.";
    }
    return null;
});

$zones = DB::all("SELECT z.*, (SELECT COUNT(*) FROM orders o WHERE o.zone_id = z.id) orders,
    (SELECT COUNT(*) FROM orders o WHERE o.zone_id = z.id AND DATE(o.created_at) = CURDATE()) today,
    (SELECT COUNT(*) FROM riders r WHERE r.zone_id = z.id AND r.status = 'active') riders FROM zones z ORDER BY z.is_live DESC, z.name");
$g = ['commission' => Settings::get('commission_pct'), 'model' => Settings::get('pricing_model'), 'base' => Settings::int('base_fare_kobo'), 'km' => Settings::int('per_km_kobo'), 'min' => Settings::int('min_fare_kobo')];

layout_start('Zones', 'zones', 'Launch gating: customers can only book from live zones. Per-zone pricing overrides the global defaults.', '<button class="btn" onclick="editZone(null)">' . icon('plus') . ' New zone</button>');
?>
<div class="grid g-main">
  <div class="card"><div id="zmap" class="map tall"></div></div>
  <div class="stack" style="gap:14px">
  <?php foreach ($zones as $z): ?>
    <div class="card"><div class="card-b stack" style="gap:10px">
      <div class="row between"><div><h3><?= e($z['name']) ?> <span class="mono faint"><?= e($z['code']) ?></span></h3><div class="muted small"><?= e($z['city']) ?> · <?= $z['polygon'] ? 'polygon geofence' : e($z['radius_km']) . ' km radius' ?></div></div><?= badge($z['is_live'] ? 'live' : 'gated', $z['is_live'] ? 'Live' : 'Gated') ?></div>
      <div class="row small muted" style="gap:16px"><span><b style="color:var(--text)"><?= number_format((int) $z['orders']) ?></b> orders</span><span><b style="color:var(--text)"><?= (int) $z['today'] ?></b> today</span><span><b style="color:var(--text)"><?= (int) $z['riders'] ?></b> riders</span></div>
      <div class="small muted">Pricing: <?= $z['pricing_model'] || $z['base_fare_kobo'] !== null || $z['commission_pct'] !== null
          ? e(($z['pricing_model'] ?: $g['model']) . ' · base ' . naira($z['base_fare_kobo'] ?? $g['base'], false) . ' · ' . naira($z['per_km_kobo'] ?? $g['km'], false) . '/km · min ' . naira($z['min_fare_kobo'] ?? $g['min'], false) . ' · ' . ($z['commission_pct'] ?? $g['commission']) . '% commission')
          : 'Global defaults' ?></div>
      <div class="row"><button class="btn ghost sm" onclick='editZone(<?= e(json_encode($z)) ?>)'>Edit</button>
        <form method="post" data-confirm="<?= $z['is_live'] ? 'Gate this zone? New bookings from it will be blocked.' : 'Launch this zone for customers?' ?>"><?= csrf_field() ?><input type="hidden" name="action" value="toggle"><input type="hidden" name="id" value="<?= $z['id'] ?>"><button class="btn <?= $z['is_live'] ? 'danger ghost' : 'soft' ?> sm"><?= $z['is_live'] ? 'Gate zone' : 'Launch zone' ?></button></form></div>
    </div></div>
  <?php endforeach; ?>
  </div>
</div>

<dialog id="dlgZone" style="width:min(640px,calc(100vw - 32px))"><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="save"><input type="hidden" name="id">
  <div class="d-h"><h3 id="zTitle">Zone</h3><button type="button" class="x" data-close>×</button></div>
  <div class="d-b"><div class="form-grid">
    <label class="f">Name<input class="input" name="name" required></label>
    <label class="f">Code<input class="input" name="code" maxlength="6" required placeholder="BEN"><span class="hint">Track ID prefix, e.g. BEN-48213</span></label>
    <label class="f">City<input class="input" name="city" required></label>
    <label class="f">Radius (km)<input class="input" name="radius_km" type="number" step="0.5" required></label>
    <label class="f">Centre latitude<input class="input" name="center_lat" required></label>
    <label class="f">Centre longitude<input class="input" name="center_lng" required></label>
    <div class="full callout">Tip: click the map behind this dialog after closing it to pick a centre — or paste a polygon below for an exact geofence.</div>
    <label class="f full">Polygon (optional)<textarea class="input mono" name="polygon" placeholder='[[6.40,5.55],[6.40,5.68],[6.27,5.68],[6.27,5.55]]'></textarea></label>
    <div class="full divider"></div>
    <label class="f">Pricing model<select class="input" name="pricing_model"><option value="">Global (<?= e($g['model']) ?>)</option><option value="min_fare">Minimum fare</option><option value="distance_only">Distance only</option></select></label>
    <label class="f">Commission %<input class="input" name="commission_pct" placeholder="Global: <?= e($g['commission']) ?>"></label>
    <label class="f">Base fare (₦)<input class="input" name="base_fare" placeholder="Global: <?= $g['base'] / 100 ?>"></label>
    <label class="f">Per km (₦)<input class="input" name="per_km" placeholder="Global: <?= $g['km'] / 100 ?>"></label>
    <label class="f">Minimum fare (₦)<input class="input" name="min_fare" placeholder="Global: <?= $g['min'] / 100 ?>"></label>
  </div></div>
  <div class="d-f"><button type="button" class="btn ghost" data-close>Cancel</button><button class="btn">Save zone</button></div></form></dialog>
<?php
$json = json_encode(array_map(fn($z) => ['id' => (int) $z['id'], 'name' => $z['name'], 'lat' => (float) $z['center_lat'], 'lng' => (float) $z['center_lng'], 'r' => (float) $z['radius_km'], 'poly' => $z['polygon'] ? json_decode($z['polygon']) : null, 'live' => (bool) $z['is_live']], $zones));
layout_end(<<<JS
<script>
const zones = $json; const map = DMap.create('zmap', [6.335, 5.6037], 7); const all = [];
zones.forEach(z => {
  const st = { color: z.live ? '#34A853' : '#A0A4AB', weight: 2, fillOpacity: z.live ? .12 : .06, dashArray: z.live ? null : '6 6' };
  const shape = z.poly ? L.polygon(z.poly, st) : L.circle([z.lat, z.lng], Object.assign({ radius: z.r * 1000 }, st));
  shape.addTo(map).bindTooltip(esc(z.name) + (z.live ? ' · live' : ' · gated'), { permanent: true, direction: 'center', className: '' });
  all.push(shape.getBounds());
});
if (all.length) map.fitBounds(all.reduce((a, b) => a.extend(b)), { padding: [20, 20] });
const dlg = document.getElementById('dlgZone'), f = dlg.querySelector('form');
window.editZone = function (z) {
  f.reset(); document.getElementById('zTitle').textContent = z ? 'Edit ' + z.name : 'New zone';
  const set = (k, v) => { if (f[k]) f[k].value = v == null ? '' : v; };
  if (z) { ['id','name','code','city','radius_km','center_lat','center_lng','commission_pct','pricing_model'].forEach(k => set(k, z[k]));
    set('polygon', z.polygon || ''); set('base_fare', z.base_fare_kobo != null ? z.base_fare_kobo / 100 : ''); set('per_km', z.per_km_kobo != null ? z.per_km_kobo / 100 : ''); set('min_fare', z.min_fare_kobo != null ? z.min_fare_kobo / 100 : ''); }
  else { set('id', ''); set('radius_km', 10); const c = map.getCenter(); set('center_lat', c.lat.toFixed(6)); set('center_lng', c.lng.toFixed(6)); }
  dlg.showModal();
};
map.on('click', e => { if (dlg.open) return; f.center_lat.value = e.latlng.lat.toFixed(6); f.center_lng.value = e.latlng.lng.toFixed(6); dlg.showModal(); });
</script>
JS);
