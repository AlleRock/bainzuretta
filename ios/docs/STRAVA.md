# Configurazione personale Strava

**Stato: codice disponibile e test automatici con risposte simulate; autenticazione reale non ancora collaudata.** L'utente ha confermato di non disporre ancora di un broker. Nessun servizio è stato acquistato, nessun account o segreto è stato modificato.

## Prima di iniziare

Il Client Secret non deve essere inserito nell'app, nei file Swift, nel repository o in questa chat. L'app riceverà soltanto l'URL del broker e una chiave di abbinamento separata, salvata in Keychain.

Per mantenere indipendente la PWA, usare un **client API Strava dedicato alla versione nativa**. Non modificare il dominio di callback del client web `210700` e non rigenerarne il segreto. La modifica del dominio interromperebbe il ritorno OAuth web; anche condividere lo stesso client può interferire con la rotazione dei refresh token e una revoca può coinvolgere l'autorizzazione web. Se il proprio account Strava non permette una seconda applicazione API, fermare questa configurazione e chiedere a Strava come ottenere un client separato: il codice nativo non va usato come motivo per alterare la produzione.

Il piano gratuito Workers può essere adatto a un uso personale a basso traffico, entro i limiti e le condizioni correnti del fornitore. Non viene attivato automaticamente. La connessione richiede rete anche nel simulatore; la consultazione dell'archivio funziona offline.

## Preparazione da Windows, senza Mac

1. Aprire [Cloudflare Workers](https://dash.cloudflare.com/), accedere al proprio account e creare un Worker personale. Scegliere un percorso gratuito se disponibile; non attivare abbonamenti a pagamento per questa prova.
2. Aprire nel repository `ios/backend/worker.mjs`, copiare il contenuto completo e usarlo come codice del Worker. In alternativa, con Node installato, usare Wrangler da `ios/backend` e il file `wrangler.jsonc` incluso.
3. Nelle impostazioni del Worker aggiungere la variabile pubblica `STRAVA_CLIENT_ID`, con il numero del client **nativo**.
4. Aggiungere come variabili **Secret**, non normali variabili pubbliche:
   - `STRAVA_CLIENT_SECRET`: segreto del client nativo.
   - `PAIRING_KEY`: stringa casuale privata di almeno 32 caratteri.
   - `STATE_SIGNING_KEY`: un'altra stringa casuale privata di almeno 32 caratteri, differente dalla precedente.
5. Conservare le due stringhe in un gestore password. La chiave di firma non serve nell'app; la chiave di abbinamento sì. Non inviarle al repository o alla chat. Disabilitare log/osservabilità delle richieste; la configurazione Wrangler inclusa lo fa già.
6. Pubblicare il Worker **solo dopo** avere impostato queste variabili. Annotare l'URL HTTPS pubblico, per esempio `https://nome-personale.workers.dev`.
7. Nelle impostazioni del client Strava **nativo**, impostare Authorization Callback Domain al dominio del Worker, senza `https://` né `/callback`. Il broker costruisce automaticamente l'URL HTTPS `/callback`.
8. In Bainzuretta: HOME → Configura collegamento sicuro. Inserire l'URL HTTPS e il valore di `PAIRING_KEY`. Non inserire il Client Secret.
9. Premere Salva, poi Connetti con Strava. Nella finestra di autenticazione accedere al proprio account e concedere `activity:read_all`.
10. Attendere il ritorno all'app e il completamento dell'importazione. Confrontare almeno un'uscita nota con data, km, durata, D+ e cadenza di Strava.

Se si usa Wrangler, i segreti si impostano con comandi interattivi, senza scriverli nella cronologia:

```sh
npx wrangler secret put STRAVA_CLIENT_SECRET
npx wrangler secret put PAIRING_KEY
npx wrangler secret put STATE_SIGNING_KEY
npx wrangler deploy
```

Cambiare prima il placeholder `STRAVA_CLIENT_ID` in `wrangler.jsonc`. Le credenziali locali `.dev.vars` sono ignorate da Git. Non è necessario esporre CORS: l'app chiama il broker tramite URLSession, non JavaScript del browser.

## Come funziona

`POST /start` richiede chiave di abbinamento e restituisce URL Strava/state firmato. L'autenticazione usa ASWebAuthenticationSession, senza WebView dell'app. `GET /callback` valida state/scadenza/scope e rimanda al solo schema `bainzuretta://strava-callback`. `POST /exchange` richiede chiave, state e verificatore corrispondente alla prova SHA256; il segreto viene aggiunto soltanto sul server. `POST /refresh` rinnova i token. `POST /revoke` usa HTTP Basic con il segreto sul server per revocare l'autorizzazione. Nessun endpoint accetta URL di ritorno arbitrari; token e attività non sono conservati sul broker.

La chiave di abbinamento protegge l'uso del broker personale. Non sostituisce un sistema multiutente: per distribuire pubblicamente l'app sarà necessario aggiungere gestione utenti e limiti server appropriati. Questa versione è per il progetto personale richiesto.

## Prova in simulatore/Appetize

- Safari e ASWebAuthenticationSession del simulatore devono poter raggiungere Strava e il broker.
- Lo schema di ritorno è registrato in Info.plist. Non richiede Universal Links, dominio Apple associato o account Apple Developer per il simulatore.
- Non serve l'app Strava installata. I link delle attività provano ad aprirla e usano il browser se non è disponibile.
- Login Google/Apple, 2FA o antiabuso di Strava possono avere limitazioni nel browser remoto. Usare il login supportato da Strava dentro la sessione mostrata. Non è stato verificato con un account reale.
- La sessione Appetize può essere effimera: token e archivio del simulatore non sono garantiti tra sessioni. Conservare un backup esterno.
- Se la finestra Strava resta aperta dopo l'autorizzazione, annotare se il broker è raggiungibile e se il ritorno all'app avviene. Non riportare query con `code` o `state` negli screenshot.

## Errori e verifica

Rete assente: nessun aggiornamento parziale, riprovare. Limite API: attendere. Scope assente: riconnettere concedendo il permesso. Sessione revocata: riconnettere. Broker non configurato o chiave errata: ricontrollare i Secret del Worker e l'abbinamento nell'app. Non cancellare l'archivio per risolvere errori OAuth.

Un collaudo reale completo dovrà includere: primo collegamento; sincronizzazione incrementale; rinomina attività e risync; nessun duplicato dopo seconda sync; attività cancellata e scelta conserva/rimuovi; rinnovo di token scaduto; disconnessione locale; revoca remota; riconnessione. Le risposte simulate verificano la logica, non l'effettivo comportamento di Strava o Appetize.

Fonti ufficiali consultate: [OAuth Strava](https://developers.strava.com/docs/authentication/), [Workers Secrets](https://developers.cloudflare.com/workers/configuration/secrets/).
