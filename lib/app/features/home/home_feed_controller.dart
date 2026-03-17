import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/home/feed_repository.dart';

class HomeFeedController extends ChangeNotifier {
  HomeFeedController({FeedRepository? repository})
    : _repository = repository ?? FirebaseFeedRepository();

  final FeedRepository _repository;

  bool isLoading = true;
  Object? error;
  List<HomeFeedItem> items = [];

  StreamSubscription<List<HomeFeedItem>>? _subscription;

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    notifyListeners();

    _subscription = _repository.watchFeedItems().listen(
      (feedItems) {
        items = feedItems;
        error = null;
        isLoading = false;
        notifyListeners();
      },
      onError: (Object streamError) {
        error = streamError;
        isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
