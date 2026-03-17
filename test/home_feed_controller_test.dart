import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/home/feed_repository.dart';
import 'package:soundimplosion/app/features/home/home_feed_controller.dart';

void main() {
  test('HomeFeedController initializes and receives sorted feed items', () async {
    final repository = FakeFeedRepository([
      const HomeFeedItem(id: '1', type: 'jam_published', timestamp: 10),
      const HomeFeedItem(id: '2', type: 'jam_published', timestamp: 20),
    ]);
    final controller = HomeFeedController(repository: repository);

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(controller.isLoading, isFalse);
    expect(controller.items, hasLength(2));
    expect(controller.items.first.id, '1');

    controller.dispose();
  });
}

class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository(this.items);

  final List<HomeFeedItem> items;

  @override
  Stream<List<HomeFeedItem>> watchFeedItems() {
    return Stream<List<HomeFeedItem>>.value(items);
  }
}