import 'package:soundimplosion/services/database_service.dart';

class HomeFeedItem {
  const HomeFeedItem({
    required this.id,
    required this.type,
    required this.timestamp,
    this.jamId,
    this.creatorId,
    this.date,
    this.startTime,
    this.description,
  });

  final String id;
  final String type;
  final int timestamp;
  final String? jamId;
  final String? creatorId;
  final String? date;
  final String? startTime;
  final String? description;

  bool get isJamPublished => type == 'jam_published';

  factory HomeFeedItem.fromMap(String id, Map<String, dynamic> map) {
    int parseTimestamp(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    return HomeFeedItem(
      id: id,
      type: map['type']?.toString() ?? '',
      timestamp: parseTimestamp(map['timestamp']),
      jamId: map['jam_id']?.toString(),
      creatorId: map['creator_id']?.toString(),
      date: map['data']?.toString(),
      startTime: map['ora_inizio']?.toString(),
      description: map['descrizione']?.toString(),
    );
  }
}

abstract class FeedRepository {
  Stream<List<HomeFeedItem>> watchFeedItems();
}

class FirebaseFeedRepository implements FeedRepository {
  FirebaseFeedRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;

  @override
  Stream<List<HomeFeedItem>> watchFeedItems() {
    return _databaseService.getFeedStream().map((event) {
      final rawData = event.snapshot.value;
      final feedItems = <HomeFeedItem>[];

      if (rawData is Map) {
        for (final entry in rawData.entries) {
          final itemData = Map<String, dynamic>.from(entry.value as Map);
          feedItems.add(HomeFeedItem.fromMap(entry.key.toString(), itemData));
        }
      } else if (rawData is List) {
        for (int index = 0; index < rawData.length; index++) {
          final item = rawData[index];
          if (item == null) {
            continue;
          }
          final itemData = Map<String, dynamic>.from(item as Map);
          feedItems.add(HomeFeedItem.fromMap(index.toString(), itemData));
        }
      }

      feedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return feedItems;
    });
  }
}