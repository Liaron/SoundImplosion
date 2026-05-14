class PublicSiteContent {
  // ---------------------------------------------------------
  // BRAND & FOOTER
  // ---------------------------------------------------------
  static const String brandName = 'SoundImplosion';
  static const String brandTagline =
      'Sale prove professionali per band, solisti e podcaster';
  static const String footerText =
      'SoundImplosion | Sale prove, jam session e podcast.';
  static const String footerPoweredByText = 'Powered by Liaron';
  static String get footerPoweredBy => footerPoweredByText;

  // ---------------------------------------------------------
  // CONTATTI E INDIRIZZO
  // ---------------------------------------------------------
  static const String footerPhone = '+39 379 209 3805';
  static const String footerEmail = '';
  static const String footerAddress =
      'Via delle palme, 5 - Bracciano, RM 00062\n Sotto il bar Lo Stregatto, rampa sulla destra';
  static const String footerHours = 'Aperto: Lunedì - Sabato, 10:00 - 00:00';

  static const List<Map<String, String>> footerLinks = [
    {'label': 'Contatti', 'url': '/contact'},
  ];

  static const String contactEyebrow = 'Contatti';
  static const String contactTitle = 'Parliamone prima di accendere gli ampli.';
  static const List<String> contactDescription = [
    'Non ci conosci? Esplora le nostre pagine social per scoprire chi siamo e cosa facciamo.',
    'Hai domande sulle sale o la strumentazione? **Siamo qui per te!**',
    'Contattaci su __whatsapp__ per ricevere maggiori informazioni.\n**Siamo pronti ad aiutarti!**',
    'Accettiamo le prenotazioni __solo tramite il sistema online o tramite app__, scaricala o fai accesso tramite browser per prenotare la tua prossima prova.',
  ];
  static const String contactActionButton = 'Accedi e prenota';
  static const String contactInfoTitle = 'Dove trovarci';
  static const String contactInfoDescription =
      'Siamo a Bracciano 2, sotto il bar Lo Stregatto. Rampa sulla destra, in fondo al corridoio sulla destra. Puoi parcheggiare facilmente su strada nelle vicinanze. Ti aspettiamo!';

  static const List<Map<String, String>> contactPhones = [
    {
      'label': 'WhatsApp',
      'value': '+39 379 209 3805',
      'url': 'tel:+393792093805',
    },
  ];
  static const List<Map<String, String>> contactEmails = [
    {
      'label': 'Email',
      'value': 'info@soundimplosion.it',
      'url': 'mailto:info@soundimplosion.it',
    },
  ];

  // Lascia vuota questa lista finché non hai un'email pubblica da mostrare.
  static const List<Map<String, String>> contactSocials = [
    {
      'label': 'Instagram',
      'value': 'sound_implosion',
      'url': 'https://www.instagram.com/sound_implosion',
    },
    {
      'label': 'TikTok',
      'value': '@soundimplosion',
      'url': 'https://www.tiktok.com/@sound_implosion',
    },
  ];

  // ---------------------------------------------------------
  // HOME - HERO SECTION
  // ---------------------------------------------------------
  static const String heroBadge = 'Il tuo spazio per suonare e creare';
  static const String heroTitle =
      'La tua musica merita il suono e lo spazio migliore.';
  static const String heroDescription =
      'Scopri le nostre sale prove progettate per musicisti, band, produttori e podcaster. Strumentazione backline di altissima qualità, acustica su misura e un ambiente pronto a spingere la tua creatività al massimo.';

  static const String heroPrimaryButton = 'Accedi e Prenota';
  static const String heroSecondaryButton = 'Vedi le Tariffe';

  static const String heroDownloadEyebrow = 'App Android';
  static const String heroDownloadTitle =
      'Scarica l\'APK e prenota dal telefono';
  static const String heroDownloadDescription =
      'Installa l\'app Android per controllare disponibilita, gestire le prenotazioni e avere SoundImplosion sempre a portata di mano.';
  static const List<String> heroDownloadHighlights = [
    'Installazione manuale per dispositivi Android',
    'Accesso rapido a prenotazioni e disponibilita',
    'Esperienza ottimizzata per smartphone',
  ];
  static const String heroDownloadPrimaryButton = 'Scarica APK';
  static const String heroDownloadSecondaryText =
      'Download diretto dal sito, compatibile con Android';
  static const String heroDownloadUrl = '/soundimplosion-android.apk';

  // Immagine principale della Home
  // Inserisci qui il percorso della tua immagine (es: 'assets/images/hero_room.jpg')
  static const String heroImagePath = '';

  // ---------------------------------------------------------
  // HOME - PUNTI DI FORZA (HIGHLIGHTS)
  // ---------------------------------------------------------
  static const String highlight1Title = 'Strumentazione disponibile';
  static const String highlight1Description =
      'Amplificatori valvolari, batterie professionali e impianti voce sempre revisionati.';

  static const String highlight2Title = 'Acustica';
  static const String highlight2Description =
      'Pannelli fonoassorbenti e diffusori per garantire una resa sonora pulita.';

  static const String highlight3Title = 'Servizi Inclusi';
  static const String highlight3Description =
      'Wi-Fi, area relax e zero pensieri.';

  // ---------------------------------------------------------
  // HOME - STATISTICHE
  // ---------------------------------------------------------
  static const String stat1Value = '40mq';
  static const String stat1Label = 'Sala Prove Attrezzata';

  static const String stat2Value = 'Aperto 6/7';
  static const String stat2Label = 'Anche in orari serali';

  static const String stat3Value = 'E anche';
  static const String stat3Label = 'Sala registrazione podcast e live streaming';

  // ---------------------------------------------------------
  // HOME - COME FUNZIONA (WORKFLOW)
  // ---------------------------------------------------------
  static const String workflowEyebrow = 'Come funziona';
  static const String workflowTitle =
      'Dal divano al palco in tre semplici passaggi.';
  static const String workflowDescription =
      'Prenotare la tua prossima prova è diventato istantaneo. Nessun giro di messaggi o incomprensioni, fai tutto online.';
  static const String workflowActionLabel = 'Inizia subito';

  static const List<String> workflowSteps = [
    'Scegli la sala più adatta alle tue esigenze e strumentazione',
    'Seleziona l\'orario disponibile direttamente dal calendario',
    'Aggiungi i membri della tua band per avvisarli in automatico',
    'Vieni in sede, accendi gli ampli e pensa solo a suonare',
  ];

  // Immagine di accompagnamento per la sezione "Come Funziona"
  static const String workflowImagePath = '';

  // ---------------------------------------------------------
  // CHI SIAMO (ABOUT)
  // ---------------------------------------------------------
  // Nei testi descrittivi puoi usare **grassetto**, *corsivo* e __sottolineato__.
  static const String aboutEyebrow = 'Chi siamo';
  static const String aboutTitle =
      'Uno spazio nato da amicizia, musica e creatività.';
  static const String aboutDescription =
      'SoundImplosion è una sala prove nata dal sogno condiviso di '
      'Federico Millimaci, Marco Chima ed Emanuele Soria, con la '
      'collaborazione di Lorenzo Pontecorvi, Andrea Marchi, Alessio Chima '
      "e Daniele Chima. È un luogo nato dall'amicizia, dalla passione "
      'condivisa e dalla volontà di costruire uno spazio reale da vivere, '
      'creare e condividere insieme.';
  static const String aboutActionButton = 'Unisciti alla community';

  static const String story1Title = 'Le nostre radici';
  static const String story1Description =
      'La sala nasce dalla passione per la musica, dalla voglia di creare '
      "uno spazio autentico dedicato agli artisti e dall'unione delle "
      'esperienze maturate da ogni socio nel mondo musicale, tecnico e live. '
      'Ogni competenza raccolta nel tempo ha contribuito alla realizzazione '
      'di un ambiente pensato per musicisti, band, creativi e produzioni '
      'che cercano professionalità, comfort e libertà espressiva.';

  static const String story2Title = 'Creatività a 360 gradi';
  static const String story2Description =
      'Oltre a essere una sala prove musicale in continuo sviluppo, '
      'SoundImplosion è uno spazio dedicato alla creatività a 360 gradi: '
      'produzioni podcast, registrazioni video, contenuti multimediali e '
      'progetti artistici trovano qui un ambiente versatile e in costante '
      'evoluzione. Musica, canto, parole, poesia, immagini e nuove forme di '
      'comunicazione convivono per dare voce alla creatività in tutte le sue '
      'forme.';

  static const String value1Title = 'Aggregazione';
  static const String value1Description =
      'Un luogo dove arte, persone e idee diverse possono incontrarsi.';

  static const String value2Title = 'Espressione';
  static const String value2Description =
      'Uno spazio pensato per dare voce alla creatività in ogni forma.';

  static const String value3Title = 'Sperimentazione';
  static const String value3Description =
      'Un ambiente aperto alla collaborazione e alla nascita di nuovi progetti.';

  // ---------------------------------------------------------
  // TARIFFE E PREZZI (PRICING)
  // ---------------------------------------------------------
  static const String pricingEyebrow = 'Tariffe';
  static const String pricingTitle =
      'Prezzi chiari e trasparenti per ogni esigenza.';
  static const String pricingDescription =
      'Dalla tariffa oraria singola agli abbonamenti mensili per band residenti. Scopri l\'opzione migliore per il tuo gruppo.';
  static const String pricingActionButton = 'Accedi e prenota';

  // Puoi configurare i piani tariffari qui
  static const List<Map<String, dynamic>> pricingPlans = [
    {
      'title': 'Slot Singolo',
      'price': '20€',
      'period': '/ ora',
      'description': 'Per chi vuole provare occasionalmente senza vincoli.',
      'popular': false,
      'features': [
        'Strumentazione base inclusa',
        'Prenotazione web e app istantanea',
        'Cancellazione gratuita (24h)',
      ],
      'cta': 'Prenota un\'ora',
    },
    {
      'title': 'Band Residente (Mensile)',
      'price': '200€',
      'period': '/ mese',
      'description':
          'L\'opzione più scelta dalle band fisse per avere una sala garantita.',
      'popular': true,
      'features': [
        'Tutto ciò che c\'è in "Mezza Giornata"',
        '12 ore',
        'Deposito strumentazione',
      ],
      'cta': 'Richiedi disponibilità',
    },
    {
      'title': 'Mezza Giornata',
      'price': '70€',
      'period': '/ 4 ore',
      'description':
          'Un pacchetto orario lungo per chi organizza pre-produzioni e date live.',
      'popular': false,
      'features': [
        'Tutto ciò che c\'è in "Slot Singolo"',
        'Ideale per pre-produzioni',
        'Sala grande (40mq)',
      ],
      'cta': 'Prenota blocco',
    },
  ];

  static const List<Map<String, String>> pricingFaqs = [
    {
      'question': 'Come funziona la cancellazione?',
      'answer':
          'Puoi cancellare o spostare la tua prenotazione gratuitamente fino a 24 ore prima dell\'inizio del turno.',
    },
    {
      'question': 'La strumentazione è inclusa?',
      'answer':
          'Sì, in parte. La nostra sala registrazione podcast e live streaming dispone di batteria, 2 ampli chitarra, 1 ampli basso e impianto voce con 2 microfoni.',
    },
    {
      'question': 'Come funziona l\'abbonamento mensile?',
      'answer': 'Dà diritto a 12 ore al prezzo di 10',
    },
  ];
}
