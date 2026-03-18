# SoundImplosion Roadmap

## Sprint 1
Obiettivo: stabilita, sicurezza, osservabilita
Stato: completato

- Integrare Firebase Crashlytics.
  Priorita: alta
  Stima: bassa
  Dipendenze: nessuna
- Integrare analytics sugli eventi chiave.
  Eventi: login, signup, booking, create group, invite group, create jam
  Priorita: alta
  Stima: bassa
  Dipendenze: nessuna
- Hardening cambio email/password con re-authentication.
  Priorita: alta
  Stima: media
  Dipendenze: auth attuale
- Spostare su backend trusted i flussi piu sensibili.
  Ambiti: inviti gruppo, cleanup account, trigger notifiche, controlli critici
  Priorita: alta
  Stima: alta
  Dipendenze: Firebase Functions gia attive
- Ripulire e documentare regole RTDB.
  Priorita: alta
  Stima: media
  Dipendenze: revisione flussi reali
- Aggiungere test integrazione sui flussi auth, gruppi e notifiche.
  Priorita: media
  Stima: media
  Dipendenze: stabilizzazione API repository

## Sprint 2
Obiettivo: UX prenotazioni e notifiche
Stato: completato

- Navigazione prenotazioni con selettore rapido settimanale e selettore data dedicato.
  UI: strip dei prossimi giorni, date picker e griglia slot
  Priorita: alta
  Stima: alta
  Dipendenze: modello slot esistente
- Migliorare la schermata slot con stati visivi piu chiari.
  Stati: libero, occupato, disabilitato, jam
  Priorita: alta
  Stima: media
  Dipendenze: nessuna
- Deep link dalle notifiche.
  Obiettivo: aprire direttamente booking, gruppo o jam corretti
  Priorita: alta
  Stima: media
  Dipendenze: notifiche gia attive
- Preferenze notifiche per categoria.
  Categorie: gruppi, jam, prenotazioni, sistema
  Priorita: media
  Stima: media
  Dipendenze: pagina impostazioni gia presente
- Badge notifiche e unread coerenti in UI.
  Priorita: media
  Stima: bassa
  Dipendenze: repository notifiche
- Reminder prenotazioni piu precisi.
  Ambiti: modifica, cancellazione, ri-programmazione edge case
  Priorita: media
  Stima: media
  Dipendenze: reminder locali gia presenti

## Sprint 3
Obiettivo: profilo, gruppi, discovery
Stato: completato

- Profilo utente esteso.
  Campi: bio, strumenti, generi, livello, citta, disponibilita
  Priorita: alta
  Stima: media
  Dipendenze: modello utente
- Rendere citta e preferenze usabili nella ricerca.
  Priorita: alta
  Stima: media
  Dipendenze: profilo esteso
- Discovery utenti.
  Filtri: username, citta, strumento, genere
  Priorita: media
  Stima: alta
  Dipendenze: indicizzazione DB
- Gestione inviti gruppo completa.
  Ambiti: revoca invito, scadenza, pending nella UI gruppo, storico
  Priorita: alta
  Stima: media
  Dipendenze: flusso inviti attuale
- Pagina gruppo piu ricca.
  Ambiti: pending invites, ruoli, note, attivita recenti
  Priorita: media
  Stima: media
  Dipendenze: inviti completi
- Migliorare UX jam.
  Ambiti: stato partecipazione, membri confermati, maggior contesto
  Priorita: media
  Stima: media
  Dipendenze: gruppi e profili

## Ordine Consigliato

1. Crashlytics e analytics
2. Re-auth e hardening auth
3. Deep link notifiche
4. Calendario prenotazioni
5. Inviti gruppo completi
6. Profilo esteso e discovery
