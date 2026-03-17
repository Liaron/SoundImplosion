import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/services/database_service.dart';

class AdminSlotItem {
  const AdminSlotItem({
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
  bool get isMutable => !isOccupied;

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

abstract class AdminSlotManagementRepository {
  Future<List<AdminSlotItem>> loadSlots(DateTime date);
  Future<void> updateSlots({
    required DateTime date,
    required List<String> slotTimes,
    required bool disabled,
  });
}

class FirebaseAdminSlotManagementRepository
    implements AdminSlotManagementRepository {
  FirebaseAdminSlotManagementRepository({
    DatabaseService? databaseService,
    FirebaseAuth? auth,
  }) : _databaseService = databaseService ?? DatabaseService(),
       _auth = auth ?? FirebaseAuth.instance;

  final DatabaseService _databaseService;
  final FirebaseAuth _auth;

  @override
  Future<List<AdminSlotItem>> loadSlots(DateTime date) async {
    if (_auth.currentUser == null) {
      throw Exception('Utente non loggato');
    }

    final slotMaps = await _databaseService.getAdminSlotsForDate(
      DateFormat('yyyy-MM-dd').format(date),
    );

    return slotMaps
        .map(
          (slot) => AdminSlotItem(
            time: slot['time']?.toString() ?? '',
            status: slot['status']?.toString() ?? 'libero',
            bookedBy: slot['booked_by']?.toString(),
            bookingId: slot['booking_id']?.toString(),
            isJam: slot['is_jam'] == true,
          ),
        )
        .where((slot) => slot.time.isNotEmpty)
        .toList();
  }

  @override
  Future<void> updateSlots({
    required DateTime date,
    required List<String> slotTimes,
    required bool disabled,
  }) {
    return _databaseService.updateAdminSlotStatuses(
      dateStr: DateFormat('yyyy-MM-dd').format(date),
      slotTimes: slotTimes,
      disabled: disabled,
    );
  }
}
