# Inventario vincolante della versione web

Fonte analizzata integralmente: `AlleRock/bainzuretta`, commit `5b25cf855fe4d6782d7db26c6463309b7815f98a`. SHA256 di `index.html`: `d3b80b6a07dbedba3c19bc751516f93d1cd66c8816abf72b65047b24b8531ada`.

## File e architettura

- `index.html`: 1759 righe. CSS, DOM, navigazione e tutta la logica JavaScript in un unico file; nessun framework. Font remoti Outfit e Lobster, tema chiaro/scuro, intestazione arancione `#fb8c00`, schede arrotondate, sei pulsanti inferiori, controlli fissi sopra liste scorrevoli e modale inferiore condivisa.
- `manifest.json`: PWA standalone, nome Bainzuretta, tema arancione, icona remota.
- `sw.js`: cache `bainzuretta-v86`; rete prioritaria per HTML, ripiego offline, cache solo delle risorse locali; esclusione esplicita di OAuth e richieste Strava.
- `README.md`: descrizione e formato backup. Non è fonte normativa per le formule: in alcuni punti è meno preciso del codice.
- `icona.png`: immagine RGBA 766×783. Versione web conservata byte per byte; risorsa iOS adattata al quadrato 1024×1024 su fondo arancione senza tagliare il disegno.
- `.github/workflows/pages.yml`: pubblica soltanto `main` e consente avvio manuale. Intatto.

## HOME

Obiettivo annuale predefinito 5000 km, cambiabile toccando il riquadro, persistito con chiave per anno. Km mancanti limitati a zero. Proiezione arrotondata all'intero; km/settimana arrotondati per eccesso. Verde se il passo è in anticipo, giallo per ritardo fino al 10%, rosso oltre il 10%; arancione senza km; oro, stelle e animazione al traguardo. Legenda con formule e data di arrivo stimata.

Km storici, giri del mondo (40075 km), migliore anno per **media semplice delle sole velocità positive**. Inserimento manuale con data, km, HH:MM[:SS] oppure ore decimali; durata vuota ammessa e pari a zero. Modifica manuale da DIARIO, ritorno a HOME, annullamento senza toccare l'attività; metadati conservati. Niente modifica locale delle attività Strava.

Connessione Strava, stato atleta, sincronizzazione incrementale automatica all'avvio, sincronizzazione manuale, riallineamento 60 giorni, disconnessione locale o revoca remota. Backup JSON, importazione sostitutiva con conferma, copia precedente e recupero; report anno corrente; reset selettivo con conferma di attività, obiettivi, preferenze, backup e credenziali.

## DIARIO

Attività dell'anno corrente, **tutto l'anno** anche se ci sono date future; ordinamento data civile decrescente. Riepilogo km, numero uscite, media ponderata valida e dislivello. Viste Attività/Mese/Settimana; gruppi con km, numero uscite, media ponderata e dislivello; medaglie ai tre gruppi con più km. Tocco di un gruppo apre l'elenco attività. Dettagli data, nome, km, durata, velocità, dislivello e cadenza; link Strava; modifica delle manuali ed eliminazione locale con conferma.

## SFIDA

Solo anno corrente. Settimane lunedì-domenica, tagliate al 1 gennaio e 31 dicembre. Quota = target / 365 o 366 × numero giorni della riga. Dalla settimana corrente verso gennaio, numerazione progressiva originale, periodo/quota/fatto/delta. Settimana corrente senza km mostra trattino; raggiungimento verde, ritardo rosso. Riepilogo obiettivo e quota di 7 giorni.

## ARCHIVIO

Selettore di tutti gli anni presenti escluso quello corrente, più recente per primo. Filtro **DOY ≤ DOY corrente** e anno selezionato. Riepilogo e tre viste come DIARIO, medaglie e gruppi consultabili; dettagli senza azioni di modifica/eliminazione. La selezione di un anno dal RANKING apre ARCHIVIO.

## RANKING

Titolo RANKING YTD (il pulsante web usa la sigla RANK). Quattro metriche: Distanza Totale, Media Ponderata, Media Semplice, Dislivello Totale dal 2019. Filtro per numero di giorno nell'anno; restano anche anni con risultato YTD zero. Barre relative al migliore; distanza annuale completa aggiuntiva per anni storici; tocco dell'anno storico apre ARCHIVIO.

## RECORD: 39 voci, sette categorie

Ogni record con classifica mostra il primato e apre Top 5; per ≥100 e ≥150 km apre **l'intero elenco** ordinato per distanza. Ogni attività con `strava_id` ha collegamento Strava. Categoria ricordata fra riaperture. Parità: ordinamento stabile del JavaScript, inclusa l'enumerazione crescente delle chiavi numeriche degli oggetti.

| Categoria | Voci effettive |
|---|---|
| DISTANZA (7) | Giro più lungo; Uscite ≥100 km; Uscite ≥150 km; Settimana/Mese/Anno con più km; Max km in 7 giorni mobili |
| VELOCITÀ (6) | Media più alta in assoluto; fasce 30≤km<50, 50≤km<100, ≥100; fasce inclusive 50–60 e 100–110 km |
| TEMPO (4) | Uscita più lunga; Settimana/Mese/Anno con più ore in sella |
| DISLIVELLO (5) | Più dislivello in un'uscita; densità di salita su uscite ≥20 km; Settimana/Mese/Anno con più dislivello; solo dal 2019 e con D+ positivo |
| CADENZA (5) | Cadenza più alta; fasce 30≤km<50, 50≤km<100, ≥100; anno con cadenza media semplice più alta; solo cadenza positiva |
| COSTANZA (5) | Striscia più lunga (Top 5 strisce intere); striscia attuale; Settimana/Mese/Anno con più uscite |
| CURIOSITÀ (7) | Giorno settimana e mese dell'anno più pedalati **per numero di uscite**; Max km in 4 giorni; media km/uscita; media uscite/mese dal primo mese incluso fino all'attuale; numero ≥100 e ≥150 km |

Finestre mobili: una finestra parte da ciascun giorno con attività e dura N giorni; somma delle uscite giornaliere; selezione greedy delle cinque finestre migliori **non sovrapposte**. Non sono le cinque settimane più forti, né semplicemente i cinque massimi adiacenti. Striscia attuale: deve includere la settimana corrente; se manca attività questa settimana vale zero, anche se la settimana precedente è presente.

## Date e formule da non uniformare

`data` rappresenta la data/ora **civile dell'attività**, anche quando Strava etichetta l'ora locale con Z. Il suffisso non deve spostarla nel fuso del dispositivo. `data_utc` è invece un istante reale per i filtri API e le cancellazioni. Settimane storiche possono attraversare due anni; SFIDA invece taglia i confini annuali.

| Contesto | Tempo e media originali |
|---|---|
| Attività e record TEMPO | `tempo`, ore decimali salvate |
| DIARIO, ARCHIVIO, ranking ponderato | solo attività con distanza>0 e media>0: somma km validi / somma(km/media) |
| Gruppi mese/settimana | **tutti** i km / somma(km/media) delle sole medie positive |
| Ranking semplice | somma di **tutte** le medie, compresi gli zeri / numero attività |
| Migliore anno in HOME | media semplice delle sole medie positive |
| Report annuale | km totali / somma `tempo` |
| YTD | numero progressivo del giorno; il 29 febbraio sposta il confronto fra anni bisestili e non bisestili |

## Persistenza e importazione originale

Chiavi localStorage `bainzuretta_raw`, `bainzuretta_target_YYYY`, `bainzuretta_record_cat`, copia precedente, archivio danneggiato, token/segreto/state OAuth e finestra sync incompleta. Backup web = array di attività; **non** include obiettivi/preferenze/token. Campi `id`, `strava_id` facoltativo, `data`, `distanza`, `tempo`, `media`, nome/D+/cadenza/UTC facoltativi; i campi sconosciuti sono conservati. Identificativi sicuri numerici, oppure stringhe alfanumeriche con `_` e `-` per ID locali. Numeri stringa con virgola o punto accettati. Tempo/media mancanti ricostruiti solo dall'altro valore positivo. ID locali e Strava duplicati rifiutati. Import sostituisce, **non unisce**, e conserva copia precedente. Dati illeggibili non vanno sovrascritti al prossimo salvataggio.

## Sincronizzazione originale

`act.type` in Ride, VirtualRide, EBikeRide, MountainBikeRide: **GravelRide e altri sport non sono inclusi**. Distanza metri→km (2 decimali), moving_time secondi→ore (4 decimali), velocità ricavata prima degli arrotondamenti (2 decimali), D+ e cadenza. Pagine da 100, intervallo `after/before` fisso, riuso finestra incrementale dopo errore, commit soltanto al completamento. Incrementale aggiunge solo nuovi `strava_id`; 60 giorni aggiunge e aggiorna campi, conserva `id` originale e metadati. Collisioni con manuali: nuovo ID `strava_ID[_n]`. Eliminazioni: soltanto dopo risposta completa, almeno una uscita ciclistica scaricata e conferma; per dati senza UTC solo giornate sicuramente interne alla finestra (margini -14/+36 ore). Rinnovo token con 5 minuti di anticipo, una richiesta in corso alla volta; errori rete, autorizzazione, permessi, limite API, storage e risposta anomala.

## Incongruenze e differenze dichiarate

1. HOME/DIARIO/gruppi/report usano medie e tempi diversi: preservato e verificato, senza correggerlo arbitrariamente.
2. Il comando PDF web genera `Bainzuretta_YYYY.html`, poi richiede stampa dal browser. iOS genera direttamente un PDF con gli stessi contenuti, esportabile/stampabile dalla condivisione.
3. Target web: `parseInt` senza validazione consente valori negativi/NaN; al riavvio zero ricade su 5000. iOS accetta solo interi positivi: miglioramento esplicito di integrità dell'input, non modifica dei calcoli per target validi.
4. Due definizioni CSS sovrapposte dell'animazione oro; iOS realizza una sola animazione rispettando Riduci movimento.
5. Alcune variabili della striscia massima sono inutilizzate; conta il risultato effettivo `tutteStrisce`.
6. Il backup web non esporta preferenze/obiettivi. iOS offre in aggiunta un backup completo distinguibile, mantenendo il normale JSON web compatibile.
7. Il testo del README sulla sicurezza va contestualizzato: il Client Secret web sta in localStorage. iOS non lo memorizza né lo distribuisce e usa un broker HTTPS con segreti server e Keychain.
8. L'assenza di attività ciclistiche nella risposta di risync non propone cancellazioni: protezione originale intenzionalmente preservata.
9. Le viste web Attività/Mese/Settimana e il selettore ranking non persistono dopo chiusura; solo categoria RECORD e target sono preferenze persistite nell'originale.
