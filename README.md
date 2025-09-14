🗓️ **Turni**

Turni è un’applicazione per la gestione e distribuzione dei turni di lavoro in modo digitale, trasparente e scalabile.  
L’obiettivo è sostituire processi manuali e spesso caotici con un sistema rapido, chiaro e condiviso tra dipendenti e responsabili.

⸻

📝 **Descrizione**

Ogni organizzazione che gestisce turni (una pizzeria con i rider per le consegne, un ristorante con i camerieri, un negozio con gli addetti, ecc.) affronta lo stesso problema: raccogliere le disponibilità dei lavoratori e distribuire i turni rispettando regole di equità, priorità o preferenze.

Turni nasce per semplificare questo processo:  
- I **dipendenti** inseriscono le proprie disponibilità dall’app.  
- Il **responsabile** (boss, manager, capo turno) visualizza una panoramica di tutte le disponibilità e assegna i turni.  
- Le regole di distribuzione possono essere:  
  - Casualità guidata da algoritmo: una selezione casuale ma controllata, che evita squilibri estremi (es. un dipendente escluso per troppe settimane di fila).  
  - Priorità per frequenza: chi garantisce più disponibilità ottiene precedenza.  
  - Decisione manuale del **responsabile**: il capo decide direttamente, con trasparenza sul criterio applicato.

In questo modo l’app garantisce un processo:  
- **Trasparente**: tutti possono vedere lo storico delle selezioni e i criteri applicati.  
- **Equo**: le regole sono condivise e non dipendono da favoritismi.  
- **Scalabile**: funziona sia per una piccola pizzeria che per una catena di negozi.

⸻

✨ **Funzionalità**

**Autenticazione**  
- Accesso con email e password  
- Accesso rapido tramite Google  

**Dipendenti**  
- Inserimento e modifica delle proprie disponibilità  
- Visualizzazione dei propri turni assegnati e dello storico  

**Responsabili**  
- Panoramica di tutte le disponibilità  
- Assegnazione turni in base alle regole definite (casualità controllata, priorità, scelta manuale)  

**Storico**  
- Registro dei turni passati, con criteri applicati per la selezione

⸻

🛠️ **Tecnologie**

- **Flutter** → interfaccia cross-platform (Web, Android, iOS, Desktop)  
- **Supabase** → autenticazione e database Postgres con Row Level Security  
- **Dart** → linguaggio principale dell’app

⸻

🌍 **Esempio pratico**

In una pizzeria:  
- I rider inseriscono i giorni in cui possono lavorare.  
- Il responsabile visualizza tutte le disponibilità e assegna i turni.  
- Se ci sono troppi rider disponibili per lo stesso giorno:  
  - l’applicazione applica un **algoritmo equo di selezione**,  
  - oppure dà la possibilità al responsabile di decidere manualmente.  
- I rider possono sempre consultare lo **storico** e capire perché sono stati selezionati o meno.

⸻

🚀 **Stato del progetto**

Attualmente è in fase di sviluppo attivo come MVP (Minimum Viable Product), con focus sulla gestione delle disponibilità e sulla panoramica boss.  
Prossimi passi:  
- Estensione delle regole di distribuzione  
- Test su dispositivi Android/iOS reali  
- Rilascio sugli store ufficiali