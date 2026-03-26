import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/database_service.dart';

class BookingListItem {
  const BookingListItem({required this.id, required this.booking});

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
    final groupName = booking.groupName?.trim();
    if (groupName != null && groupName.isNotEmpty) {
      return 'Gruppo: $groupName';
    }
    final groupId = booking.groupId?.trim();
    if (groupId == null || groupId.isEmpty) {
      return 'Nessun gruppo';
    }
    return 'Gruppo: $groupId';
  }
}

class BookingSlotItem {
  const BookingSlotItem({
    required this.time,
    required this.status,
    this.bookedBy,
    this.bookingId,
    this.isJam = false,
  });

  final String time;
  final String status;
  final String? bookedBy;
  final String? bookingId;
  final bool isJam;

  bool get isDisabled => status == 'disabilitato';
  bool get isFree => status == 'libero';
  bool get isOccupied => !isFree && !isDisabled;

  String get statusLabel {
    if (isDisabled) {
      return 'Disabilitato';
    }
    if (isOccupied) {
      return isJam ? 'Jam' : 'Occupato';
    }
    return 'Libero';
  }
}

abstract class BookingRepository {
  Future<List<DateTime>> loadAvailableDates();
  Future<List<Map<String, String>>> loadUserGroups();
  Future<List<String>> loadAvailableSlots(DateTime date);
  Future<List<BookingSlotItem>> loadSlotsOverview(DateTime date);
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
  }) : _databaseService = databaseService ?? DatabaseService(),
       _auth = auth ?? FirebaseAuth.instance;

  final DatabaseService _databaseService;
  final FirebaseAuth _auth;

  static const int _slotDurationMinutes = 30;

  Map<String, dynamic>? _mapFromRawValue(dynamic rawValue) {
    if (rawValue is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(rawValue);
  }

  @override
  Future<List<DateTime>> loadAvailableDates() async {
    await _databaseService.cleanupPastSlots();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final candidateDates = List.generate(
      30,
      (index) => now.add(Duration(days: index)),
    );

    final results = await Future.wait(
      candidateDates.map((date) async {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final freeSlots = await _databaseService.getFreeSlotsForDate(dateStr);
        final hasBookableSlot = freeSlots.any(
          (slot) => _isSlotAtLeast24HoursAway(slot, date),
        );
        return hasBookableSlot
            ? DateTime(date.year, date.month, date.day)
            : null;
      }),
    );

    return results
        .whereType<DateTime>()
        .where(
          (date) => !DateTime(date.year, date.month, date.day).isBefore(today),
        )
        .toList();
  }

  @override
  Future<List<Map<String, String>>> loadUserGroups() {
    return _databaseService.getUserGroups();
  }

  @override
  Future<List<String>> loadAvailableSlots(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final freeSlots = await _databaseService.getFreeSlotsForDate(dateStr);
    return freeSlots
        .where((slot) => _isSlotAtLeast24HoursAway(slot, date))
        .toList();
  }

  @override
  Future<List<BookingSlotItem>> loadSlotsOverview(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final slotMaps = await _databaseService.getSlotsForDate(dateStr);
    return slotMaps
        .map(
          (slot) => BookingSlotItem(
            time: slot['time']?.toString() ?? '',
            status: slot['status']?.toString() ?? 'libero',
            bookedBy: slot['booked_by']?.toString(),
            bookingId: slot['booking_id']?.toString(),
            isJam: slot['is_jam'] == true,
          ),
        )
        .where((slot) => slot.time.isNotEmpty)
        .where((slot) => _isSlotAtLeast24HoursAway(slot.time, date))
        .toList();
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
    if (orderedSlots.length < 2) {
      throw Exception('Seleziona almeno due slot contigui.');
    }
    if (!areSlotsContiguous(orderedSlots)) {
      throw Exception(
        'Per selezionare slot separati e necessario effettuare due richieste distinte.',
      );
    }

    final availableGroups = selectedGroupId == null
        ? const <Map<String, String>>[]
        : await loadUserGroups();

    final startSlot = orderedSlots.first;
    final endTime = calculateEndTime(orderedSlots.last);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final selectedGroupName = selectedGroupId == null
        ? null
        : availableGroups
              .where((group) => group['id'] == selectedGroupId)
              .map((group) => group['name']?.trim())
              .firstWhere(
                (name) => name != null && name.isNotEmpty,
                orElse: () => null,
              );

    final booking = Booking(
      userId: user.uid,
      groupId: selectedGroupId,
      groupName: selectedGroupName,
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
    final controller = StreamController<List<BookingListItem>>();
    late final StreamSubscription<DatabaseEvent> subscription;

    subscription = _databaseService.getBookingsStream().listen((event) async {
      try {
        controller.add(await _parseBookingCollection(event.snapshot.value));
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }, onError: controller.addError);

    controller.onCancel = () async {
      await subscription.cancel();
    };

    return controller.stream;
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
      final merged =
          <String, BookingListItem>{
            for (final item in ownBookings) item.id: item,
            for (final bookings in groupBookings.values)
              for (final item in bookings) item.id: item,
          }.values.toList()..sort((a, b) {
            final left = '${a.booking.data} ${a.booking.oraInizio}';
            final right = '${b.booking.data} ${b.booking.oraInizio}';
            return right.compareTo(left);
          });

      controller.add(merged);
    }

    ownSubscription = _databaseService.getBookingsStream().listen((
      event,
    ) async {
      try {
        ownBookings = await _parseBookingCollection(event.snapshot.value);
        emitMerged();
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }, onError: controller.addError);

    groupIdsSubscription = _databaseService.getUserGroupIdsStream().listen((
      event,
    ) async {
      for (final subscription in groupSubscriptions) {
        await subscription.cancel();
      }
      groupSubscriptions.clear();
      groupBookings.clear();

      final groupIds = _parseIdCollection(event.snapshot.value);
      for (final groupId in groupIds) {
        final subscription = _databaseService
            .getGroupBookingsStream(groupId)
            .listen((groupEvent) async {
              try {
                groupBookings[groupId] = await _parseBookingCollection(
                  groupEvent.snapshot.value,
                );
                emitMerged();
              } catch (error, stackTrace) {
                controller.addError(error, stackTrace);
              }
            }, onError: controller.addError);
        groupSubscriptions.add(subscription);
      }

      emitMerged();
    }, onError: controller.addError);

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

  Future<List<BookingListItem>> _parseBookingCollection(dynamic rawData) async {
    final bookings = <BookingListItem>[];

    if (rawData is Map) {
      for (final entry in rawData.entries) {
        final bookingData = _mapFromRawValue(entry.value);
        if (bookingData == null) {
          continue;
        }
        bookings.add(
          await _buildBookingListItem(entry.key.toString(), bookingData),
        );
      }
    } else if (rawData is List) {
      for (int index = 0; index < rawData.length; index++) {
        final item = rawData[index];
        if (item == null) {
          continue;
        }
        final bookingData = _mapFromRawValue(item);
        if (bookingData == null) {
          continue;
        }
        bookings.add(
          await _buildBookingListItem(index.toString(), bookingData),
        );
      }
    }

    return bookings;
  }

  Future<BookingListItem> _buildBookingListItem(
    String id,
    Map<String, dynamic> bookingData,
  ) async {
    final booking = Booking.fromMap(id, bookingData);
    if (booking.groupId == null || booking.groupId!.trim().isEmpty) {
      return BookingListItem(id: id, booking: booking);
    }
    if (booking.groupName?.trim().isNotEmpty == true) {
      return BookingListItem(id: id, booking: booking);
    }

    final resolvedGroupName = await _databaseService.resolveGroupName(
      booking.groupId,
    );
    return BookingListItem(
      id: id,
      booking: booking.copyWith(
        groupName: resolvedGroupName.trim().isEmpty ? null : resolvedGroupName,
      ),
    );
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
