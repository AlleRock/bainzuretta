# Matrice di equivalenza funzionale

Fonte: commit web `5b25cf8`. Dettagli e formule in [INVENTARIO](INVENTARIO.md). Esiti aggiornati in [VERIFICHE](VERIFICHE.md).

Legenda: **V** implementato e verificato dal test indicato; **N** implementato ma collaudo specifico ancora da eseguire; **P** parziale/condizionato da configurazione esterna; **M** mancante. Una verifica del calcolo non certifica automaticamente tutti i tocchi dell'interfaccia o un servizio reale.

| Funzione | Originale → implementazione iOS | Stato | Test / esito / limite |
|---|---|---|---|
| Sei menu invariati | HOME, DIARIO, SFIDA, ARCHIVIO, RANKING, RECORD → AppSection/RootView | N UI | Test UI configurato; esito finale nel registro |
| Target per anno | default 5000, modifica e persistenza → Preferences/AppStore | V nucleo; N UI | ArchiveTests; test nativo previsto. Input iOS limitato esplicitamente a interi positivi |
| Km mancanti/proiezione/km settimanali | formule originali → Statistics.goal | V | EquivalenceTests su sei dataset, anche gennaio/dicembre/bisestile |
| Colori e traguardo | soglie passo, oro, animazione, legenda → GoalCard/GoalSettings | N visivo | Calcoli implementati; controllo visivo/aptico fisico ancora necessario |
| Arrivo stimato | passo corrente → Goal.arrivalDays/GoalCard | V calcolo; N UI | ArchiveTests: passo, percentuale, proiezione, colori e arrivo controllati con valori attesi |
| Contatori storici | totale, mondo, miglior media positiva anno → Statistics/Summary | V | EquivalenceTests esatto entro 1e-7 |
| Inserimento manuale | data, km, durata/formati → Activity.manual e form | V nucleo; N UI | Validazione, ore e annullamento testati; percorso UI configurato |
| Modifica/annulla | solo manuali, ID e metadati conservati → AppStore/form | V nucleo; N UI | ArchiveTests, test nativo previsto |
| Eliminazione | conferma e rimozione locale → ActivityRow/AppStore | N UI | Operazione e conferma presenti; nessuna cancellazione su Strava |
| DIARIO | anno intero, lista data decrescente, recap → JournalView | V filtri/calcoli; N UI | YTD e medie distinte in test; scenario UI previsto |
| ARCHIVIO | anni escluso corrente, DOY e tre viste → JournalView | V filtri/calcoli; N UI | Leap-year/DOY verificati; selezione e dettaglio da collaudare |
| Gruppi e medaglie | mese/lunedì, top tre km, drill-down → Statistics.groups | V gruppi; N UI | Chiavi, km, ore, D+, numero e ID confrontati con JS |
| SFIDA | settimane tagliate, quota giorni, delta e zero corrente → challenge/ChallengeView | V calcoli; N UI | Ogni riga dei sei fixture confrontata |
| Ranking quattro metriche | YTD, medie diverse, D+ dal 2019 → Statistics.ranking | V calcoli; N UI | Ogni anno/valore/totale confrontato |
| Ranking apre Archivio | selezione anno → AppStore.openYear | N UI | Implementato; da verificare interazione specifica |
| Categoria RECORD ricordata | localStorage → Preferences/archivio nativo | V nucleo; N UI | Persistenza/rilettura; test nativo previsto |
| Top 5 e liste complete | modale originale → RecordStandings | V dati; N UI | Tutte le entry confrontate; ≥100/≥150 non limitate a cinque |
| Link attività | app Strava con fallback web → StravaLink | N esterno | Dipende dall'app Strava/browser nel simulatore |
| Import JSON web | sostituzione, normalizzazione, ID e campi extra → ArchiveCodec | V | Round trip, BOM, numeri stringa, null, input errati e duplicati |
| Import ripetuto | nessun doppione → sostituzione idempotente | V | ArchiveTests con seconda importazione |
| Backup/recupero | copia precedente e archivio corrotto conservato → FileArchive | V | Salvataggio, riapertura, recupero e corruzione testati |
| Backup completo | aggiunta iOS per obiettivi/preferenze → Archive envelope v1 | V | Round trip; normale JSON web resta separato |
| Consultazione offline | cache web → archivio locale senza dipendenza rete | V nucleo; N flusso iOS offline | Lettura/calcoli locali testati; prova modalità aereo non eseguita |
| Reset | conferma, solo dati Bainzuretta → FileArchive/Keychain | V archivio; N UI/Keychain | Reset disco testato; test Keychain nativo previsto |
| PDF anno | HTML stampabile → PDF nativo con contenuto equivalente | N iOS | Codice e test PDFKit multipagina presenti, in attesa esecuzione |
| Condivisione/stampa | download browser → FileExporter/UIActivityViewController | N sistema | Richiede simulatore/Appetize o dispositivo per le opzioni disponibili |
| OAuth2 | state/scope e consenso → ASWebAuthenticationSession + broker | P reale | Backend simulato V; manca configurazione personale |
| Segreto/token | localStorage web → Secret server + Keychain | V backend; N Keychain | Nessun segreto distribuito; test nativo Keychain previsto |
| Rinnovo token | margine 5 min/singola richiesta → StravaConnection | N reale | Logica presente; contratto backend simulato V |
| Tipi bici e conversioni | quattro act.type e arrotondamenti → StravaRemote | V simulato | Pagine, filtri, km/ore/media e doppioni testati |
| Sync incrementale | solo nuove, finestra fissa riprendibile → AppStore/StravaSync | V logica; P reale | Collisioni e duplicate API testate; riavvio reale durante sync da collaudare |
| Resync 60 giorni | update ID invariati e confronto ±1e-6 → StravaSync | V simulato; P reale | Update/metadati/ID testati; nessun accesso account reale |
| Attività sparite | margini UTC, guardia vuoto e conferma → pendingRemoval | V piano; N conferma UI | Guardie e risultato conserva/rimuovi testati |
| Errori API/rete | auth/scope/429/risposta/storage → errori italiani | V simulato; N tutte le presentazioni | StravaTests/worker tests; archivio non parzialmente modificato |
| Disconnessione/revoca | locale o autorizzazione remota → broker /revoke | V contratto; P reale | HTTP Basic resta server; nessuna revoca reale eseguita |
| Tema, testo, safe area | CSS → SwiftUI adattivo | N UI | Scenari scuro/testo grande configurati; revisione visiva da completare |
| Font/identità/icona | arancione e icona conservati, font sistema | N visivo | Niente font remoti; icona quadrata senza taglio |
| PWA/service worker | installazione web/offline → app nativa e archivio locale | V separazione | PWA originale intatta; service worker non incluso nel runtime nativo |
| Progetto Xcode/manutenibilità | monofile web → moduli separati e progetto riproducibile | V generatore; N build finale | Parsing Swift e determinismo verificati; runner macOS in esecuzione |
| Build/artifact simulatore | nuova funzione → workflow macOS/Xcode 27 | P fino al successo | Formato/validazione/avvio configurati; link finale nel registro |
| workflow_dispatch | dichiarato, più trigger push e rerun | P interfaccia GitHub | Run workflow richiede file sul ramo predefinito; main intatto, usare Re-run all jobs |
| Appetize | nuova destinazione di collaudo | P | Formato documentato; upload/sessione/account non collaudati |
| Installazione fisica | obiettivo futuro | M intenzionale | Fuori dall'ambito attuale; nessuna firma o distribuzione attivata |

## Ogni record originale

Le voci seguenti sono tutte implementate in `RecordEngine.records`. **V calcolo/dati**: ogni titolo, valore, sottotitolo, entry, ordine e ID attività è confrontato con il JS originale nei sei dataset. **N consultazione UI specifica**: la verifica numerica non sostituisce la prova di ogni schermata. Per assenza di un dato la voce rimane presente con trattino, come nel web.

| Categoria | Nome originale conservato | Implementazione | Test / stato / limite |
|---|---|---|---|
| DISTANZA | Giro più lungo | RecordEngine / dist / 1 | EquivalenceTests: V calcolo, N UI; Top 5 |
| DISTANZA | Uscite ≥100 km | RecordEngine / dist / 2 | EquivalenceTests: V calcolo, N UI; Elenco integrale, non Top 5 |
| DISTANZA | Uscite ≥150 km | RecordEngine / dist / 3 | EquivalenceTests: V calcolo, N UI; Elenco integrale, non Top 5 |
| DISTANZA | Settimana con più km | RecordEngine / dist / 4 | EquivalenceTests: V calcolo, N UI; Top 5 |
| DISTANZA | Mese con più km | RecordEngine / dist / 5 | EquivalenceTests: V calcolo, N UI; Top 5 |
| DISTANZA | Anno con più km | RecordEngine / dist / 6 | EquivalenceTests: V calcolo, N UI; Top 5 |
| DISTANZA | Max km in 7 giorni mobili | RecordEngine / dist / 7 | EquivalenceTests: V calcolo, N UI; Top 5 |
| VELOCITÀ | Media più alta in assoluto | RecordEngine / vel / 1 | EquivalenceTests: V calcolo, N UI; Top 5 |
| VELOCITÀ | Media più alta su uscite 30–49,9 km | RecordEngine / vel / 2 | EquivalenceTests: V calcolo, N UI; Top 5 |
| VELOCITÀ | Media più alta su uscite 50–99,9 km | RecordEngine / vel / 3 | EquivalenceTests: V calcolo, N UI; Top 5 |
| VELOCITÀ | Media più alta su uscite ≥100 km | RecordEngine / vel / 4 | EquivalenceTests: V calcolo, N UI; Top 5 |
| VELOCITÀ | Miglior media su uscite 50–60 km | RecordEngine / vel / 5 | EquivalenceTests: V calcolo, N UI; Top 5 |
| VELOCITÀ | Miglior media su uscite 100–110 km | RecordEngine / vel / 6 | EquivalenceTests: V calcolo, N UI; Top 5 |
| TEMPO | Uscita più lunga | RecordEngine / tempo / 1 | EquivalenceTests: V calcolo, N UI; Top 5 |
| TEMPO | Settimana con più ore in sella | RecordEngine / tempo / 2 | EquivalenceTests: V calcolo, N UI; Top 5 |
| TEMPO | Mese con più ore in sella | RecordEngine / tempo / 3 | EquivalenceTests: V calcolo, N UI; Top 5 |
| TEMPO | Anno con più ore in sella | RecordEngine / tempo / 4 | EquivalenceTests: V calcolo, N UI; Top 5 |
| DISLIVELLO | Più dislivello in un’uscita | RecordEngine / disliv / 1 | EquivalenceTests: V calcolo, N UI; Top 5 |
| DISLIVELLO | Maggior densità di salita (min 20 km) | RecordEngine / disliv / 2 | EquivalenceTests: V calcolo, N UI; Top 5 |
| DISLIVELLO | Settimana con più dislivello | RecordEngine / disliv / 3 | EquivalenceTests: V calcolo, N UI; Top 5 |
| DISLIVELLO | Mese con più dislivello | RecordEngine / disliv / 4 | EquivalenceTests: V calcolo, N UI; Top 5 |
| DISLIVELLO | Anno con più dislivello | RecordEngine / disliv / 5 | EquivalenceTests: V calcolo, N UI; Top 5 |
| CADENZA | Cadenza media più alta | RecordEngine / cad / 1 | EquivalenceTests: V calcolo, N UI; Top 5 |
| CADENZA | Cadenza media più alta su uscite 30–49,9 km | RecordEngine / cad / 2 | EquivalenceTests: V calcolo, N UI; Top 5 |
| CADENZA | Cadenza media più alta su uscite 50–99,9 km | RecordEngine / cad / 3 | EquivalenceTests: V calcolo, N UI; Top 5 |
| CADENZA | Cadenza media più alta su uscite ≥100 km | RecordEngine / cad / 4 | EquivalenceTests: V calcolo, N UI; Top 5 |
| CADENZA | Anno con cadenza media più alta | RecordEngine / cad / 5 | EquivalenceTests: V calcolo, N UI; Top 5 |
| COSTANZA | Striscia più lunga di settimane consecutive | RecordEngine / cost / 1 | EquivalenceTests: V calcolo, N UI; Top 5 |
| COSTANZA | Striscia attuale | RecordEngine / cost / 2 | EquivalenceTests: V calcolo, N UI; Valore singolo |
| COSTANZA | Settimana con più uscite | RecordEngine / cost / 3 | EquivalenceTests: V calcolo, N UI; Top 5 |
| COSTANZA | Mese con più uscite | RecordEngine / cost / 4 | EquivalenceTests: V calcolo, N UI; Top 5 |
| COSTANZA | Anno con più uscite | RecordEngine / cost / 5 | EquivalenceTests: V calcolo, N UI; Top 5 |
| CURIOSITÀ | Giorno della settimana più pedalato | RecordEngine / cur / 1 | EquivalenceTests: V calcolo, N UI; Top 5 |
| CURIOSITÀ | Mese dell’anno più pedalato | RecordEngine / cur / 2 | EquivalenceTests: V calcolo, N UI; Top 5 |
| CURIOSITÀ | Max km in 4 giorni | RecordEngine / cur / 3 | EquivalenceTests: V calcolo, N UI; Top 5 |
| CURIOSITÀ | Media km per uscita | RecordEngine / cur / 4 | EquivalenceTests: V calcolo, N UI; Valore singolo |
| CURIOSITÀ | Media uscite per mese | RecordEngine / cur / 5 | EquivalenceTests: V calcolo, N UI; Valore singolo |
| CURIOSITÀ | Numero di uscite ≥100 km | RecordEngine / cur / 6 | EquivalenceTests: V calcolo, N UI; Valore singolo |
| CURIOSITÀ | Numero di uscite ≥150 km | RecordEngine / cur / 7 | EquivalenceTests: V calcolo, N UI; Valore singolo |

La conversione non è dichiarata interamente collaudata: i servizi reali e i controlli indicati N/P richiedono le verifiche descritte. Nessuna categoria o voce identificata nel codice originale è stata rimossa.
