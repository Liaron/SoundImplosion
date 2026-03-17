import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/app_scaffold_controller.dart';
import 'package:soundimplosion/app/features/profile/profile_repository.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  test(
    'AppScaffoldController loads profile and marks email as verified',
    () async {
      final repository = FakeProfileRepository(
        initialUser: AppUser(uid: 'user-1', nickname: 'nick'),
      );
      final controller = AppScaffoldController(
        profileRepository: repository,
        currentEmailVerified: () => true,
        refreshEmailVerification: () async => true,
        sendVerificationEmail: () async {},
      );

      await controller.initialize();

      expect(controller.isLoadingProfile, isFalse);
      expect(controller.isEmailVerified, isTrue);
      expect(controller.user?.nickname, 'nick');

      controller.dispose();
    },
  );

  test(
    'AppScaffoldController exposes admin role from loaded profile',
    () async {
      final repository = FakeProfileRepository(
        initialUser: AppUser(uid: 'user-1', nickname: 'nick', role: 'admin'),
      );
      final controller = AppScaffoldController(
        profileRepository: repository,
        currentEmailVerified: () => true,
        refreshEmailVerification: () async => true,
        sendVerificationEmail: () async {},
      );

      await controller.initialize();

      expect(controller.isAdmin, isTrue);

      controller.dispose();
    },
  );

  test('AppScaffoldController refreshes email verification', () async {
    final repository = FakeProfileRepository(
      initialUser: AppUser(uid: 'user-1', nickname: 'nick'),
    );
    var verified = false;
    final controller = AppScaffoldController(
      profileRepository: repository,
      currentEmailVerified: () => verified,
      refreshEmailVerification: () async {
        verified = true;
        return verified;
      },
      sendVerificationEmail: () async {},
    );

    await controller.initialize();
    expect(controller.isEmailVerified, isFalse);

    await controller.refreshEmailVerification();

    expect(controller.isEmailVerified, isTrue);

    controller.dispose();
  });
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.initialUser});

  final AppUser? initialUser;
  final List<AppUser> savedUsers = [];

  @override
  Future<AppUser?> loadProfile() async => initialUser;

  @override
  Future<void> saveProfile(AppUser user) async {
    savedUsers.add(user);
  }

  @override
  Future<void> deleteProfile() async {}
}
