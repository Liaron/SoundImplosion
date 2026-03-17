import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/profile/profile_controller.dart';
import 'package:soundimplosion/app/features/profile/profile_repository.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  test('ProfileController initializes and loads profile', () async {
    final repository = FakeProfileRepository(
      initialUser: AppUser(uid: 'user-1', nickname: 'Nick'),
    );
    final controller = ProfileController(repository: repository);

    await controller.initialize();

    expect(controller.isLoading, isFalse);
    expect(controller.user?.nickname, 'Nick');

    controller.dispose();
  });

  test('ProfileController updates nickname and instruments', () async {
    final repository = FakeProfileRepository(
      initialUser: AppUser(uid: 'user-1', nickname: 'Nick'),
    );
    final controller = ProfileController(repository: repository);

    await controller.initialize();
    await controller.updateNickname('NuovoNick');
    await controller.addInstrument(name: 'Chitarra', level: 7);
    await controller.removeInstrument(0);

    expect(controller.user?.nickname, 'NuovoNick');
    expect(controller.user?.strumentiList, isEmpty);
    expect(repository.savedUsers, hasLength(3));

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