// Definisce lo stato di una prenotazione
enum BookingStatus { inElaborazione, confermata, annullata, sospesa, superata }

enum JamStatus { inElaborazione, pubblicata, annullata, sospesa }

class AppUser {
  final String uid;
  final String nickname;
  final String? email;
  final String? role;
  final List<String> gruppi; // ID dei gruppi
  final List<String> amici; // UID degli amici
  final Map<String, dynamic> preferenze;
  final List<Map<String, dynamic>> strumentiList;
  final String? profileImageUrl;

  AppUser({
    required this.uid,
    required this.nickname,
    this.email,
    this.role = 'user',
    this.gruppi = const [],
    this.amici = const [],
    this.preferenze = const {},
    this.strumentiList = const [],
    this.profileImageUrl,
  });

  bool get isAdmin => role == 'admin';
  String get username => nickname;
  String get city => _generalPreferences['city']?.toString() ?? '';
  String get bio => _profilePreferences['bio']?.toString() ?? '';
  String get skillLevel =>
      _profilePreferences['skill_level']?.toString() ?? 'Non specificato';
  List<String> get genres => _stringListFrom(_profilePreferences['genres']);
  List<String> get availability =>
      _stringListFrom(_profilePreferences['availability']);

  Map<String, dynamic> get _generalPreferences {
    final general = preferenze['general'];
    if (general is Map) {
      return Map<String, dynamic>.from(general);
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> get _profilePreferences {
    final profile = preferenze['profile'];
    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }
    return const <String, dynamic>{};
  }

  static List<String> _stringListFrom(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  Map<String, dynamic> toMap() {
    return {
      'username': nickname,
      'username_lowercase': nickname.toLowerCase(),
      'email': email,
      'email_lowercase': email?.toLowerCase(),
      'role': role ?? 'user',
      // Salva la lista di gruppi come una mappa, più robusto per Firebase
      'gruppi': {for (var id in gruppi) id: true},
      'amici': {for (var id in amici) id: true},
      'preferenze': preferenze,
      'strumenti_list': strumentiList,
      'profile_image_url': profileImageUrl,
    };
  }

  AppUser copyWith({
    String? nickname,
    String? email,
    String? role,
    List<String>? gruppi,
    List<String>? amici,
    Map<String, dynamic>? preferenze,
    List<Map<String, dynamic>>? strumentiList,
    String? profileImageUrl,
  }) {
    return AppUser(
      uid: uid,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      role: role ?? this.role ?? 'user',
      gruppi: gruppi ?? this.gruppi,
      amici: amici ?? this.amici,
      preferenze: preferenze ?? this.preferenze,
      strumentiList: strumentiList ?? this.strumentiList,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  factory AppUser.fromMap(String uid, Map<dynamic, dynamic> map) {
    // Helper robusto per parsare liste da Firebase
    List<T> parseList<T>(dynamic value) {
      if (value == null) return [];
      if (value is List) return List<T>.from(value.where((e) => e != null));
      if (value is Map) return List<T>.from(value.keys.where((e) => e != null));
      return [];
    }

    Map<String, dynamic> parseMap(dynamic value) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return const <String, dynamic>{};
    }

    List<Map<String, dynamic>> parseStrumenti(dynamic value) {
      if (value == null) return [];
      final list = <Map<String, dynamic>>[];

      void addItem(dynamic item) {
        if (item is Map) {
          list.add(Map<String, dynamic>.from(item));
          return;
        }
        final instrumentName = item?.toString().trim() ?? '';
        if (instrumentName.isNotEmpty) {
          list.add({'nome': instrumentName, 'livello': 0});
        }
      }

      if (value is List) {
        for (final item in value) {
          addItem(item);
        }
      } else if (value is Map) {
        for (final item in value.values) {
          addItem(item);
        }
      } else {
        addItem(value);
      }

      return list;
    }

    return AppUser(
      uid: uid,
      nickname: map['username']?.toString().trim().isNotEmpty == true
          ? map['username'].toString()
          : (map['nickname']?.toString().trim().isNotEmpty == true
                ? map['nickname'].toString()
                : uid),
      email: map['email']?.toString(),
      role: map['role']?.toString() ?? 'user',
      gruppi: parseList<String>(map['gruppi']),
      amici: parseList<String>(map['amici']),
      preferenze: parseMap(map['preferenze']),
      strumentiList: parseStrumenti(map['strumenti_list']),
      profileImageUrl: map['profile_image_url']?.toString(),
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

  factory Booking.fromMap(String id, Map<String, dynamic> map) {
    BookingStatus parseStatus(dynamic rawStatus) {
      final statusName = rawStatus?.toString();
      return BookingStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => BookingStatus.inElaborazione,
      );
    }

    return Booking(
      id: id,
      userId: map['user_id'] as String? ?? '',
      groupId: map['group_id'] as String?,
      data: map['data'] as String? ?? '',
      oraInizio: map['ora_inizio'] as String? ?? '',
      oraFine: map['ora_fine'] as String? ?? '',
      numeroUtenti: map['numero_utenti'] as int? ?? 0,
      attrezzatura: map['attrezzatura'] as String? ?? '',
      stato: parseStatus(map['stato']),
    );
  }
}

class Jam {
  String? id;
  final String creatorId;
  final String? groupId;
  final String? groupName;
  final String titolo;
  final String data;
  final String oraInizio;
  final String oraFine;

  final int personePresenti;
  final int personeRichieste;
  final String descrizione;
  final String pagamento;
  final String attrezzatura;
  final String? creatorNickname; // Aggiunto per coerenza
  final JamStatus stato;

  Jam({
    this.id,
    required this.creatorId,
    this.groupId,
    this.groupName,
    required this.titolo,
    required this.data,
    required this.oraInizio,
    required this.oraFine,
    required this.personePresenti,
    required this.personeRichieste,
    required this.descrizione,
    required this.pagamento,
    required this.attrezzatura,
    this.creatorNickname,
    this.stato = JamStatus.inElaborazione,
  });

  Map<String, dynamic> toMap() {
    return {
      'creator_id': creatorId,
      'creator_nickname': creatorNickname,
      'group_id': groupId,
      'group_name': groupName,
      'titolo': titolo,
      'data': data,
      'ora_inizio': oraInizio,
      'ora_fine': oraFine,
      'persone_presenti': personePresenti,
      'persone_richieste': personeRichieste,
      'descrizione': descrizione,
      'pagamento': pagamento,
      'attrezzatura': attrezzatura,
      'stato': stato.name,
    };
  }

  factory Jam.fromMap(String id, Map<String, dynamic> map) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    JamStatus parseStatus(dynamic rawStatus) {
      final statusName = rawStatus?.toString();
      return JamStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () {
          final normalized = statusName?.toLowerCase();
          if (normalized == 'published' || normalized == 'pubblicata') {
            return JamStatus.pubblicata;
          }
          return JamStatus.inElaborazione;
        },
      );
    }

    return Jam(
      id: id,
      creatorId: map['creator_id'] as String? ?? '',
      groupId: map['group_id'] as String?,
      groupName: map['group_name'] as String?,
      titolo: map['titolo'] as String? ?? '',
      data: map['data'] as String? ?? '',
      oraInizio: map['ora_inizio'] as String? ?? '',
      oraFine: map['ora_fine'] as String? ?? '',
      personePresenti: parseInt(map['persone_presenti']),
      personeRichieste: parseInt(map['persone_richieste']),
      descrizione: map['descrizione'] as String? ?? '',
      pagamento: map['pagamento'] as String? ?? '',
      attrezzatura: map['attrezzatura'] as String? ?? '',
      creatorNickname: map['creator_nickname'] as String?,
      stato: parseStatus(map['stato'] ?? map['status']),
    );
  }
}
