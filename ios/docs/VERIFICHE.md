# Verifiche effettive e limiti

Aggiornato il 17 novembre 2026. Fonte web: commit `5b25cf855fe4d6782d7db26c6463309b7815f98a`; sorgenti nativi sottoposti al collaudo: `de267d628edab011c3613aa38321378f0186c224`. Eventuali commit successivi di sola documentazione non cambiano l'app verificata.

## Esecuzione di riferimento

[GitHub Actions — Bainzuretta iOS Simulator, esecuzione 44160612164](https://github.com/AlleRock/bainzuretta/actions/runs/44160612164).

**Esito: successo.** Xcode **27.1**, SDK Simulator **27.1**, iPhone **18 Pro / iOS 27.0**. Riusciti **14 test Swift del nucleo + 3 test Node del broker + 5 test nativi iOS + 5 test UI**, tutti senza fallimenti. Una prova aggiuntiva ripete navigazione/inserimento/riapertura sulla **Release effettivamente confezionata**: riuscita anch’essa. Sono quindi 27 test distinti e 28 esecuzioni di test. La build Release e l’upload degli artifact sono riusciti.

## Calcoli, dati e servizi simulati

- **14 test Swift del nucleo**, eseguiti realmente anche su Linux con Swift 6.1.2 e su macOS nel workflow. I test confrontano tutte le **39 voci RECORD** delle sette categorie, i relativi valori, sottotitoli, entry, ordine, ID e classifiche con il JavaScript originale eseguito da Node. Stringhe esatte; valori numerici con tolleranza 1e-7.
- Sei dataset sintetici: archivio vuoto, limiti delle fasce, valori mancanti, anni bisestili, gennaio/dicembre e 600 attività deterministiche in dieci anni. Sono verificati HOME, obiettivi, quattro ranking, gruppi mensili/settimanali e ogni riga SFIDA. Nessun backup personale è stato fornito o usato.
- Importazione/esportazione e record su **12.000 attività**; round trip dei campi aggiuntivi e identificativi; import ripetuto; duplicati; dati non validi; scrittura/riapertura; copia precedente; corruzione; recupero e reset.
- API Strava simulata: pagine da 100, quattro valori originali di `type`, conversioni e arrotondamenti, doppioni e collisioni, update recenti con ID/metadati conservati, attività mancanti e margini UTC. Errori HTTP/rete e risposte malformate non producono commit parziali.
- **3 test Node del broker** con upstream Strava simulato: abbinamento, state/prova, scope, destinazione callback fissa, scambio, rinnovo, revoca e risposte anomale.

Il confronto ha richiesto di riprodurre sia la formattazione italiana delle migliaia sia l'arrotondamento binario esatto di `toFixed` JavaScript: per esempio `1.125 → 1.13` e `2.675 → 2.67`. Le formule differenti fra contesti sono conservate e descritte nell'inventario.

## Test nativi iOS

I **5 test nativi** verificano sul simulatore:

1. Rifiuto di URL broker non HTTPS, credenziali nell'URL e query inattese.
2. Keychain reale: scrittura, lettura, aggiornamento e cancellazione di valori fittizi di test. Nessun token reale utilizzato. La firma locale ad-hoc e gli entitlement sono limitati al Simulator.
3. PDF reale multipagina: PDFKit trova le sezioni del report e tutte le **160 attività** generate per il test.
4. AppStore: attività manuale, obiettivo/categoria persistenti, riapertura, modifica con ID invariato, annullamento e cancellazione; scelte di raggruppamento/ranking mantenute nel cambio menu e ripristinate al default alla riapertura, come nel web.
5. Importazione web che conserva le preferenze più recenti e backup completo che ripristina quelle incluse nel file.

## Test dell'interfaccia

I **5 test UI** coprono:

- Apertura di tutti i sei menu; aggiunta di 42,5 km, durata e ritrovamento dopo chiusura/riavvio.
- Tutte le sette categorie RECORD; apertura e ritorno da cinque Top 5 rappresentative. DISLIVELLO e CADENZA sono aperti senza dati nel caso UI manuale; i valori sono verificati dal nucleo.
- Incolla JSON, verifica, conferma di sostituzione e seconda importazione dello stesso file, con una sola attività risultante.
- Navigazione orizzontale fino a RECORD con Dynamic Type accessibile molto grande e apertura della pagina.
- Tema scuro e annullamento dell'inserimento senza creare attività.

Le schermate sono allegati reali del simulatore, esportati nell'artifact `Bainzuretta-screenshots`, non mockup. HOME, RECORD, tema scuro e testo grande sono sottoposti anche a ispezione visiva. Queste prove non coprono ogni tocco di tutti i form e non equivalgono a una revisione completa VoiceOver o di tutti i formati dello schermo; la [matrice](EQUIVALENZA.md) indica i controlli specifici mancanti.

## Pacchetto simulatore

[Scarica l’artifact Bainzuretta-iOS-Simulator](https://github.com/AlleRock/bainzuretta/actions/runs/44160612164/artifacts/14365995426). Contiene lo ZIP interno **Bainzuretta-iOS-Simulator.zip**, il relativo `.sha256` e una schermata reale della HOME della Release.

Verifiche compiute nel workflow e ripetute sul pacchetto scaricato:

- ZIP interno integro, **3.268.688 byte**, contenente `Bainzuretta.app` con eseguibile Mach-O compilato. Nessun sorgente Swift o fixture/oracolo incluso.
- Bundle `it.allerock.Bainzuretta`; piattaforma `iPhoneSimulator`; architettura **ARM64**, verificata con lipo; LC_BUILD_VERSION **IOSSIMULATOR**, minimo iOS **18.0**, SDK **27.1**.
- La prova UI usa il runner già compilato indirizzato al percorso `Release-iphonesimulator/Bainzuretta.app`, lo stesso bundle poi compresso. Installa da zero, apre i sei menu, salva 42,5 km, chiude e riapre l’app verificando il dato. La schermata di anteprima proviene da questa prova, dopo il caricamento della HOME; è stata ispezionata e mostra l’interfaccia correttamente. Una precedente cattura a soli tre secondi dall’avvio era ancora bianca: è stata sostituita da questa verifica esplicita della Release.
- SHA256 dello **ZIP interno** (differente dall’hash del contenitore GitHub):

```text
632d0a89102d7add6c25b048c5ccaa7d9f531c275e0be3921ce25e1d53774dfe
```

L’artifact dell’app scade il **17 dicembre 2026**; può essere rigenerato con Re-run all jobs. [Schermate reali dei test](https://github.com/AlleRock/bainzuretta/actions/runs/44160612164/artifacts/14364598054) e [log/xcresult](https://github.com/AlleRock/bainzuretta/actions/runs/44160612164/artifacts/14365835817) hanno conservazione di 14 giorni. La disponibilità di questi artifact è stata verificata via API GitHub; app e schermate sono state effettivamente scaricate.

Il workflow rigenera le attese dal JS e il progetto Xcode, fallendo se risultano differenze non versionate. Build, test nativi, test UI e build Release devono riuscire prima dell'upload dell'app. Solo l'esportazione delle schermate diagnostiche è facoltativa: nessun test fallito viene ignorato.

## Protezione della versione web

`main` è rimasto al commit originale `5b25cf8`. `index.html`, `README.md`, `manifest.json`, `sw.js`, `icona.png` e `.github/workflows/pages.yml` sono identici al punto di partenza anche su `ios-native`. Nessun merge, deployment Pages, acquisto, attivazione Apple Developer, App Store o TestFlight.

## Non verificato con servizi o dati reali

- **OAuth/sync Strava reali:** l'utente ha confermato di non avere ancora un broker e ha richiesto codice e guida di configurazione. Il broker non è stato pubblicato e nessun account è stato collegato. Test simulati e Keychain riusciti non attestano un login reale.
- **Backup personale:** nessuno fornito; l'importazione è verificata con dati sintetici compatibili con il formato originale.
- **Appetize:** formato del bundle conforme alla documentazione consultata; upload e sessione nel proprio account, disponibilità del runtime, trasferimento JSON/appunti, callback OAuth e servizi di condivisione non ancora collaudati nel servizio.
- **iPhone fisico:** nessun dispositivo collegato. Aptica, installazione fisica e distribuzione richiedono una fase successiva.
- **Altre interazioni:** selettore File, condivisione/stampa iOS, tutte le conferme, tutte le aperture individuali dei record e i selettori di anni/gruppi non sono coperti dai cinque test UI; vedere la matrice.

## Ripetere le verifiche

```sh
TZ=Europe/Rome node ios/scripts/web-oracle.cjs
swift test --package-path ios
node --test ios/backend/worker.test.mjs
python3 ios/scripts/generate-project.py
```

Per build e test iOS usare **Re-run all jobs** nell'esecuzione collegata sopra; la [guida Windows](COLLAUDO-WINDOWS.md) spiega ogni passaggio. `workflow_dispatch` è dichiarato, ma il pulsante Run workflow dipende dalla presenza del file sul ramo predefinito, che non è stato modificato. L'artifact `Bainzuretta-test-results` contiene log e xcresult; `Bainzuretta-iOS-Simulator` contiene l'app; `Bainzuretta-screenshots` contiene le schermate consultabili da Windows.
