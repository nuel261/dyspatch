<?php
require __DIR__ . '/_init.php';
require_admin();
layout_start('Live map', 'live', 'Every online rider and active delivery, refreshed every 8 seconds.', '<span class="muted small" id="liveStamp">Loading…</span>');
$center = DB::row('SELECT center_lat, center_lng FROM zones WHERE is_live = 1 ORDER BY id LIMIT 1') ?: ['center_lat' => 6.335, 'center_lng' => 5.6037];
?>
<div class="grid" style="grid-template-columns:minmax(0,1fr) 320px">
  <div class="card" style="padding:10px"><div id="map" class="map tall"></div></div>
  <div class="card" style="max-height:calc(100vh - 190px);display:flex;flex-direction:column">
    <div class="card-h"><h3>Active</h3><span class="badge b-info plain"><span id="orderCount">0</span>&nbsp;orders</span><span class="badge b-online plain"><span id="riderCount">0</span>&nbsp;riders</span></div>
    <div class="card-b stack" id="liveList" style="overflow-y:auto;gap:8px"></div>
    <div class="card-b" style="border-top:1px solid var(--border)"><div class="row small muted" style="gap:14px">
      <span class="row" style="gap:6px"><span class="mk rider" style="width:16px;height:16px;border-width:2px"></span>Busy</span>
      <span class="row" style="gap:6px"><span class="mk rider idle" style="width:16px;height:16px;border-width:2px"></span>Available</span>
      <span class="row" style="gap:6px"><span class="mk pick" style="width:16px;height:16px;border-width:2px"></span>Pickup</span>
      <span class="row" style="gap:6px"><span class="mk drop" style="width:16px;height:16px;border-width:2px"></span>Drop-off</span>
    </div></div>
  </div>
</div>
<style>@media (max-width:900px){.content>.grid{grid-template-columns:1fr!important}}</style>
<?php layout_end('<script>window.LIVE_CENTER=[' . (float) $center['center_lat'] . ',' . (float) $center['center_lng'] . '];</script><script src="../assets/js/live.js?v=3"></script>');
