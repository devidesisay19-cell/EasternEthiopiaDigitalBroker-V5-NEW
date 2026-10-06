/* Lets demo photos stored as data: URLs work through storage.getPublicUrl(). Real paths are untouched. */
(function () {
  if (!window.supabase || !window.supabase.createClient || window.supabase.__eedbPatched) return;
  const orig = window.supabase.createClient;
  window.supabase.createClient = function () {
    const c = orig.apply(this, arguments);
    try {
      const from = c.storage.from.bind(c.storage);
      c.storage.from = function (bucket) {
        const b = from(bucket), get = b.getPublicUrl.bind(b);
        b.getPublicUrl = function (p, o) {
          return (typeof p === 'string' && p.indexOf('data:') === 0) ? { data: { publicUrl: p } } : get(p, o);
        };
        return b;
      };
    } catch (e) { /* ignore */ }
    return c;
  };
  window.supabase.__eedbPatched = true;
})();
