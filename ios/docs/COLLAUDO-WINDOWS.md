# Prima prova da Windows 11

Non occorrono Mac, Xcode sul PC o un abbonamento Apple Developer. Il codice viene compilato da GitHub su un Mac remoto; il simulatore viene poi mostrato nel browser da Appetize. Non si sta installando l'app sul tuo iPhone fisico.

## 1. Trovare e avviare la compilazione

1. Accedi a GitHub e apri [Bainzuretta → Actions](https://github.com/AlleRock/bainzuretta/actions).
2. Nella lista a sinistra scegli **Bainzuretta iOS Simulator**. Non scegliere Deploy Pages.
3. Apri l'esecuzione più recente riferita al ramo **ios-native**.
4. Per ripetere la prova premi **Re-run all jobs** in alto a destra. L'operazione ricompila lo stesso commit senza modificare `main`.
5. Se GitHub mostra **Run workflow**, puoi usare quello e scegliere **ios-native** nel menu del ramo.
6. Aspetta che l'esecuzione termini. Il cerchio verde significa successo; rosso significa errore. Non usare un pacchetto di una compilazione fallita.

**Perché potrebbe mancare Run workflow?** Il file include `workflow_dispatch`, ma GitHub richiede che un workflow manuale sia presente anche nel ramo predefinito per rendere disponibile l'avvio manuale. In questa consegna `main` è protetto come richiesto e non è stato modificato. L'avvio da push su `ios-native` e **Re-run all jobs** consentono il collaudo senza intervenire sulla produzione. Aggiungere in futuro il solo workflow al ramo predefinito richiederà una decisione separata: non fare merge dell'intera conversione per mostrare un pulsante.

## 2. Scaricare il file giusto

1. Apri una esecuzione verde e scorri fino a **Artifacts**.
2. Clicca **Bainzuretta-iOS-Simulator**. GitHub potrebbe richiederti di essere connesso.
3. Windows scarica lo ZIP esterno dell'artifact. Aprilo o estrailo con Esplora file.
4. All'interno trovi **Bainzuretta-iOS-Simulator.zip** e il file di controllo `.sha256`.
5. Il file da caricare su Appetize è **Bainzuretta-iOS-Simulator.zip**, senza estrarlo ulteriormente.
6. Se lo apri per curiosità, contiene **Bainzuretta.app**, non file Swift. Non caricare lo ZIP del repository e non cercare un IPA.

Gli artifact hanno una scadenza. Se non sono più disponibili, ripeti la compilazione. **Bainzuretta-test-results** contiene invece log, risultati dei test e schermate: non è l'app da caricare.

## 3. Aprire Appetize

1. Apri [Appetize.io](https://appetize.io/) in Edge o Chrome.
2. Accedi al tuo account, oppure segui la registrazione offerta dal servizio se vuoi procedere. Questo progetto non ha creato account né acquistato piani.
3. Controlla i limiti del piano attuale prima di proseguire. Non serve attivare un abbonamento Apple.
4. Nel pannello cerca **Upload** o **Add app** e scegli iOS.
5. Seleziona il file interno **Bainzuretta-iOS-Simulator.zip**.
6. Attendi il completamento del caricamento e apri la pagina della nuova app.
7. Scegli un iPhone e un runtime iOS compatibile. Se sono presenti iPhone 18 Pro e iOS 27, usali; altrimenti scegli il più vicino fra quelli supportati dal servizio e dal pacchetto. L'app richiede almeno iOS 18.
8. Premi il pulsante di avvio della sessione, normalmente **Tap to Play** o **Start**.

La build è ARM64 Simulator, formato attualmente raccomandato da Appetize. Il runtime effettivamente usato nei test GitHub è registrato nei risultati. La disponibilità di iOS 27 sul tuo account Appetize va verificata lì: non viene dedotta dalla disponibilità su GitHub.

## 4. Prime operazioni

- **HOME**: tocca l'obiettivo per modificarlo e leggere la legenda. Aggiungi un'attività manuale con data, km e durata. Il pulsante Annulla chiude la modifica senza salvarla.
- **DIARIO**: cambia Attività/Mese/Settimana; tocca una riga per i dettagli. Scorri la riga lateralmente o tienila premuta per modificare/eliminare.
- **SFIDA**: controlla quota, km fatti e differenza per ogni settimana.
- **ARCHIVIO**: seleziona un anno precedente e cambia vista. I dati sono YTD: stesso numero di giorno dell'anno attuale.
- **RANKING**: scegli una delle quattro metriche; tocca un anno storico per aprirlo in ARCHIVIO.
- **RECORD**: scegli una delle sette categorie e tocca il primato per vedere Top 5 o l'elenco completo delle uscite ≥100/≥150 km.

Con testo molto grande, la barra inferiore scorre orizzontalmente: tutte le sei sezioni restano disponibili.

## 5. Importare il tuo backup reale

Prima esporta **BACKUP JSON** dalla Bainzuretta web e conserva quel file sul PC. Non incollarlo in chat: può contenere nomi, date e identificativi personali.

Dentro l'app iOS scegli HOME → **Importa JSON**. Si apre il selettore File del simulatore, non quello di Windows. Se il servizio permette di trasferire un file nella cartella Documenti dell'app o in File, trasferisci lì il JSON e selezionalo. La semplice funzione Appetize per caricare foto/video non garantisce il trasferimento di un JSON generico: dipende dagli strumenti e dal piano del servizio.

Alternativa già inclusa:

1. Apri il file JSON sul PC con Blocco note. Seleziona tutto e copia.
2. In HOME espandi **Altre opzioni di backup** e scegli **Incolla backup JSON**.
3. Usa il comando di incolla/trasferimento testo disponibile nella sessione Appetize per inserire il testo nel riquadro dell'app. Non è garantito che Ctrl+V del PC venga trasferito automaticamente nel simulatore.
4. Premi **Verifica**. Leggi il numero delle attività e conferma **Sostituisci**.
5. Se il servizio limita la quantità di testo o non trasferisce gli appunti, questo percorso non è disponibile per archivi grandi: usare il trasferimento file/documenti del piano Appetize, oppure provare in un altro simulatore remoto compatibile.

L'importazione sostituisce l'archivio, conserva una copia precedente e non moltiplica i dati se ripeti lo stesso file. Se sbagli file, usa HOME → Altre opzioni → **Ripristina archivio precedente**. Un errore di validazione lascia intatti i dati esistenti.

## 6. Strava

Vedi [guida Strava](STRAVA.md). La sola build non contiene un servizio OAuth già attivo. Per il primo test servono un broker personale e le relative impostazioni. Non inserire il Client Secret nell'app. I dati del test automatico non sono collegati al tuo account reale.

## 7. PDF e backup

In HOME scegli **PDF riepilogo anno** per creare un vero PDF e aprire la condivisione iOS. Salva/condividi/stampa se il servizio lo permette. **Backup JSON** esporta il file compatibile con la versione web. Il backup completo salva anche obiettivi e preferenze ed è destinato al ripristino nella versione iOS.

Conserva sempre una copia sul PC. Non dare per scontato che Appetize mantenga i dati o il portachiavi fra sessioni, reinstallazioni o caricamenti di nuove build. Non caricare una sessione contenente dati personali come demo pubblica.

## 8. Segnalare un problema

Indica: link della esecuzione GitHub; se l'errore accade durante build, caricamento o uso; modello/runtime del simulatore; sezione e pulsanti usati; risultato atteso e risultato ottenuto. Aggiungi il messaggio di errore o una schermata senza dati personali. Non inviare token, chiavi, codici OAuth o l'intero backup personale.

Se la build è rossa, apri la riga rossa nei job e copia soltanto le righe finali dell'errore. Se manca l'artifact, non usare Download ZIP dalla pagina Code: quello è solo sorgente.

## Limiti del collaudo remoto

Il formato del pacchetto viene controllato nel workflow e l'app viene installata/avviata nel simulatore Apple. Il caricamento effettivo nel tuo account Appetize, trasferimento JSON, ritorno OAuth, condivisione file, persistenza fra sessioni e servizi del sistema operativo richiedono il collaudo nel servizio. Aptica e comportamento di un iPhone fisico non sono verificabili dal browser.

Fonti: [formato iOS Appetize](https://docs.appetize.io/platform/app-management/uploading-apps/ios), [esecuzione manuale GitHub Actions](https://docs.github.com/en/actions/how-tos/managing-workflow-runs-and-deployments/managing-workflow-runs/manually-running-a-workflow).
