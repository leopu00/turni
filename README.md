🗓️ **Turni**

Turni is an application for managing and distributing work shifts in a digital, transparent, and scalable way.  
The goal is to replace manual and often chaotic processes with a fast, clear system shared between employees and managers.

⸻

📝 **Description**

Every organization that manages shifts (a pizzeria with delivery riders, a restaurant with waiters, a shop with staff, etc.) faces the same problem: collecting workers' availabilities and distributing shifts while respecting fairness rules, priorities, or preferences.

Shifts was created to simplify this process:  
- **Employees** enter their availabilities through the app.  
- The **manager** (boss, supervisor, shift leader) sees an overview of all availabilities and assigns shifts.  
- Distribution rules can be:  
  - Algorithm-guided randomness: a random but controlled selection that avoids extreme imbalances (e.g., an employee being excluded for too many weeks in a row).  
  - Priority by frequency: those who provide more availability get priority.  
  - Manual decision by the **manager**: the boss decides directly, with transparency on the applied criteria.

In this way, the app guarantees a process that is:  
- **Transparent**: everyone can see the history of selections and the criteria used.  
- **Fair**: the rules are shared and do not depend on favoritism.  
- **Scalable**: it works for both a small pizzeria and a retail chain.

⸻

✨ **Features**

**Authentication**  
- Login with email and password  
- Quick login via Google  

**Employees**  
- Enter and edit their own availabilities  
- View their assigned shifts and history  

**Managers**  
- Overview of all availabilities  
- Assign shifts based on defined rules (controlled randomness, priority, manual choice)  

**History**  
- Record of past shifts, with criteria used for selection

⸻

🛠️ **Technologies**

- **Flutter** → cross-platform interface (Web, Android, iOS, Desktop)  
- **Supabase** → authentication and Postgres database with Row Level Security  
- **Dart** → main language of the app

⸻

🌍 **Practical example**

In a pizzeria:  
- Riders enter the days they can work.  
- The manager sees all availabilities and assigns shifts.  
- If too many riders are available on the same day:  
  - the app applies a **fair selection algorithm**,  
  - or allows the manager to decide manually.  
- Riders can always check the **history** and understand why they were selected or not.

⸻

🚀 **Project status**

Currently in active development as an MVP (Minimum Viable Product), focusing on availability management and the boss overview.  
Next steps:  
- Extension of distribution rules  
- Testing on real Android/iOS devices  
- Release on official stores



---ITA---

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