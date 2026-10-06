/* City selection: shown the first time the app opens, remembered afterwards.
   Uses the existing #cityFilter select + applyFilters() of index.html. */
(function () {
  var KEY = 'eedb_city';
  var TXT = {
    en: { title: 'Select your city', sub: 'Choose where you want to buy, sell, rent or find jobs.', all: 'See all cities', change: 'Change city' },
    om: { title: 'Magaalaa kee filadhu', sub: 'Bakka bituu, gurguruu, kireessuu ykn hojii barbaaddu filadhu.', all: 'Magaalota hunda ilaali', change: 'Magaalaa jijjiiri' },
    am: { title: 'ከተማዎን ይምረጡ', sub: 'ለመግዛት፣ ለመሸጥ፣ ለመከራየት ወይም ሥራ ለመፈለግ የሚፈልጉትን ከተማ ይምረጡ።', all: 'ሁሉንም ከተሞች ይመልከቱ', change: 'ከተማ ቀይር' }
  };
  function t() { var l = 'en'; try { l = getCurrentLanguage(); } catch (e) {} return TXT[l] || TXT.en; }
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); }
  function saved() { try { return JSON.parse(localStorage.getItem(KEY) || 'null'); } catch (e) { return null; } }
  function save(id, name) { try { localStorage.setItem(KEY, JSON.stringify({ id: id, name: name })); } catch (e) {} }

  function chip(name) {
    var c = document.getElementById('eedbCityChip');
    if (!c) {
      c = document.createElement('button');
      c.id = 'eedbCityChip'; c.type = 'button';
      c.style.cssText = 'position:fixed;left:12px;bottom:14px;z-index:9000;border:0;border-radius:999px;padding:10px 14px;background:#0d47a1;color:#fff;font:700 14px Arial,sans-serif;box-shadow:0 6px 18px rgba(0,0,0,.28);cursor:pointer';
      c.onclick = function () { picker(true); };
      document.body.appendChild(c);
    }
    c.textContent = '\uD83D\uDCCD ' + name + ' \u25BE';
  }

  function cityOptions() {
    var sel = document.getElementById('cityFilter');
    if (!sel) return [];
    return Array.prototype.filter.call(sel.options, function (o) { return o.value !== 'all'; })
      .map(function (o) { return { id: o.value, name: o.textContent.trim() }; });
  }

  function choose(id, name, again) {
    var sel = document.getElementById('cityFilter');
    save(id, name);
    if (sel) sel.value = id;
    chip(id === 'all' ? t().all : name);
    var ov = document.getElementById('eedbCityGate'); if (ov) ov.remove();
    if (again && typeof applyFilters === 'function') applyFilters();
    if (resolver) { var r = resolver; resolver = null; r(); }
  }

  var resolver = null;
  function picker(again) {
    var list = cityOptions();
    if (!list.length) return Promise.resolve();
    var old = document.getElementById('eedbCityGate'); if (old) old.remove();
    var s = t(), ov = document.createElement('div');
    ov.id = 'eedbCityGate';
    ov.style.cssText = 'position:fixed;inset:0;z-index:99999;background:linear-gradient(160deg,#0d47a1,#1e88e5);color:#fff;overflow:auto;padding:28px 18px;font-family:Arial,sans-serif';
    ov.innerHTML = '<div style="max-width:460px;margin:0 auto;text-align:center"><div style="font-size:44px">\uD83D\uDCCD</div>' +
      '<h1 style="font-size:26px;margin:8px 0 6px">' + esc(s.title) + '</h1>' +
      '<p style="opacity:.9;font-size:15px;margin-bottom:22px">' + esc(s.sub) + '</p>' +
      list.map(function (c, i) { return '<button type="button" data-i="' + i + '" style="display:block;width:100%;margin:0 0 10px;padding:16px;border:0;border-radius:14px;background:#fff;color:#0d47a1;font:700 18px Arial,sans-serif;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.18)">' + esc(c.name) + '</button>'; }).join('') +
      '<button type="button" data-all="1" style="margin-top:8px;padding:12px;border:0;background:transparent;color:#fff;font:600 15px Arial,sans-serif;text-decoration:underline;cursor:pointer">' + esc(s.all) + '</button></div>';
    ov.addEventListener('click', function (e) {
      var b = e.target.closest('button'); if (!b) return;
      if (b.getAttribute('data-all')) choose('all', s.all, again);
      else { var c = list[+b.getAttribute('data-i')]; choose(c.id, c.name, again); }
    });
    document.body.appendChild(ov);
    return new Promise(function (res) { resolver = res; });
  }

  window.cityGate = function () {
    var list = cityOptions();
    if (!list.length) return Promise.resolve();
    var sv = saved();
    if (sv && sv.id === 'all') { chip(t().all); return Promise.resolve(); }
    if (sv && list.some(function (c) { return c.id === sv.id; })) {
      var sel = document.getElementById('cityFilter'); if (sel) sel.value = sv.id;
      chip(sv.name); return Promise.resolve();
    }
    return picker(false);
  };
  window.eedbRestoreCity = function () {
    var sv = saved(), sel = document.getElementById('cityFilter');
    if (sv && sv.id !== 'all' && sel && sel.querySelector('option[value="' + sv.id + '"]')) sel.value = sv.id;
  };
})();
