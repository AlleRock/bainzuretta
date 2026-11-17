# Relazione tecnica

## Architettura

Il progetto Xcode usa SwiftUI e il pacchetto locale `BainzurettaCore`. Il nucleo non importa SwiftUI/UIKit: modelli e algoritmi sono gli stessi eseguiti nei test Linux/macOS e nell'app. Swift 5 language mode su toolchain Swift 6 evita obblighi di migrazione concurrency non necessari, mantenendo protocolli Sendable e isolamento esplicito dello stato UI su MainActor.

`AppStore` è osservabile, isolato MainActor e pubblica lo stato dopo la scrittura riuscita. `Statistics`, `RecordEngine`, `ArchiveCodec` e `StravaSync` sono funzioni/moduli separati. `FileArchive` gestisce il disco; `StravaRemote` usa un trasporto HTTP sostituibile nei test. `StravaConnection` gestisce ASWebAuthenticationSession e rinnovo credenziali. Nessuna dipendenza di rete per consultazione, calcoli o report.

## Persistenza

Scelta: documento JSON versionato in Application Support, con scrittura atomica Foundation. È una soluzione nativa adatta a questo archivio personale: conserva esattamente anche campi aggiuntivi non noti, richiede meno migrazioni di uno schema SwiftData e rende verificabile il round trip con il formato web. La validazione e i test da 12.000 attività precedono l'uso sul dispositivo. Non è un wrapper di localStorage.

Il documento contiene attività, obiettivi, categoria record e finestra incrementale incompleta. Il backup normale è l'array web; quello completo è un envelope versione 1. Non contiene token o chiavi. ID normalizzati con le stesse regole di sicurezza numerica JavaScript. La sostituzione è idempotente, non un merge implicito. Una copia precedente consente annullamento dell'importazione; un archivio corrotto è preservato separatamente quando l'utente conferma il recupero. Nessun salvataggio normale può sovrascrivere un archivio corrotto.

Su iOS il file attivo usa protezione `completeUntilFirstUserAuthentication`; i token e la chiave di abbinamento usano Keychain `AfterFirstUnlockThisDeviceOnly`. Il reset riguarda solo cartella e account Keychain Bainzuretta. Va sempre confermato dall'utente.

## Fedeltà dei calcoli

Le distinzioni fra medie descritte nell'inventario sono intenzionali. Non si usa una formula unica per tutti i contesti. `CivilDate` separa la data locale sportiva dall'istante UTC API, conta i giorni in calendario gregoriano UTC senza effetti DST e tratta i lunedì in modo deterministico. Settimane dei record attraversano l'anno, quote SFIDA no. YTD per numero di giorno.

L'oracolo Node legge `index.html` e ne esegue lo script intero con un adattatore DOM. I soli hook acquisiscono valori dentro le funzioni originali, senza riscriverne le formule in JavaScript. Verifica riepilogo HOME, gruppi, quattro ranking, quote e risultati SFIDA e tutte le voci/classifiche RECORD. I fixture includono origine/hash. CI rigenera i fixture e fallisce se cambiano senza revisione. Test numerici con tolleranza 1e-7; stringhe dei record confrontate esattamente, inclusi arrotondamenti e ordine delle parità.

Sei archivi sintetici: vuoto; confini/fasce/valori mancanti; 29 febbraio; 1 gennaio; 31 dicembre con obiettivo raggiunto; 600 attività deterministiche in dieci anni. Un test separato importa/esporta 12.000 attività e consulta tutte le categorie. Nessun dato reale dell'utente è stato usato.

## Interfaccia

Arancione, nome, schede arrotondate e sei sezioni conservati. Navigazione SwiftUI con pulsanti SF Symbols nel margine inferiore sicuro; nessuna sezione nascosta in un menu More. Con testo accessibile grande la barra può scorrere orizzontalmente per mantenere leggibili tutte le etichette. Liste native, menu contestuali e swipe con conferma, picker, form e fogli modali.

HOME presenta obiettivo e contatori compatti; aggiunta manuale in un foglio accessibile da HOME. Importazioni e opzioni meno usate restano in HOME con un gruppo espandibile. DIARIO/ARCHIVIO usano selettore segmentato e medaglie; RECORD mantiene categorie e liste integrali. Nessuna informazione eliminata per ridurre lo scrolling. Le schermate restano naturalmente scorrevoli, evitando pannelli fissi troppo grandi con Dynamic Type.

Tema dal sistema, dimensioni testo dal sistema, nessun font remoto, numeri monospaziati e testo secondario adattivo. Animazione oro e feedback aptico al traguardo; animazione rispettosa di Riduci movimento. Formazione dei numeri deterministica in italiano. Non si è tentato di incorporare i font Google senza una verifica delle relative licenze; il marchio usa un carattere serif corsivo di sistema.

## Rete e OAuth

Broker Worker stateless, abbinamento privato, state firmato e scaduto dopo 30 minuti, prova SHA256 legata al verificatore generato dall'app. Questo meccanismo protegge lo scambio presso il broker; **non** pretende che Strava implementi PKCE. Client Secret solo nei Secret del backend. Callback HTTPS del broker con destinazione fissa `bainzuretta://strava-callback`. Controllo scope e state nell'app prima dello scambio. Token nuovi salvati in Keychain prima di aggiornare lo stato; rinnovo singolo concorrente e con margine di 5 minuti. Revoca tramite endpoint Strava `/oauth/revoke` dal broker.

Attività ottenute direttamente dall'API Strava dall'app. Pagine da 100; nessun commit parziale; intervallo riprendibile; quattro tipi bici originali; update recenti e collisioni ID protette. Nessun download o import con dati fittizi nascosti. La conferma delle attività mancanti avviene in un foglio con elenco esplicito.

## Report

PDF vero generato da UIGraphicsPDFRenderer, paginato A4, testo ricercabile, senza HTML/WebView. Comprende totali, sei indicatori, Top 5 distanza e velocità, mesi, record cadenza e tutte le attività con durata/D+/cadenza. UIActivityViewController permette condivisione e, se il servizio/dispositivo lo supporta, salvataggio o stampa. Il test nativo controlla presenza di tutte le 160 attività e più pagine tramite PDFKit.

## Build e protezione produzione

Workflow aggiuntivo soltanto su `ios-native`, senza deployment, certificati o segreti Apple. Verifica Xcode ≥27, SDK, runtime; esegue test del nucleo, broker e test nativi/UI; build Release per Simulator ARM64, controlli Mach-O/platform, installazione e avvio con simctl, ZIP creato con ditto e upload artifact. Il package non è un IPA e non installa su iPhone fisico.

Il progetto Xcode e lo schema sono già versionati e rigenerabili con Python standard. Non è stato modificato `pages.yml`, non è stato creato alcun deployment Pages, non è stato effettuato alcun merge.

## Passi futuri separati dal lavoro implementato

1. Collaudo OAuth reale con un broker personale e un client Strava isolato dalla produzione web.
2. Collaudo Appetize con archivio reale scelto dall'utente e verifica della disponibilità runtime iOS 27 nel proprio account.
3. Revisione visiva su schermo fisico, VoiceOver e feedback aptico; questi ultimi non si possono giudicare dal browser.
4. Solo successivamente firma, dispositivo fisico, eventuale distribuzione e account Apple: nessuna di queste operazioni è stata attivata.
5. Se archivi molto più grandi rendono necessario l'accesso indicizzato, sostituire FileArchive con SQLite dietro lo stesso confine del servizio, conservando il codec JSON e i test di equivalenza.
