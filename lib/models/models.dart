
// Definisce lo stato di una prenotazione
enum BookingStatus { inElaborazione, confermata, annullata, sospesa, superata }

class AppUser {
  final String uid;
  final String nickname;
  final List<String> gruppi; // ID dei gruppi
  final List<String> amici; // UID degli amici
  final Map<String, dynamic> preferenze;
  // Nuova lista strumenti: ogni elemento è { 'nome': String, 'livello': int }
  final List<Map<String, dynamic>> strumentiList; 
  final String? profileImageUrl;

  AppUser({
    required this.uid,
    required this.nickname,
    this.gruppi = const [],
    this.amici = const [],
    this.preferenze = const {},
    this.strumentiList = const [],
    this.profileImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'gruppi': gruppi.asMap(),
      'amici': amici.asMap(),
      'preferenze': preferenze,
      'strumenti_list': strumentiList,
      'profile_image_url': profileImageUrl,
    };
  }

  factory AppUser.fromMap(String uid, Map<dynamic, dynamic> map) {
    return AppUser(
      uid: uid,
      nickname: map['nickname'] ?? '',
      gruppi: map['gruppi'] != null 
          ? (map['gruppi'] as List<dynamic>).map((e) => e.toString()).toList() 
          : [],
      amici: map['amici'] != null
          ? (map['amici'] as List<dynamic>).map((e) => e.toString()).toList()
          : [],
      preferenze: map['preferenze'] != null 
          ? Map<String, dynamic>.from(map['preferenze']) 
          : {},
      strumentiList: map['strumenti_list'] != null
          ? (map['strumenti_list'] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [],
      profileImageUrl: map['profile_image_url'],
    );
  }
}

class Booking {
  String? id;
  final String userId;
  final String? groupId;
  final String data;
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
      'stato': stato.name,
    };
  }
}

class Jam {
  String? id;
  final String creatorId;
  final String? groupId;
  final String data;
  final String oraInizio;
  final String oraFine;
  
  final int personePresenti;
  final int personeRichieste;
  final String descrizione;
  final String pagamento; 
  final String attrezzatura;

  Jam({
    this.id,
    required this.creatorId,
    this.groupId,
    required this.data,
    required this.oraInizio,
    required this.oraFine,
    required this.personePresenti,
    required this.personeRichieste,
    required this.descrizione,
    required this.pagamento,
    required this.attrezzatura,
  });

  Map<String, dynamic> toMap() {
    return {
      'creator_id': creatorId,
      'group_id': groupId,
      'data': data,
      'ora_inizio': oraInizio,
      'ora_fine': oraFine,
      'persone_presenti': personePresenti,
      'persone_richieste': personeRichieste,
      'descrizione': descrizione,
      'pagamento': pagamento,
      'attrezzatura': attrezzatura,
    };
  }
}
