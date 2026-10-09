/* Dyspatch Admin — vanilla JS + Leaflet (framework-free) */
(function () {
  const root = document.documentElement;
  const themeBtn = document.getElementById('themeBtn');
  if (themeBtn) themeBtn.addEventListener('click', () => {
    const dark = root.dataset.theme ? root.dataset.theme === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
    root.dataset.theme = dark ? 'light' : 'dark';
    try { localStorage.setItem('dsp-theme', root.dataset.theme); } catch (e) {}
    document.dispatchEvent(new Event('themechange'));
  });

  // Copy-to-clipboard on Track ID chips
  document.addEventListener('click', (e) => {
    const t = e.target.closest('[data-copy]');
    if (t) {
      e.stopPropagation();
      navigator.clipboard && navigator.clipboard.writeText(t.dataset.copy);
      const old = t.textContent; t.textContent = 'Copied'; setTimeout(() => (t.textContent = old), 900);
      return;
    }
    const row = e.target.closest('tr[data-href]');
    if (row && !e.target.closest('a,button,form,input,select')) location.href = row.dataset.href;
    const op = e.target.closest('[data-open]');
    if (op) { const d = document.getElementById(op.dataset.open); if (d) d.showModal(); }
    const cl = e.target.closest('[data-close]');
    if (cl) cl.closest('dialog').close();
  });
  document.addEventListener('submit', (e) => {
    const m = e.target.dataset.confirm;
    if (m && !confirm(m)) e.preventDefault();
  });

  // Address autocomplete: <input data-geo="pickup"> + hidden pickup_lat/pickup_lng
  document.querySelectorAll('input[data-geo]').forEach((inp) => {
    const prefix = inp.dataset.geo;
    const form = inp.form;
    const lat = form.querySelector(`[name="${prefix}_lat"]`), lng = form.querySelector(`[name="${prefix}_lng"]`);
    const box = document.createElement('div');
    box.className = 'card';
    Object.assign(box.style, { position: 'absolute', zIndex: 50, left: 0, right: 0, top: '100%', marginTop: '4px', display: 'none', maxHeight: '260px', overflowY: 'auto', padding: '6px' });
    inp.parentElement.style.position = 'relative';
    inp.parentElement.appendChild(box);
    let tmr;
    inp.addEventListener('input', () => {
      if (lat) lat.value = ''; if (lng) lng.value = '';
      clearTimeout(tmr);
      const q = inp.value.trim();
      if (q.length < 3) { box.style.display = 'none'; return; }
      tmr = setTimeout(async () => {
        try {
          const r = await fetch('../api/places/search?q=' + encodeURIComponent(q)).then((r) => r.json());
          const list = (r.data || []);
          box.innerHTML = list.length ? '' : '<div class="muted small" style="padding:10px">No matches — keep typing or drop a pin on the map.</div>';
          list.forEach((p) => {
            const a = document.createElement('a');
            a.href = '#';
            a.style.cssText = 'display:block;padding:9px 10px;border-radius:10px';
            a.innerHTML = `<b style="font-weight:600">${esc(p.name)}</b><div class="muted small">${esc(p.address)}</div>`;
            a.onmouseenter = () => (a.style.background = 'var(--surface-2)');
            a.onmouseleave = () => (a.style.background = '');
            a.onclick = (ev) => {
              ev.preventDefault();
              inp.value = p.name + (p.address && p.address !== p.name ? ', ' + p.address : '');
              if (lat) lat.value = p.lat; if (lng) lng.value = p.lng;
              box.style.display = 'none';
              inp.dispatchEvent(new CustomEvent('geo:set', { detail: p, bubbles: true }));
            };
            box.appendChild(a);
          });
          box.style.display = 'block';
        } catch (e) { box.style.display = 'none'; }
      }, 350);
    });
    document.addEventListener('click', (e) => { if (!box.contains(e.target) && e.target !== inp) box.style.display = 'none'; });
  });

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
  window.esc = esc;

  // ── Map helpers ──
  const ICONS = {
    rider: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="5.5" cy="17" r="3.5"/><circle cx="18.5" cy="17" r="3.5"/><path d="M5.5 17 9 9h6l3.5 8M9 9 7.5 6H5"/></svg>',
    pick: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M21 8 12 3 3 8v8l9 5 9-5z"/></svg>',
    drop: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z"/></svg>',
  };
  window.DMap = {
    tiles() {
      const dark = root.dataset.theme ? root.dataset.theme === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
      return `https://{s}.basemaps.cartocdn.com/${dark ? 'dark_all' : 'light_all'}/{z}/{x}/{y}{r}.png`;
    },
    create(el, center, zoom) {
      const m = L.map(el, { zoomControl: true, attributionControl: true }).setView(center || [6.335, 5.6037], zoom || 13);
      const layer = L.tileLayer(this.tiles(), { maxZoom: 19, subdomains: 'abcd', attribution: '&copy; OpenStreetMap &copy; CARTO' }).addTo(m);
      document.addEventListener('themechange', () => layer.setUrl(this.tiles()));
      return m;
    },
    icon(kind, extra) {
      return L.divIcon({ className: '', html: `<div class="mk ${kind} ${extra || ''}">${ICONS[kind] || ''}</div>`, iconSize: [34, 34], iconAnchor: [17, 17], popupAnchor: [0, -16] });
    },
  };
})();
