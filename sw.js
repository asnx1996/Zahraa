/* ═══════════════════════════════════════════════════════════
   Service Worker — كاش خفيف يخلي الموقع يفتح بسرعة
   الاستراتيجية:
     • ملفات الموقع (HTML/CSS/JS)  → الشبكة أول، والكاش احتياط
     • الخطوط والصور                → الكاش أول، والشبكة تحدّثه
     • طلبات Supabase (API)         → الشبكة فقط، أبداً ما تنكشّ
   ═══════════════════════════════════════════════════════════ */
const V     = 'cz-v4';
const SHELL = ['./', './index.html', './manifest.webmanifest'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(V).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== V).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  /* لا تلمس أي شي يخص Supabase — البيانات لازم تكون طازجة دائماً */
  if (url.hostname.endsWith('supabase.co')) return;

  const isAsset = /\.(?:png|jpg|jpeg|webp|svg|gif|woff2?)$/i.test(url.pathname)
               || url.hostname.includes('fonts.g')
               || url.hostname.includes('images.unsplash.com');

  if (isAsset){
    /* الكاش أول */
    e.respondWith(
      caches.match(req).then(hit => {
        const net = fetch(req).then(res => {
          if (res && res.status === 200) caches.open(V).then(c => c.put(req, res.clone()));
          return res;
        }).catch(() => hit);
        return hit || net;
      })
    );
    return;
  }

  /* الشبكة أول، وإذا فشلت رجّع من الكاش */
  e.respondWith(
    fetch(req)
      .then(res => {
        if (res && res.status === 200 && url.origin === location.origin){
          const copy = res.clone();
          caches.open(V).then(c => c.put(req, copy));
        }
        return res;
      })
      .catch(() => caches.match(req).then(hit => {
        if (hit) return hit;
        /* احتياط الصفحة الرئيسية للموقع العام فقط — بدون هذا الشرط
           فتح اللوحة أوفلاين چان يعرض الموقع العام محل اللوحة */
        if (url.pathname.endsWith('/admin.html')) return Response.error();
        return caches.match('./index.html');
      }))
  );
});
