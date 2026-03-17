import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/jam/jam_repository.dart';

class FindJamController extends ChangeNotifier {
  FindJamController({
    JamRepository? repository,
    this.currentUserId,
  }) : _repository = repository ?? FirebaseJamRepository();

  final JamRepository _repository;
  final String? currentUserId;

  bool isLoading = true;
  bool isLoadingFilterDates = false;
  Object? streamError;

  List<DateTime> selectedDates = [];
  bool showMyJams = false;
  bool showParticipatingJams = false;
  List<JamListItem> allJams = [];

  StreamSubscription<List<JamListItem>>? _subscription;

  List<JamListItem> get filteredJams {
    if (showMyJams) {
      var jams = allJams.where((jam) => jam.isOwnedBy(currentUserId)).toList();

      if (selectedDates.isNotEmpty) {
        jams = jams.where((jam) {
          final jamDate = _parseDate(jam.jam.data);
          if (jamDate == null) {
            return false;
          }

          return selectedDates.any((selected) => _isSameDay(selected, jamDate));
        }).toList();
      }

      jams.sort((a, b) => '${b.jam.data} ${b.jam.oraInizio}'.compareTo('${a.jam.data} ${a.jam.oraInizio}'));
      return jams;
    }

    var jams = allJams.where((jam) => jam.isPublished).toList();

    if (showParticipatingJams) {
      jams = jams.where((jam) => jam.isJoinedBy(currentUserId)).toList();
    }

    if (selectedDates.isNotEmpty) {
      jams = jams.where((jam) {
        final jamDate = _parseDate(jam.jam.data);
        if (jamDate == null) {
          return false;
        }

        return selectedDates.any((selected) => _isSameDay(selected, jamDate));
      }).toList();
    }

    jams.sort((a, b) => '${b.jam.data} ${b.jam.oraInizio}'.compareTo('${a.jam.data} ${a.jam.oraInizio}'));
    return jams;
  }

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    _subscription = _repository.watchJams().listen(
      (jams) {
        allJams = jams;
        streamError = null;
        isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        streamError = error;
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<List<DateTime>> loadAvailableFilterDates() async {
    isLoadingFilterDates = true;
    notifyListeners();

    try {
      final jams = await _repository.loadPublishedJamsOnce();
      final availableDays = <DateTime>[];

      for (final jam in jams) {
        final parsed = _parseDate(jam.jam.data);
        if (parsed == null) {
          continue;
        }

        final normalized = DateTime(parsed.year, parsed.month, parsed.day);
        if (!availableDays.any((day) => _isSameDay(day, normalized))) {
          availableDays.add(normalized);
        }
      }

      return availableDays;
    } finally {
      isLoadingFilterDates = false;
      notifyListeners();
    }
  }

  Future<JamListItem?> loadJamById(String jamId) {
    return _repository.loadJamById(jamId);
  }

  Future<void> joinJam(String jamId) {
    return _repository.joinJam(jamId);
  }

  Future<void> leaveJam(String jamId) {
    return _repository.leaveJam(jamId);
  }

  void setSelectedDates(List<DateTime> dates) {
    selectedDates = dates;
    notifyListeners();
  }

  void clearSelectedDates() {
    selectedDates = [];
    notifyListeners();
  }

  void setShowMyJams(bool value) {
    showMyJams = value;
    notifyListeners();
  }

  void setShowParticipatingJams(bool value) {
    showParticipatingJams = value;
    notifyListeners();
  }

  void resetFilters() {
    selectedDates = [];
    showMyJams = false;
    showParticipatingJams = false;
    notifyListeners();
  }

  Future<void> deleteJam(String jamId) {
    return _repository.deleteJam(jamId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  DateTime? _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}