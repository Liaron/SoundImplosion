import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/services/app_update_service.dart';

void main() {
  group('AppUpdateService', () {
    test('parseBuildNumber parses integers and strings', () {
      expect(AppUpdateService.parseBuildNumber(123), 123);
      expect(AppUpdateService.parseBuildNumber('456'), 456);
      expect(AppUpdateService.parseBuildNumber('abc'), 0);
    });

    test('isBuildOutdated only blocks lower builds', () {
      expect(
        AppUpdateService.isBuildOutdated(
          currentBuildNumber: 260319,
          minimumBuildNumber: 260320,
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isBuildOutdated(
          currentBuildNumber: 260320,
          minimumBuildNumber: 260320,
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isBuildOutdated(
          currentBuildNumber: 260321,
          minimumBuildNumber: 260320,
        ),
        isFalse,
      );
    });
  });
}