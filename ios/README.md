# Bainzuretta nativa per iOS

Progetto Swift + SwiftUI, separato dalla PWA. Tutto il lavoro è nel ramo **ios-native**, dentro `ios/`; i file web e il workflow Pages restano intatti. Nessuna WebView, nessuna dipendenza runtime esterna, firma locale ad-hoc per il simulatore senza certificati o account Apple Developer.

- [Guida semplice Windows → GitHub Actions → Appetize](docs/COLLAUDO-WINDOWS.md)
- [Inventario verificato nel codice originale](docs/INVENTARIO.md)
- [Architettura e decisioni tecniche](docs/RELAZIONE-TECNICA.md)
- [Matrice di equivalenza e stato delle verifiche](docs/EQUIVALENZA.md)
- [Configurazione Strava sicura](docs/STRAVA.md)
- [Esiti effettivi e verifiche ancora necessarie](docs/VERIFICHE.md)

## Struttura

```
ios/
  Bainzuretta.xcodeproj/    progetto e schema condiviso Bainzuretta
  Bainzuretta/App/          stato osservabile, navigazione e ciclo app
  Bainzuretta/Components/   componenti SwiftUI e formati visivi
  Bainzuretta/Features/     HOME, DIARIO, SFIDA, ARCHIVIO, RANKING, RECORD
  Bainzuretta/Services/     Keychain, OAuth nativo, PDF e documenti
  Sources/BainzurettaCore/  modelli, date civili, calcoli, 39 record, archivio e sync
  Tests/                   test portabili Swift e dati attesi dal JS originale
  NativeTests/             test iOS di stato, Keychain e PDF
  UITests/                 navigazione, inserimento, riapertura, tema e testo grande
  backend/                 broker OAuth Cloudflare Worker e test Node
  scripts/                 oracolo JS, generatore progetto e controlli artifact
```

## Compilazione

Aprire `ios/Bainzuretta.xcodeproj`, scegliere schema **Bainzuretta**, un iPhone Simulator e avviare. Minimo iOS 18.0; workflow su Xcode 27 e runtime iOS disponibile più recente, preferendo iPhone 18 Pro a parità di runtime. Non cambiare il target per installare su Windows: il simulatore gira in remoto.

Test del nucleo anche su Linux, con Swift 6.0 o successivo:

```sh
TZ=Europe/Rome node ios/scripts/web-oracle.cjs
swift test --package-path ios
node --test ios/backend/worker.test.mjs
```

Dopo aggiunta/rimozione di file Swift: `python3 ios/scripts/generate-project.py`. Il progetto generato è già incluso e non richiede XcodeGen, CocoaPods o altre installazioni.

Non pubblicare un artifact se build o test falliscono. Non inserire dati personali nei fixture. Il collegamento Strava reale richiede la configurazione personale descritta nella guida: i test simulati non attestano un accesso reale.
