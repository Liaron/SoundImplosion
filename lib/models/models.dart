import 'package:flutter/foundation.dart';

// Definisce lo stato di una prenotazione
enum BookingStatus { inElaborazione, confermata, annullata, sospesa, superata }

class AppUser {
  final String uid;
  final String nickname;
  final List<String> gruppi; // ID dei gruppi
  final List<String> amici; // UID degli amici
  final Map<String, dynamic> preferenze;
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
      // Salva la lista di gruppi come una mappa, più robusto per Firebase
      'gruppi': { for (var id in gruppi) id : true },
      'amici': { for (var id in amici) id : true },
      'preferenze': preferenze,
      'strumenti_list': strumentiList,
      'profile_image_url': profileImageUrl,
    };
  }

  factory AppUser.fromMap(String uid, Map<dynamic, dynamic> map) {
    // Helper robusto per parsare liste da Firebase
    List<T> _parseList<T>(dynamic value) {
      if (value == null) return [];
      if (value is List) return List<T>.from(value.where((e) => e != null));
      if (value is Map) return List<T>.from(value.keys.where((e) => e != null));
      return [];
    }

    List<Map<String, dynamic>> _parseStrumenti(dynamic value) {
        if (value == null) return [];
        final list = <Map<String, dynamic>>[];
        if (value is List) {
          for (final item in value) {
            if (item is Map) list.add(Map<String, dynamic>.from(item));
          }
        } else if (value is Map) {
          for (final item in value.values) {
            if (item is Map) list.add(Map<String, dynamic>.from(item));
          }
        }
        return list;
    }

    return AppUser(
      uid: uid,
      nickname: map['nickname'] ?? uid,
      gruppi: _parseList<String>(map['gruppi']),
      amici: _parseList<String>(map['amici']),
      preferenze: map['preferenze'] != null
          ? Map<String, dynamic>.from(map['preferenze'] as Map)
          : const {},
      strumentiList: _parseStrumenti(map['strumenti_list']),
      profileImageUrl: map['profile_image_url'] as String?,
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
  final String? creatorNickname; // Aggiunto per coerenza

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
    this.creatorNickname,
  });

  Map<String, dynamic> toMap() {
    return {
      'creator_id': creatorId,
      'creator_nickname': creatorNickname,
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

  factory Jam.fromMap(String id, Map<String, dynamic> map) {
    return Jam(
      id: id,
      creatorId: map['creator_id'] as String,
      groupId: map['group_id'] as String?,
      data: map['data'] as String,
      oraInizio: map['ora_inizio'] as String,
      oraFine: map['ora_fine'] as String,
      personePresenti: map['persone_presenti'] as int,
      personeRichieste: map['persone_richieste'] as int,
      descrizione: map['descrizione'] as String,
      pagamento: map['pagamento'] as String,
      attrezzatura: map['attrezzatura'] as String,
      creatorNickname: map['creator_nickname'] as String?,
    );
  }
}
