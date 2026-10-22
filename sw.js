/* Bainzuretta — service worker PWA
 * v86: aggiornamenti online prioritari, consultazione offline e cache isolata.
 * Non intercetta le API Strava, l'autorizzazione OAuth o richieste di altre app.
 */
const CACHE_PREFIX = 'bainzuretta-';
const CACHE_NAME = 'bainzuretta-v86';
const APP_URL = new URL('./index.html', self.registration.scope).href;
const APP_PATH = new URL(self.registration.scope).pathname;
const APP_SHELL = ['./index.html', './manifest.json', './icona.png'];

self.addEventListener('install', (event) => {
    event.waitUntil((async () => {
        const cache = await caches.open(CACHE_NAME);
        // La pagina e' indispensabile per la navigazione offline.
        await cache.add(new Request(APP_URL, { cache: 'reload' }));
        // Un manifest o un'icona non disponibili non devono bloccare l'aggiornamento.
        await Promise.allSettled(APP_SHELL.slice(1).map(file => cache.add(file)));
        await self.skipWaiting();
    })());
});

self.addEventListener('activate', (event) => {
    event.waitUntil((async () => {
        const names = await caches.keys();
        await Promise.all(names
            .filter(name => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
            .map(name => caches.delete(name)));
        // Non cancellare mai le cache create da altre app GitHub Pages.
        await self.clients.claim();
    })());
});

self.addEventListener('fetch', (event) => {
    const request = event.request;
    if (request.method !== 'GET') return;
    const url = new URL(request.url);
    if (url.origin !== self.location.origin) return;

    const isHome = url.pathname === APP_PATH || url.pathname === APP_PATH + 'index.html';
    const isOAuth = ['code', 'state', 'error', 'error_description'].some(key => url.searchParams.has(key));

    // Il ritorno da Strava va SEMPRE in rete: non mostrare una copia offline
    // al posto della risposta OAuth, e non conservare i codici nell'archivio.
    if (isHome && isOAuth) return;

    if (request.mode === 'navigate' && isHome) {
        event.respondWith((async () => {
            try {
                // Prima la rete: a ogni apertura si prova a scaricare l'HTML aggiornato.
                const response = await fetch(request, { cache: 'no-store' });
                if (response.ok) {
                    const cache = await caches.open(CACHE_NAME);
                    await cache.put(APP_URL, response.clone()).catch(() => {});
                }
                return response;
            } catch (_) {
                // Offline: mantieni utilizzabili diario e statistiche locali.
                return (await caches.match(APP_URL)) || Response.error();
            }
        })());
        return;
    }

    // Manifest e icona locali: cache come ripiego in assenza di rete.
    const localAssets = [APP_PATH + 'manifest.json', APP_PATH + 'icona.png'];
    if (localAssets.includes(url.pathname)) {
        event.respondWith((async () => {
            try {
                const response = await fetch(request);
                if (response.ok) {
                    const cache = await caches.open(CACHE_NAME);
                    await cache.put(request, response.clone()).catch(() => {});
                }
                return response;
            } catch (_) {
                return (await caches.match(request)) || Response.error();
            }
        })());
    }
});
