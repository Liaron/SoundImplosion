class EquipmentSheetContent {
  static const String title = 'Scheda tecnica sala';
  static const String subtitle =
      'Sala 8x5 metri, 40 mq, con strumenti musicali e strumentazione tecnica.';
  static const String bookingIntro =
      'Prima di inviare la prenotazione, controlla la dotazione disponibile.';

  static const List<EquipmentSheetSection> sections = [
    EquipmentSheetSection(title: 'Sala', items: ['Sala 8x5 metri, 40 mq']),
    EquipmentSheetSection(
      title: 'Strumenti musicali',
      items: [
        'N1 batteria Mapex Tornado comprendente: '
            'n1 grancassa 20" con pedale, '
            'n2 tom, '
            'n1 floor tom, '
            'n2 piatti Hi-Hat 12", '
            'n1 piatto crash 14", '
            'n1 sgabello, '
            'n1 paio di bacchette Vic Firth, '
            'n1 training pad',
        'N1 tastiera Yamaha PSR473',
        'N1 synth Roland EG101',
        'N2 reggitastiera',
        'N1 chitarra elettrica Eko',
        'N1 stand per chitarra',
        'N1 amplificatore per chitarra Fender Performer 1000',
        'N1 amplificatore per basso Dynacord BS412',
      ],
    ),
    EquipmentSheetSection(
      title: 'Strumentazione tecnica',
      items: [
        'N1 mixer digitale Avid',
        'N1 PC Mac G5 dedicato con schermi',
        'N1 scheda audio Motu Traveler MKIII',
        'N1 mixer Behringer analogico Xenyx 1202 SFX',
        'N1 split cuffie Powerplay Behringer',
        'N1 diffusore audio 12" ZZipp Zzar',
        'N1 diffusore audio 10" Alto TX310',
        'N2 diffusori audio 8" Technosound TA08A',
        'N1 microfono Shure C606 con asta',
        'N1 microfono Proel DM58LC',
        'N2 aste standard per microfono',
        'N2 leggii standard',
        'N1 sgabello Konig & Mayer',
      ],
    ),
    EquipmentSheetSection(
      title: 'Richieste e servizi',
      items: [
        'Qualora ci sia bisogno di attrezzature aggiuntive rispetto '
            'a quelle presenti, è possibile richiederle a noleggio '
            'con prezzi dedicati direttamente a noi.',
        'Mettiamo a disposizione, su richiesta, ulteriore materiale audio, '
            'luci e video compatibilmente con la disponibilità.',
        'Esigenze particolari andranno comunicate in anticipo, '
            'così da poter organizzare tutto al meglio.',
        'È inoltre possibile richiedere servizio di registrazione '
            'in tutte le sue fasi: registrazione, mixaggio e mastering, '
            'concordando il prezzo con trattativa privata dedicata.',
      ],
    ),
  ];
}

class EquipmentSheetSection {
  const EquipmentSheetSection({required this.title, required this.items});

  final String title;
  final List<String> items;
}
