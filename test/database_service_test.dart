import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/services/database_service.dart';

void main() {
  group('DatabaseService.extractIndexedUserIds', () {
    test('supports current nested index structure', () {
      final ids = DatabaseService.extractIndexedUserIds({
        'user-1': {'nickname': 'Alessio'},
        'user-2': {'nickname': 'Mario'},
      });

      expect(ids, {'user-1', 'user-2'});
    });

    test('supports legacy string index structure', () {
      final ids = DatabaseService.extractIndexedUserIds('user-1');

      expect(ids, {'user-1'});
    });

    test('supports legacy single payload map', () {
      final ids = DatabaseService.extractIndexedUserIds({
        'uid': 'user-1',
        'nickname': 'Alessio',
      });

      expect(ids, {'user-1'});
    });

    test('ignores unsupported payloads', () {
      expect(DatabaseService.extractIndexedUserIds(42), isEmpty);
      expect(DatabaseService.extractIndexedUserIds(null), isEmpty);
    });
  });

  group('DatabaseService.sanitizeUsernameSeed', () {
    test('normalizes display names into username-safe values', () {
      expect(
        DatabaseService.sanitizeUsernameSeed('Alessio Chima'),
        'alessiochima',
      );
      expect(
        DatabaseService.sanitizeUsernameSeed('Alessio.Chima_92'),
        'alessiochima_92',
      );
    });

    test('falls back to empty string for unsupported characters only', () {
      expect(DatabaseService.sanitizeUsernameSeed('***'), isEmpty);
    });
  });
}
