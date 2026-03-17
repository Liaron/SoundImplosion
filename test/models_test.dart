import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  test('AppUser.fromMap tolerates legacy string fields', () {
    final user = AppUser.fromMap('user-1', {
      'username': 'Alessio',
      'role': 'user',
      'preferenze': 'legacy-value',
      'strumenti_list': 'Chitarra',
      'profile_image_url': 12345,
    });

    expect(user.nickname, 'Alessio');
    expect(user.preferenze, isEmpty);
    expect(user.strumentiList, [
      {'nome': 'Chitarra', 'livello': 0},
    ]);
    expect(user.profileImageUrl, '12345');
  });

  test('AppUser.fromMap parses map and list based legacy collections', () {
    final user = AppUser.fromMap('user-1', {
      'username': 'Alessio',
      'gruppi': {'group-1': true, 'group-2': true},
      'amici': ['friend-1', 'friend-2'],
      'preferenze': {'genre': 'rock'},
      'strumenti_list': {
        '0': {'nome': 'Basso', 'livello': 2},
        '1': 'Voce',
      },
    });

    expect(user.gruppi, ['group-1', 'group-2']);
    expect(user.amici, ['friend-1', 'friend-2']);
    expect(user.preferenze, {'genre': 'rock'});
    expect(user.strumentiList, [
      {'nome': 'Basso', 'livello': 2},
      {'nome': 'Voce', 'livello': 0},
    ]);
  });

  test('AppUser.toMap writes username fields', () {
    final user = AppUser(uid: 'user-1', nickname: 'Alessio');

    expect(user.toMap()['username'], 'Alessio');
    expect(user.toMap()['username_lowercase'], 'alessio');
    expect(user.toMap().containsKey('nickname'), isFalse);
  });
}
