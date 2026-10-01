# 🚴 Bainzuretta

[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-v8.4-orange?style=flat-square&logo=github)](https://allerock.github.io/bainzuretta/)
[![PWA](https://img.shields.io/badge/PWA-Ready-brightgreen?style=flat-square&logo=progressive-web-apps)](https://allerock.github.io/bainzuretta/)
[![Strava API](https://img.shields.io/badge/Strava-Integrated-FC4C02?style=flat-square&logo=strava)](https://www.strava.com/)

**Bainzuretta** è un'applicazione web progressiva (PWA) e standalone, leggera e ottimizzata per dispositivi mobili, progettata per i ciclisti che desiderano monitorare le proprie attività, sfidare i propri limiti storici e tracciare in tempo reale l'avvicinamento al proprio obiettivo chilometrico annuale.

Nata come strumento personale e indipendente, Bainzuretta si interfaccia nativamente con le **API di Strava** per sincronizzare automaticamente le uscite (Ride, VirtualRide, EBikeRide, MountainBikeRide) memorizzando in modo sicuro tutti i dati in locale sul dispositivo dell'utente.

---

## 🌟 Funzionalità Principali

### 📊 Dashboard & Target Dinamico (Home)
* **Pace-Tracking Intelligente:** Il box dell'obiettivo cambia colore dinamicamente in base alle tue performance rispetto alla tabella di marcia dell'anno corrente:
  * 🟢 **Verde:** Sei in anticipo sulla tabella di marcia.
  * 🟡 **Giallo:** Sei in leggero ritardo (entro il 10%).
  * 🔴 **Rosso:** Sei in ritardo di oltre il 10%.
  * 👑 **Gold Effetto Shimmer:** Attivato al raggiungimento del 100% del traguardo!
* **Stime e Proiezioni:** Visualizzazione della proiezione chilometrica a fine anno, calcolo dei chilometri settimanali necessari e stima della data esatta di arrivo al traguardo basata sul passo attuale.
* **Contatori Storici:** Tracciamento dei chilometri totali percorsi da sempre, traduzione della distanza in "Giri del Mondo" (basati sulla circonferenza equatoriale di 40.075 km) e individuazione dell'anno con la migliore media oraria complessiva.

### 📅 Diario & Archivio Storico YTD
* **Visualizzazione Flessibile:** Monitora le attività dell'anno in corso (Diario) o degli anni passati (Archivio) filtrando e raggruppando i dati per:
  * Singole **Attività** (con dettagli su velocità media, tempo, dislivello, cadenza e link diretto all'attività Strava).
  * Riepiloghi aggregati per **Mese**.
  * Riepiloghi aggregati per **Settimana** (da lunedì a domenica).
* **Confronto Omogeneo YTD:** L'archivio mostra le statistiche degli anni passati calcolate esattamente *fino al giorno dell'anno corrente* (Year-To-Date), permettendo un confronto reale sul tuo stato di forma rispetto al passato.

### 🏁 La Sfida
* Il target annuale è suddiviso sui giorni effettivi dell'anno (365 o 366): ogni riga ha una quota proporzionale ai giorni che contiene. Le settimane a cavallo d'anno vengono tagliate al 1° gennaio e al 31 dicembre.
* Visualizzazione tabellare delle settimane (lunedì-domenica) passate e di quella corrente con indicazione dei chilometri fatti e del delta (positivo o negativo) rispetto alla quota richiesta.

### 🏆 Ranking & Record Storici
* **Classifiche Interannuali:** Classifica tutti gli anni registrati in base a 4 metriche selezionabili: *Distanza Totale*, *Media Ponderata*, *Media Semplice* o *Dislivello Totale* (calcolato dal 2019 in poi).
* **Il Muro dei Record:** pagina dedicata ai primati di sempre, con un menu a tendina fisso per scegliere la categoria (l'ultima scelta viene ricordata): **Distanza, Velocità, Tempo, Dislivello, Cadenza, Costanza, Curiosità**.
  * Ogni record mostra il miglior risultato; un tocco apre la finestra con la **Top 5**.
  * Per i record legati a una singola attività ogni voce della Top 5 ha il tasto **STRAVA** per aprire l'uscita corrispondente (app di Strava, con ripiego sul sito).
  * Giro più lungo, uscite ≥100 e ≥150 km (con elenco consultabile), migliori medie per fascia di distanza, uscita più lunga, più dislivello, densità di salita (m D+/km su uscite ≥20 km), cadenze medie più alte.
  * Settimana, mese e anno con più km, ore in sella, dislivello o uscite; massimo di km in 7 giorni mobili e in 4 giorni.
  * Striscia massima e attuale di settimane consecutive in sella, giorno della settimana e mese dell'anno più pedalati, medie storiche.

### 💾 Sicurezza e Portabilità dei Dati
* **Integrazione Strava:** Connessione sicura tramite OAuth2. Il *Client Secret* viene richiesto al primo accesso e salvato esclusivamente all'interno del browser dell'utente (nessun server di terze parti memorizza le tue chiavi).
* **Manutenzione Dati:** Possibilità di inserire, modificare (con annullamento) o eliminare attività manualmente.
* **Risincronizzazione:** il tasto *Risincronizza ultimi 60 giorni* riscarica le attività recenti da Strava, aggiornando quelle già presenti (la chiave è `strava_id`) e proponendo, dopo conferma, la rimozione di quelle cancellate su Strava.
* **Backup Totale:** Funzioni native per esportare l'intero database storico in formato `JSON` e reimportarlo su qualsiasi dispositivo.
* **Stampa Report:** Generazione al volo di una pagina di riepilogo annuale stampabile o salvabile direttamente in `PDF` con grafiche pulite e tabelle dettagliate.

---

## 🛠️ Stack Tecnologico & Design

L'applicazione è contenuta interamente in un **unico file HTML standalone**, garantendo una velocità di caricamento istantanea e zero dipendenze lato server:

* **Frontend:** HTML5, CSS3 nativo (variabili CSS, modalità Dark/Light automatica in base alle impostazioni di sistema, layout responsive specifico per smartphone e supporto per i margini della *Safe Area* dei dispositivi iOS/Android).
* **Tipografia:** Caratteri d'impatto e moderni (*Outfit* per i testi e le metriche, *Lobster* per il brand dell'header) caricati tramite Google Fonts.
* **Logica:** JavaScript puro (ES6) senza framework esterni.
* **Storage:** Utilizzo intensivo del `localStorage` del browser per la persistenza dei dati e delle sessioni del token Strava.

---

## 🚀 Installazione e Configurazione

Essendo una PWA ospitata su GitHub Pages, Bainzuretta non richiede installazione tradizionale ed è pronta all'uso.

### Utilizzo Immediato
1. Apri il browser del tuo smartphone e naviga su: **`https://<il-tuo-username>.github.io/bainzuretta/`**
2. Se usi iOS (Safari), premi l'icona di condivisione e seleziona **"Aggiungi alla schermata Home"**. Se usi Android (Chrome), seleziona **"Installa applicazione"** dal menu dei tre puntini.
3. Avvia Bainzuretta direttamente dalla schermata Home come una normale applicazione nativa a tutto schermo.

### Collegamento a Strava
1. Nella scheda *Home*, clicca su **CONNETTI CON STRAVA**.
2. Verrà richiesto il tuo **Client Secret** personale. Se non lo hai, puoi recuperarlo gratuitamente accedendo al tuo profilo Strava da desktop sotto la sezione `Impostazioni -> I miei moduli API`.
3. Autorizza l'applicazione: Bainzuretta importerà istantaneamente tutte le tue attività ciclistiche passate e configurerà la sincronizzazione per quelle future.

---

## 📂 Struttura dei Dati JSON

Il file di backup generato o accettato dall'applicazione presenta la seguente struttura per ogni singola attività:

```json
[
  {
    "id": 1719836400000,
    "strava_id": 1122334455,
    "data": "2026-07-01T08:30:00Z",
    "distanza": 64.50,
    "tempo": 2.2536,
    "media": 28.62,
    "nome": "Giro del Mercoledì in relax",
    "dislivello": 450,
    "cadenza": 84
  }
]
