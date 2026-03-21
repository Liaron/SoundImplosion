import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/notifications/notifications_repository.dart';

void main() {
  group('NotificationRouteTarget', () {
    test('support chat payload preserves chat target', () {
      const target = NotificationRouteTarget(pageIndex: 7, chatId: 'chat-42');

      final decoded = NotificationRouteTarget.fromPayload(target.toPayload());

      expect(decoded, isNotNull);
      expect(decoded!.pageIndex, 7);
      expect(decoded.chatId, 'chat-42');
      expect(decoded.hasSpecificTarget, isTrue);
    });
  });

  group('AppNotificationItem', () {
    test('support chat notifications route to contact page with chat id', () {
      final item = AppNotificationItem.fromMap('notification-1', {
        'type': 'support_chat_message',
        'timestamp': 123,
        'chat_id': 'chat-99',
      });

      expect(item.routeTarget.pageIndex, 7);
      expect(item.routeTarget.chatId, 'chat-99');
    });
  });
}