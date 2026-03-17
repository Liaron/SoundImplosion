**Admin Setup**

Per promuovere un utente ad admin e rendere sicuro il pannello di moderazione jam, usa questa procedura.

**1. Recupera l'UID**

1. Apri Firebase Console.
2. Vai in Authentication.
3. Apri la lista utenti.
4. Copia l'UID dell'utente da promuovere.

**2. Assegna il ruolo admin**

Nel Realtime Database, sotto `users`, trova il nodo con chiave uguale all'UID dell'utente.

Esempio:

```json
{
  "users": {
    "abc123XYZ": {
      "nickname": "Mario",
      "role": "admin"
    }
  }
}
```

L'UID non va incollato nel valore di `role`.
L'UID deve essere il nome del nodo utente sotto `users`.

**3. Applica le regole database**

Apri Realtime Database, scheda Rules, e incolla il contenuto di [database.rules.json](database.rules.json).

Queste regole fanno queste cose importanti:

1. impediscono a un utente normale di assegnarsi da solo `role = admin`
2. permettono solo agli admin di pubblicare o rifiutare jam modificando lo stato
3. permettono solo agli admin di scrivere nel feed
4. limitano le prenotazioni root ai soli proprietari o admin
5. limitano la manipolazione degli slot agli utenti che stanno occupando o liberando i propri slot, oltre agli admin
6. abilitano i gruppi, gli inviti membri e la visibilità delle prenotazioni di gruppo
7. abilitano la ricerca utente per nickname tramite `user_search_index`

**4. Ricarica la sessione dell'utente admin**

Dopo aver assegnato `role = admin`, l'utente deve:

1. chiudere e riaprire l'app, oppure
2. fare logout e login

Così il profilo viene riletto e nel drawer compare la voce `Admin`.

**5. Operazioni consentite per ruolo**

Utente normale:

1. leggere le proprie informazioni profilo
2. modificare il proprio profilo ma non il campo `role`
3. creare, modificare e cancellare solo le proprie prenotazioni
4. leggere le proprie prenotazioni e quelle dei gruppi a cui appartiene
5. creare jam in stato `inElaborazione`
6. modificare o cancellare solo le proprie jam
7. leggere jam pubblicate e le proprie jam non ancora approvate
8. partecipare o uscire dalle jam pubblicate tramite i propri nodi `user_joined_jams`
9. creare gruppi e invitare membri nei gruppi di cui e proprietario usando il nickname esatto

Admin:

1. leggere e modificare i profili utente, incluso `role`
2. approvare, annullare e riprogrammare jam
3. approvare, annullare e riprogrammare prenotazioni
4. scrivere nel feed
5. leggere e modificare prenotazioni e nodi utente collegati
6. intervenire sugli slot per approvazioni, rifiuti o riprogrammazioni
7. vedere tutti i gruppi e invitare membri anche nei gruppi non posseduti

**6. Limiti attuali delle regole**

Le regole ora sono più puntuali per profili, ricerca utente, jam, feed, prenotazioni, gruppi, slot e notifiche legate alle prenotazioni.

Nota operativa: la ricerca utenti per invito gruppo usa il nodo `user_search_index`.
I nuovi utenti vengono indicizzati automaticamente.
Gli utenti esistenti verranno trovati dal search index dopo che il loro profilo sara aggiornato almeno una volta con la versione nuova dell'app.

Per una sicurezza completa servirebbe spostare booking, approvazioni e gestione slot in Cloud Functions o altro backend trusted.
