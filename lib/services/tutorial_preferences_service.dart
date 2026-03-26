import 'package:shared_preferences/shared_preferences.dart';

class TutorialPreferencesService {
  TutorialPreferencesService._();

  static final TutorialPreferencesService instance =
      TutorialPreferencesService._();

  static const String _appTutorialSeenKey = 'tutorial_seen_app_v1';

  Future<bool> shouldShowAppTutorial() async {
    final preferences = await SharedPreferences.getInstance();
    return !(preferences.getBool(_appTutorialSeenKey) ?? false);
  }

  Future<void> markAppTutorialSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_appTutorialSeenKey, true);
  }
}
