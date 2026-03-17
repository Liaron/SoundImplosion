import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/services/database_service.dart';

void main() {
  test('RegistrationAvailability reports both conflicts', () {
    const availability = RegistrationAvailability(
      nicknameAvailable: false,
      emailAvailable: false,
    );

    expect(availability.isAvailable, isFalse);
    expect(availability.errorMessage, 'Email e username gia utilizzati');
  });

  test('RegistrationAvailability reports username conflict', () {
    const availability = RegistrationAvailability(
      nicknameAvailable: false,
      emailAvailable: true,
    );

    expect(availability.errorMessage, 'Username gia utilizzato');
  });

  test('RegistrationAvailability reports email conflict', () {
    const availability = RegistrationAvailability(
      nicknameAvailable: true,
      emailAvailable: false,
    );

    expect(availability.errorMessage, 'Email gia utilizzata');
  });
}
