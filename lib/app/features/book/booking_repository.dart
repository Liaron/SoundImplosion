import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/database_service.dart';

class BookingListItem {
  const BookingListItem({
    required this.id,
    required this.booking,
  });

  final String id;
  final Booking booking;

  String get statusLabel {
    switch (booking.stato) {
      case BookingStatus.inElaborazione:
        return 'In elaborazione';
      case BookingStatus.confermata:
        return 'Confermata';
      case BookingStatus.annullata:
        return 'Annullata';
      case BookingStatus.sospesa:
        return 'Sospesa';
      case BookingStatus.superata:
        return 'Superata';
    }
  }

  String get groupLabel {
    final groupId = booking.groupId;
    if (groupId == null || groupId.isEmpty) {
      return 'Nessun gruppo';
    }
    return 'Gruppo: $groupId';
  }
}

abstract class BookingRepository {
  Future<List<DateTime>> loadAvailableDates();
  Future<List<Map<String, String>>> loadUserGroups();
  Future<List<String>> loadAvailableSlots(DateTime date);
  Future<void> updateBooking({
    required String bookingId,
    required DateTime selectedDate,
    required List<String> selectedSlots,
    String? groupId,
    required int peopleCount,
    required String equipment,
  });
  Future<void> submitBooking({
    required DateTime selectedDate,
    required List<String> selectedSlots,
    required int peopleCount,
    required String equipment,
    String? selectedGroupId,
  });
  Stream<List<BookingListItem>> watchUserBookings();
  Stream<List<BookingListItem>> watchAccessibleBookings();
  Future<void> deleteBooking(String bookingId);
  bool areSlotsContiguous(List<String> slots);
  String calculateEndTime(String startSlot);
}

class FirebaseBookingRepository implements BookingRepository {
  FirebaseBookingRepository({
    DatabaseService? databaseService,
    FirebaseAuth? auth,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _auth = auth ?? FirebaseAuth.instance;

  final DatabaseService _databaseService;
  final FirebaseAuth _auth;

  static const int _slotDurationMinutes = 75;

  @override
  Future<List<DateTime>> loadAvailableDates() async {
    final now = DateTime.now();
    final candidateDates = List.generate(30, (index) => now.add(Duration(days: index)));

    final results = await Future.wait(candidateDates.map((date) async {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final freeSlots = await _databaseService.getFreeSlotsForDate(dateStr);
      final hasBookableSlot = freeSlots.any((slot) => _isSlotAtLeast24HoursAway(slot, date));
      return hasBookableSlot ? date : null;
    }));

    return results.whereType<DateTime>().toList();
  }

  @override
  Future<List<Map<String, String>>> loadUserGroups() {
    return _databaseService.getUserGroups();
  }

  @override
  Future<List<String>> loadAvailableSlots(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final freeSlots = await _databaseService.getFreeSlotsForDate(dateStr);
    return freeSlots.where((slot) => _isSlotAtLeast24HoursAway(slot, date)).toList();
  }

  @override
  Future<void> updateBooking({
    required String bookingId,
    required DateTime selectedDate,
    required List<String> selectedSlots,
    String? groupId,
    required int peopleCount,
    required String equipment,
  }) {
    return _databaseService.updateBooking(
      bookingId: bookingId,
      date: DateFormat('yyyy-MM-dd').format(selectedDate),
      selectedSlotTimes: selectedSlots,
      groupId: groupId,
      peopleCount: peopleCount,
      equipment: equipment,
    );
  }

  @override
  Future<void> submitBooking({
    required DateTime selectedDate,
    required List<String> selectedSlots,
    required int peopleCount,
    required String equipment,
    String? selectedGroupId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final orderedSlots = List<String>.from(selectedSlots)..sort();
    if (orderedSlots.isEmpty) {
      throw Exception('Seleziona almeno un orario');
    }
    if (!areSlotsContiguous(orderedSlots)) {
      throw Exception('Gli orari selezionati devono essere consecutivi.');
    }

    final startSlot = orderedSlots.first;
    final endTime = calculateEndTime(orderedSlots.last);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    final booking = Booking(
      userId: user.uid,
      groupId: selectedGroupId,
      data: dateStr,
      oraInizio: startSlot,
      oraFine: endTime,
      numeroUtenti: peopleCount,
      attrezzatura: equipment.trim(),
      stato: BookingStatus.inElaborazione,
    );

    await _databaseService.createBooking(booking, orderedSlots);
  }

  @override
  Stream<List<BookingListItem>> watchUserBookings() {
    return _databaseService.getBookingsStream().map((event) {
      return _parseBookingCollection(event.snapshot.value);
    });
  }

  @override
  Stream<List<BookingListItem>> watchAccessibleBookings() {
    final controller = StreamController<List<BookingListItem>>();
    List<BookingListItem> ownBookings = const [];
    final Map<String, List<BookingListItem>> groupBookings = {};
    StreamSubscription<DatabaseEvent>? ownSubscription;
    StreamSubscription<DatabaseEvent>? groupIdsSubscription;
    final List<StreamSubscription<DatabaseEvent>> groupSubscriptions = [];

    void emitMerged() {
      final merged = <String, BookingListItem>{
        for (final item in ownBookings) item.id: item,
        for (final bookings in groupBookings.values)
          for (final item in bookings) item.id: item,
      }.values.toList()
        ..sort((a, b) {
          final left = '${a.booking.data} ${a.booking.oraInizio}';
          final right = '${b.booking.data} ${b.booking.oraInizio}';
          return right.compareTo(left);
        });

      controller.add(merged);
    }

    ownSubscription = _databaseService.getBookingsStream().listen(
      (event) {
        ownBookings = _parseBookingCollection(event.snapshot.value);
        emitMerged();
      },
      onError: controller.addError,
    );

    groupIdsSubscription = _databaseService.getUserGroupIdsStream().listen(
      (event) async {
        for (final subscription in groupSubscriptions) {
          await subscription.cancel();
        }
        groupSubscriptions.clear();
        groupBookings.clear();

        final groupIds = _parseIdCollection(event.snapshot.value);
        for (final groupId in groupIds) {
          final subscription = _databaseService.getGroupBookingsStream(groupId).listen(
            (groupEvent) {
              groupBookings[groupId] = _parseBookingCollection(groupEvent.snapshot.value);
              emitMerged();
            },
            onError: controller.addError,
          );
          groupSubscriptions.add(subscription);
        }

        emitMerged();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await ownSubscription?.cancel();
      await groupIdsSubscription?.cancel();
      for (final subscription in groupSubscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  @override
  Future<void> deleteBooking(String bookingId) {
    return _databaseService.deleteBooking(bookingId);
  }

  @override
  bool areSlotsContiguous(List<String> slots) {
    if (slots.length <= 1) {
      return true;
    }

    for (int index = 0; index < slots.length - 1; index++) {
      final current = _timeToMinutes(slots[index]);
      final next = _timeToMinutes(slots[index + 1]);
      if (next - current != _slotDurationMinutes) {
        return false;
      }
    }

    return true;
  }

  @override
  String calculateEndTime(String startSlot) {
    final totalMinutes = _timeToMinutes(startSlot) + _slotDurationMinutes;
    final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _isSlotAtLeast24HoursAway(String slot, DateTime date) {
    final parts = slot.split(':');
    final slotDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    final minAllowedStart = DateTime.now().add(const Duration(hours: 24));
    return slotDateTime.isAfter(minAllowedStart);
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  List<BookingListItem> _parseBookingCollection(dynamic rawData) {
    final bookings = <BookingListItem>[];

    if (rawData is Map) {
      for (final entry in rawData.entries) {
        final bookingData = Map<String, dynamic>.from(entry.value as Map);
        bookings.add(
          BookingListItem(
            id: entry.key.toString(),
            booking: Booking.fromMap(entry.key.toString(), bookingData),
          ),
        );
      }
    } else if (rawData is List) {
      for (int index = 0; index < rawData.length; index++) {
        final item = rawData[index];
        if (item == null) {
          continue;
        }
        final bookingData = Map<String, dynamic>.from(item as Map);
        bookings.add(
          BookingListItem(
            id: index.toString(),
            booking: Booking.fromMap(index.toString(), bookingData),
          ),
        );
      }
    }

    return bookings;
  }

  List<String> _parseIdCollection(dynamic rawData) {
    if (rawData is Map) {
      return rawData.keys.map((key) => key.toString()).toList();
    }
    if (rawData is List) {
      final values = <String>[];
      for (int index = 0; index < rawData.length; index++) {
        if (rawData[index] != null) {
          values.add(index.toString());
        }
      }
      return values;
    }
    return const [];
  }
}