import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/app_scaffold_controller.dart';
import 'package:soundimplosion/app/features/profile/profile_repository.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  test('AppScaffoldController marks configured profile when nickname differs from uid', () async {
    final repository = FakeProfileRepository(
      initialUser: AppUser(uid: 'user-1', nickname: 'nick'),
    );
    final controller = AppScaffoldController(profileRepository: repository);

    await controller.initialize();

    expect(controller.isLoadingProfile, isFalse);
    expect(controller.isProfileConfigured, isTrue);

    controller.dispose();
  });

  test('AppScaffoldController exposes admin role from loaded profile', () async {
    final repository = FakeProfileRepository(
      initialUser: AppUser(uid: 'user-1', nickname: 'nick', role: 'admin'),
    );
    final controller = AppScaffoldController(profileRepository: repository);

    await controller.initialize();

    expect(controller.isAdmin, isTrue);

    controller.dispose();
  });

  test('AppScaffoldController saves initial profile nickname', () async {
    final repository = FakeProfileRepository(
      initialUser: AppUser(uid: 'user-1', nickname: 'user-1'),
    );
    final controller = AppScaffoldController(profileRepository: repository);

    await controller.initialize();
    await controller.saveInitialProfile('NuovoNick');

    expect(controller.isProfileConfigured, isTrue);
    expect(repository.savedUsers.single.nickname, 'NuovoNick');

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
}