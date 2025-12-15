
// Definisce lo stato di una prenotazione
enum BookingStatus { vuoto, inElaborazione, confermata, annullata, sospesa, superata }

class AppUser {
  final String uid;
  final String nickname;
  final String strumento;
  final String livelloAbilita;
  final List<String> gruppi; // ID dei gruppi
  final List<String> amici; // UID degli amici
  final Map<String, dynamic> preferenze;

  AppUser({
    required this.uid,
    required this.nickname,
    required this.strumento,
    required this.livelloAbilita,
    this.gruppi = const [],
    this.amici = const [],
    this.preferenze = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'strumento': strumento,
      'livello': livelloAbilita,
      'gruppi': gruppi.asMap(), // Firebase gestisce meglio le mappe/liste indicizzate
      'amici': amici.asMap(),
      'preferenze': preferenze,
    };
  }
}

class Booking {
  String? id;
  final String userId;
  final String? groupId; // Opzionale
  final String data; // Formato YYYY-MM-DD
  final String oraInizio;
  final String oraFine;
  final int numeroUtenti;
  final String attrezzatura;
  final BookingStatus stato;

  Booking({
    this.id,
    required this.userId,
    this.groupId,
    required this.data,
    required this.oraInizio,
    required this.oraFine,
    required this.numeroUtenti,
    required this.attrezzatura,
    this.stato = BookingStatus.inElaborazione,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'group_id': groupId,
      'data': data,
      'ora_inizio': oraInizio,
      'ora_fine': oraFine,
      'numero_utenti': numeroUtenti,
      'attrezzatura': attrezzatura,
      'stato': stato.name, // Salva come stringa (es. "confermata")
    };
  }
}

class Jam {
  String? id;
  final String creatorId;
  final String data;
  final String oraInizio;
  final String oraFine;
  final int missingCount;
  // Mappa Ruolo -> Livello (es. {"Chitarrista": "Avanzato"})
  final Map<String, String> ruoliMancanti;

  Jam({
    this.id,
    required this.creatorId,
    required this.data,
    required this.oraInizio,
    required this.oraFine,
    required this.missingCount,
    required this.ruoliMancanti,
  });

  Map<String, dynamic> toMap() {
    return {
      'creator_id': creatorId,
      'data': data,
      'ora_inizio': oraInizio,
      'ora_fine': oraFine,
      'missing_count': missingCount,
      'ruoli_mancanti': ruoliMancanti,
    };
  }
}
