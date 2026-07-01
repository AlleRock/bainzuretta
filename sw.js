const CACHE_NAME = 'bainzuretta-v78'; // Incrementato la versione per forzare l'aggiornamento su iPhone

const ASSETS = [
    './',
    './index.html',
    './Bainzuretta 77.4.html', // Includiamo entrambi i possibili nomi per sicurezza
    'https://raw.githubusercontent.com/AlleRock/bainzuretta/main/icona.png'
];

// 1. Installazione: Salviamo gli asset fondamentali nella cache
self.addEventListener('install', e => {
    e.waitUntil(
        caches.open(CACHE_NAME).then(cache => {
            console.log('[Service Worker] Caching app shell');
            // Usiamo allSettled o un ciclo per evitare che il fallimento di un singolo URL blocchi tutto
            return Promise.allSettled(
                ASSETS.map(url => cache.add(url).catch(err => console.log(`Errore cache su: ${url}`, err)))
            );
        })
    );
    self.skipWaiting();
});

// 2. Attivazione: Pulizia delle vecchie cache per evitare conflitti
self.addEventListener('activate', e => {
    e.waitUntil(
        caches.keys().then(keys => {
            return Promise.all(
                keys.map(key => {
                    if (key !== CACHE_NAME) {
                        console.log('[Service Worker] Rimozione vecchia cache:', key);
                        return caches.delete(key);
                    }
                })
            );
        })
    );
    self.clients.claim();
});

// 3. Fetch: Strategia Cache-First con fallback intelligente per iOS e richieste Strava
self.addEventListener('fetch', e => {
    const url = new URL(e.request.url);

    // Gestione speciale per la pagina di navigazione principale (ignora i parametri query come ?code= di Strava)
    if (e.request.mode === 'navigate' || (url.origin === self.location.origin && (url.pathname.endsWith('.html') || url.pathname === '/'))) {
        e.respondWith(
            caches.match('./').then(response => {
                return response || caches.match('./index.html') || caches.match('./Bainzuretta 77.4.html') || fetch(e.request);
            })
        );
        return;
    }

    // Strategia standard: Cerca in cache, se manca vai in rete
    e.respondWith(
        caches.match(e.request).then(cachedResponse => {
            if (cachedResponse) {
                return cachedResponse;
            }

            // Se la risorsa non è in cache, proviamo a prenderla dalla rete
            return fetch(e.request).then(networkResponse => {
                // Se è un font di Google o un'immagine esterna, salviamola dinamicamente nella cache per la prossima volta offline
                if (url.hostname.includes('fonts.googleapis.com') || url.hostname.includes('fonts.gstatic.com')) {
                    const responseToCache = networkResponse.clone();
                    caches.open(CACHE_NAME).then(cache => {
                        cache.put(e.request, responseToCache);
                    });
                }
                return networkResponse;
            }).catch(() => {
                // Se siamo TOTALMENTE offline e la risorsa manca, restituiamo un'immagine vuota o testo per evitare il crash su iOS
                if (e.request.headers.get('accept').includes('image')) {
                    return caches.match('https://raw.githubusercontent.com/AlleRock/bainzuretta/main/icona.png');
                }
            });
        })
    );
});
