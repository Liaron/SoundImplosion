import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.minimumBuildNumber,
    required this.latestVersionLabel,
    required this.updateUrl,
    required this.title,
    required this.message,
  });

  final int minimumBuildNumber;
  final String latestVersionLabel;
  final String updateUrl;
  final String title;
  final String message;

  factory AppUpdatePolicy.fromMap(Map<String, dynamic> map) {
    return AppUpdatePolicy(
      minimumBuildNumber: AppUpdateService.parseBuildNumber(
        map['minimum_build_number'],
      ),
      latestVersionLabel: map['latest_version_label']?.toString().trim() ?? '',
      updateUrl: map['update_url']?.toString().trim() ?? '',
      title: map['title']?.toString().trim().isNotEmpty == true
          ? map['title'].toString().trim()
          : 'Aggiornamento richiesto',
      message: map['message']?.toString().trim().isNotEmpty == true
          ? map['message'].toString().trim()
          : 'Per continuare a usare SoundImplosion devi installare la versione piu recente dell\'app.',
    );
  }
}

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.requiresUpdate,
    required this.currentVersionLabel,
    required this.currentBuildNumber,
    this.policy,
  });

  final bool requiresUpdate;
  final String currentVersionLabel;
  final int currentBuildNumber;
  final AppUpdatePolicy? policy;
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();
  static const String androidFallbackDownloadUrl =
      'https://soundimplosion.it/soundimplosion-android.apk';

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Future<AppUpdateStatus> checkForRequiredUpdate() async {
    if (kIsWeb) {
      return const AppUpdateStatus(
        requiresUpdate: false,
        currentVersionLabel: 'web',
        currentBuildNumber: 0,
      );
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuildNumber = parseBuildNumber(packageInfo.buildNumber);
    final currentVersionLabel =
        'v${packageInfo.version}+${packageInfo.buildNumber}';

    final platformKey = _platformKey;
    if (platformKey == null) {
      return AppUpdateStatus(
        requiresUpdate: false,
        currentVersionLabel: currentVersionLabel,
        currentBuildNumber: currentBuildNumber,
      );
    }

    try {
      final snapshot = await _database
          .ref('app_config/force_update/$platformKey')
          .get();
      if (!snapshot.exists || snapshot.value is! Map) {
        return AppUpdateStatus(
          requiresUpdate: false,
          currentVersionLabel: currentVersionLabel,
          currentBuildNumber: currentBuildNumber,
        );
      }

      final policy = AppUpdatePolicy.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map),
      );
      final requiresUpdate = isBuildOutdated(
        currentBuildNumber: currentBuildNumber,
        minimumBuildNumber: policy.minimumBuildNumber,
      );

      final normalizedPolicy = AppUpdatePolicy(
        minimumBuildNumber: policy.minimumBuildNumber,
        latestVersionLabel: policy.latestVersionLabel,
        updateUrl: policy.updateUrl.isNotEmpty
            ? policy.updateUrl
            : androidFallbackDownloadUrl,
        title: policy.title,
        message: policy.message,
      );

      return AppUpdateStatus(
        requiresUpdate: requiresUpdate,
        currentVersionLabel: currentVersionLabel,
        currentBuildNumber: currentBuildNumber,
        policy: normalizedPolicy,
      );
    } catch (_) {
      return AppUpdateStatus(
        requiresUpdate: false,
        currentVersionLabel: currentVersionLabel,
        currentBuildNumber: currentBuildNumber,
      );
    }
  }

  static int parseBuildNumber(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool isBuildOutdated({
    required int currentBuildNumber,
    required int minimumBuildNumber,
  }) {
    if (minimumBuildNumber <= 0) {
      return false;
    }
    return currentBuildNumber < minimumBuildNumber;
  }

  String? get _platformKey {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
  }
}