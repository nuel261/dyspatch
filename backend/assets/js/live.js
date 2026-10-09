/* Live operations map: online riders + active deliveries, refreshed every 8s */
(function () {
  const el = document.getElementById('map');
  if (!el || !window.L) return;
  const map = DMap.create(el, window.LIVE_CENTER, 13);
  const layer = L.layerGroup().addTo(map);
  let fitted = false;
  const list = document.getElementById('liveList');
  const stamp = document.getElementById('liveStamp');

  async function load() {
    try {
      const d = await fetch('live_data.php', { credentials: 'same-origin' }).then((r) => r.json());
      layer.clearLayers();
      const pts = [];
      d.orders.forEach((o) => {
        const pop = `<b>${esc(o.track_id)}</b><br>${esc(o.route)}<br><span class="badge b-${o.status}">${esc(o.label)}</span><br><a class="green" href="order.php?id=${o.id}">Open order →</a>`;
        L.marker(o.pickup, { icon: DMap.icon('pick') }).bindPopup(pop).addTo(layer);
        L.marker(o.dropoff, { icon: DMap.icon('drop') }).bindPopup(pop).addTo(layer);
        L.polyline([o.pickup, o.dropoff], { color: '#34A853', weight: 2, opacity: 0.5, dashArray: '6 6' }).addTo(layer);
        pts.push(o.pickup, o.dropoff);
      });
      d.riders.forEach((r) => {
        L.marker([r.lat, r.lng], { icon: DMap.icon('rider', r.busy ? '' : 'idle'), zIndexOffset: 1000 })
          .bindPopup(`<b>${esc(r.name)}</b><br>${esc(r.plate || r.vehicle)} · ${r.busy ? 'On a delivery' : 'Available'}<br><span class="muted">Seen ${esc(r.seen)}</span><br><a class="green" href="rider.php?id=${r.id}">Open rider →</a>`)
          .addTo(layer);
        pts.push([r.lat, r.lng]);
      });
      if (!fitted && pts.length) { map.fitBounds(pts, { padding: [40, 40], maxZoom: 14 }); fitted = true; }
      if (stamp) stamp.textContent = 'Updated ' + d.at;
      if (list) {
        list.innerHTML = d.orders.length ? d.orders.map((o) => `<a href="order.php?id=${o.id}" class="row" style="padding:10px 12px;border-radius:12px;border:1px solid var(--border)"><span style="flex:1;min-width:0"><b class="mono">${esc(o.track_id)}</b><div class="muted small" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${esc(o.route)}</div></span><span class="badge b-${o.status}">${esc(o.label)}</span></a>`).join('')
          : '<div class="muted" style="padding:12px">No active deliveries.</div>';
        const rc = document.getElementById('riderCount'); if (rc) rc.textContent = d.riders.length;
        const oc = document.getElementById('orderCount'); if (oc) oc.textContent = d.orders.length;
      }
    } catch (e) { if (stamp) stamp.textContent = 'Connection lost — retrying'; }
  }
  load();
  setInterval(load, 8000);
})();
