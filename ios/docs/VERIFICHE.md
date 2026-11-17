# Registro delle verifiche effettive

Aggiornato durante lo sviluppo del 17 novembre 2026. Questo registro distingue esecuzione del codice, build e collaudo reale dei servizi.

## Eseguito nell'ambiente Linux

- Swift 6.1.2: **14 test, zero fallimenti** dopo le correzioni, circa 6 secondi nell'ultima esecuzione.
- Oracolo: eseguito il JavaScript originale su sei dataset; confronto di tutte le 39 voci di record e di ogni entry disponibile, oltre a HOME, quattro ranking, gruppi e SFIDA.
- Persistenza: scrittura/riapertura, backup precedente, import ripetuto, envelope completo, archivio corrotto, reset e validazione duplicati; 12.000 attività.
- Strava simulato: paginazione, selezione tipi, doppioni, collisioni ID, update recenti, attività mancanti, errori HTTP, rete interrotta e risposta malformata.
- Backend Node: **3 test, zero fallimenti**, con verifiche di state/prova, scope, chiave privata, callback fisso, scambio/rinnovo/revoca e risposte anomale.
- Parsing di tutti i file Swift nativi; generazione deterministica del progetto Xcode; nessuna modifica ai file web.

Le differenze trovate nella prima conversione (formattazione decimale e raggruppamento migliaia) sono state corrette e il confronto rieseguito fino a zero differenze nei fixture.

## GitHub macOS

- Prima esecuzione: Xcode 27.1, SDK iOS 27.1 individuati. Selezione simulatore fallita per identificativi runtime che includono il modello: corretto il selettore, senza rimuovere il controllo.
- Seconda esecuzione: controllo Xcode/runtime, rigenerazione fixture, test broker e test Swift del nucleo **riusciti**. Build fermata prima dei test UI per differenza architetture: il target app tentava anche x86_64 mentre il pacchetto locale era ARM64. Impostazioni allineate ad ARM64; nuova esecuzione necessaria.

Gli esiti finali e il link all'esecuzione valida verranno aggiunti dopo il completamento dei controlli. La sola presenza del workflow non equivale a build riuscita.

- Terza esecuzione: architettura ARM allineata; la compilazione ha rilevato dichiarazioni multiple `@State` non accettate dalla macro SwiftUI di Xcode 27. Le proprietà sono state separate, mantenendo gli stessi valori iniziali. Test non saltati: nuova esecuzione prevista.
- Aggiunti confronti anche della conversione API Strava nei casi di arrotondamento binario a metà (`1.125`, `2.675`), oltre ai valori null. Implementato l'arrotondamento esatto `toFixed` del JavaScript, evitando la regola tie-to-even di printf.

- Quarta esecuzione: le viste SwiftUI passano la fase che segnalava le macro; il compilatore ha rilevato `greatestFiniteMagnitude` ambiguo nel layout PDF. Specificato esplicitamente `CGFloat` e mantenuti tutti i test.

## Non verificato con servizi reali

- OAuth Strava reale: manca broker configurato; l'utente ha richiesto codice e guida, senza collegamento esistente.
- Attività reali/backup personale: nessuno fornito o consultato. I test usano soltanto dati sintetici.
- Appetize: formato conforme alla documentazione; caricamento, esecuzione nel proprio account, trasferimento JSON/appunti, callback OAuth e condivisione file richiedono collaudo nel servizio.
- iPhone fisico: nessun dispositivo collegato, firma o account Developer attivato. Aptica e servizi fisici da verificare in seguito.
- Accessibilità completa VoiceOver, contrasto misurato e revisione visiva su tutti i formati: da eseguire oltre agli scenari automatici di base.

## Ripetizione

```sh
TZ=Europe/Rome node ios/scripts/web-oracle.cjs
swift test --package-path ios
node --test ios/backend/worker.test.mjs
python3 ios/scripts/generate-project.py
```

Per build/test nativi e pacchetto usare il workflow `Bainzuretta iOS Simulator` sul ramo `ios-native`. Log e xcresult sono nell'artifact separato `Bainzuretta-test-results`. Un fallimento non viene ignorato per pubblicare comunque l'app.
