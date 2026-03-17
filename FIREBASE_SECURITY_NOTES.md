# Firebase Security Notes

## Stato attuale

L'app usa una combinazione di:
- client Flutter
- Firebase Realtime Database rules
- Cloud Functions come backend trusted

## Flussi gia spostati su backend trusted

- Cleanup dati utente al delete su Firebase Authentication
- Invio push remote per `user_notifications`
- Invito utente a un gruppo tramite Callable Function `inviteUserToGroup`
- Accept invito gruppo tramite Callable Function `acceptGroupInvite`
- Reject invito gruppo tramite Callable Function `rejectGroupInvite`

## Flussi ancora principalmente client-driven

- Creazione e aggiornamento booking
- Creazione e aggiornamento jam
- Parte della gestione notifiche applicative

## Motivazione

I flussi con maggiore rischio di abuso o race condition dovrebbero vivere nel backend trusted.
Gli inviti gruppo sono stati spostati su Function per centralizzare:
- ricerca utente
- verifica permessi owner/admin
- creazione invito pendente
- creazione notifica collegata

## Deploy richiesti

Per attivare le modifiche lato backend:

```powershell
cd c:\Users\aless\AndroidStudioProjects\SoundImplosion
firebase deploy --only functions
```

Per attivare le modifiche lato database:

- pubblicare [`database.rules.json`](c:/Users/aless/AndroidStudioProjects/SoundImplosion/database.rules.json) su Firebase Realtime Database

## Prossimi candidati da spostare su backend

- booking sensibili con side effects multipli
- jam con side effects multipli
- cleanup amministrativo utenti
