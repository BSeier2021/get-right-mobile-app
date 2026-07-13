import 'package:flutter/foundation.dart';

/// Global signal for [FeedVerticalReels] to halt playback when leaving the feed
/// (route push, bottom-nav change, app background, etc.).
class FeedPlaybackCoordinator extends ChangeNotifier {
  FeedPlaybackCoordinator._();

  static final FeedPlaybackCoordinator instance = FeedPlaybackCoordinator._();

  int _pauseNonce = 0;
  int get pauseNonce => _pauseNonce;

  void requestPause() {
    _pauseNonce++;
    notifyListeners();
  }
}
