class PublicSiteContent {
  // ---------------------------------------------------------
  // BRAND & FOOTER
  // ---------------------------------------------------------
  static const String brandName = 'SoundImplosion';
  static const String brandTagline = 'Sale prove professionali per band e solisti';
  static const String footerText = 'SoundImplosion | Prenotazioni, jam session e sale prove. \nTutti i diritti riservati.';

  // ---------------------------------------------------------
  // CONTATTI E INDIRIZZO
  // ---------------------------------------------------------
  static const String footerPhone = '+39 02 1234 5678';
  static const String footerEmail = 'info@soundimplosion.it';
  static const String footerAddress = 'Via della Musica, 42 - Milano, MI 20100';
  static const String footerHours = 'Aperto: Lunedì - Domenica, 9:00 - 23:00';

  static const List<Map<String, String>> footerLinks = [
    {
      'label': 'Contatti',
      'url': '/contact',
    },
  ];

  // ---------------------------------------------------------
  // HOME - HERO SECTION
  // ---------------------------------------------------------
  static const String heroBadge = 'Il tuo spazio per suonare e creare';
  static const String heroTitle = 'La tua musica merita il suono e lo spazio migliore.';
  static const String heroDescription = 
      'Scopri le nostre sale prove progettate per musicisti, band e produttori. Strumentazione backline di altissima qualità, acustica su misura e un ambiente pronto a spingere la tua creatività al massimo.';
  
  static const String heroPrimaryButton = 'Accedi e Prenota';
  static const String heroSecondaryButton = 'Vedi le Tariffe';
  
  // Immagine principale della Home
  // Inserisci qui il percorso della tua immagine (es: 'assets/images/hero_room.jpg')
  static const String heroImagePath = ''; 

  // ---------------------------------------------------------
  // HOME - PUNTI DI FORZA (HIGHLIGHTS)
  // ---------------------------------------------------------
  static const String highlight1Title = 'Strumentazione Top';
  static const String highlight1Description = 'Amplificatori valvolari, batterie professionali e impianti voce sempre revisionati.';
  
  static const String highlight2Title = 'Acustica Curata';
  static const String highlight2Description = 'Pannelli fonoassorbenti, bass traps e diffusori per garantire una resa sonora pulita.';
  
  static const String highlight3Title = 'Servizi Inclusi';
  static const String highlight3Description = 'Climatizzazione autonoma, Wi-Fi veloce, area relax e zero pensieri.';

  // ---------------------------------------------------------
  // HOME - STATISTICHE
  // ---------------------------------------------------------
  static const String stat1Value = '4';
  static const String stat1Label = 'Sale Prove Attrezzate';
  
  static const String stat2Value = 'Aperto 7/7';
  static const String stat2Label = 'Anche in orari serali e festivi';
  
  static const String stat3Value = '100+';
  static const String stat3Label = 'Band residenti soddisfatte';

  // ---------------------------------------------------------
  // HOME - COME FUNZIONA (WORKFLOW)
  // ---------------------------------------------------------
  static const String workflowEyebrow = 'Come funziona';
  static const String workflowTitle = 'Dal divano al palco in tre semplici passaggi.';
  static const String workflowDescription = 'Prenotare la tua prossima prova è diventato istantaneo. Nessun giro di messaggi o incomprensioni, fai tutto online.';
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
  static const String aboutEyebrow = 'Chi siamo';
  static const String aboutTitle = 'Gestito da musicisti, per i musicisti.';
  static const String aboutDescription = 
      'SoundImplosion nasce dall\'esigenza di avere un posto affidabile, comodo e professionale dove fare musica. Vogliamo eliminare tutta la frustrazione della prenotazione per lasciarti solo il piacere di suonare.';
  static const String aboutActionButton = 'Unisciti alla community';

  static const String story1Title = 'La nostra missione';
  static const String story1Description = 'Fornire uno spazio dove la creatività possa scorrere senza intoppi tecnici o problemi acustici.';
  
  static const String story2Title = 'La community (Jam)';
  static const String story2Description = 'Non siamo solo un affitto stanze. Tramite le Jam pubbliche puoi conoscere altri artisti della zona e far nascere nuovi progetti.';

  static const String value1Title = 'Passione';
  static const String value1Description = 'Viviamo la musica in prima persona, per questo sappiamo cosa ti serve per provare al meglio.';
  
  static const String value2Title = 'Professionalità';
  static const String value2Description = 'Strumentazione tenuta maniacalmente e staff sempre pronto a intervenire o consigliarti.';
  
  static const String value3Title = 'Punto di Incontro';
  static const String value3Description = 'Oltre alla sala, troverai una comoda area relax, un bar e altre band con cui confrontarti.';

  // ---------------------------------------------------------
  // TARIFFE E PREZZI (PRICING)
  // ---------------------------------------------------------
  static const String pricingEyebrow = 'Tariffe';
  static const String pricingTitle = 'Prezzi chiari e trasparenti per ogni esigenza.';
  static const String pricingDescription = 'Dalla tariffa oraria singola agli abbonamenti mensili per band residenti. Scopri l\'opzione migliore per il tuo gruppo.';
  static const String pricingActionButton = 'Accedi e prenota';

  // Puoi configurare i piani tariffari qui
  static const List<Map<String, dynamic>> pricingPlans = [
    {
      'title': 'Orario Singolo',
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
      'price': '190€',
      'period': '/ mese',
      'description': 'L\'opzione più scelta dalle band fisse per avere una sala garantita.',
      'popular': true,
      'features': [
        '4 sessioni da 3 ore garantite',
        'Sconto su ore extra',
        'Armadietto riservato',
      ],
      'cta': 'Richiedi disponibilità',
    },
    {
      'title': 'Mezza Giornata',
      'price': '60€',
      'period': '/ 4 ore',
      'description': 'Un pacchetto orario lungo per chi organizza pre-produzioni e date live.',
      'popular': false,
      'features': [
        'Ideale per pre-produzioni',
        'Sala grande (40mq)',
        'Accesso area relax',
      ],
      'cta': 'Prenota blocco',
    }
  ];

  static const List<Map<String, String>> pricingFaqs = [
    {
      'question': 'Come funziona la cancellazione?',
      'answer': 'Puoi cancellare o spostare la tua prenotazione gratuitamente fino a 24 ore prima dell\'inizio del turno.',
    },
    {
      'question': 'La strumentazione è inclusa?',
      'answer': 'Sì, tutte le sale hanno batteria (piatti esclusi), 2 ampli chitarra, 1 ampli basso e impianto voce con 2 microfoni.',
    },
    {
      'question': 'Come funziona l\'abbonamento mensile?',
      'answer': 'Dà diritto a 4 sessioni in giorni/orari fissi, oltre a sconti su ore aggiuntive e un armadietto dedicato in struttura.',
    },
  ];
}
