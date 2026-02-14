import 'package:flutter/cupertino.dart';
import '../navigation/main_tab_scaffold.dart';

/// Сервис для глобальной навигации
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  GlobalKey<MainTabScaffoldState>? _mainTabKey;

  /// Устанавливает ключ для MainTabScaffold
  void setMainTabKey(GlobalKey<MainTabScaffoldState> key) {
    _mainTabKey = key;
  }

  /// Переключается на таб создания ленты
  void navigateToFeedCreator() {
    _mainTabKey?.currentState?.navigateToFeedCreator();
  }

  /// Переключается на домашний таб
  void navigateToHome() {

    if (_mainTabKey == null) {
      return;
    }

    if (_mainTabKey?.currentState == null) {
      return;
    }

    _mainTabKey?.currentState?.navigateToHome();
  }

  /// Переключается на домашний таб и обновляет данные
  void navigateToHomeWithRefresh() {
    if (_mainTabKey == null) {
      return;
    }

    if (_mainTabKey?.currentState == null) {
      return;
    }

    _mainTabKey?.currentState?.navigateToHomeWithRefresh();
  }

  /// Navigate to home tab and wait for feed creation via WebSocket
  void navigateToHomeAndWaitForFeed(String feedId, {String? feedName, String? feedType}) {
    if (_mainTabKey == null) {
      return;
    }

    if (_mainTabKey?.currentState == null) {
      return;
    }

    _mainTabKey?.currentState?.navigateToHomeAndWaitForFeed(feedId, feedName: feedName, feedType: feedType);
  }

  /// Navigate to home tab and show loading overlay immediately (before feedId is known)
  void navigateToHomeWithPendingFeed({String? feedName, String? feedType}) {
    if (_mainTabKey == null) {
      return;
    }

    if (_mainTabKey?.currentState == null) {
      return;
    }

    _mainTabKey?.currentState?.navigateToHomeWithPendingFeed(feedName: feedName, feedType: feedType);
  }

  /// Update pending feed ID after API response and start WebSocket waiting
  void updatePendingFeedId(String feedId, {String? feedName, String? feedType}) {
    print('[NavigationService] updatePendingFeedId called with feedId: $feedId');

    if (_mainTabKey == null) {
      print('[NavigationService] _mainTabKey is NULL!');
      return;
    }

    if (_mainTabKey?.currentState == null) {
      print('[NavigationService] _mainTabKey.currentState is NULL!');
      return;
    }

    print('[NavigationService] Calling MainTabScaffold.updatePendingFeedId...');
    _mainTabKey?.currentState?.updatePendingFeedId(feedId, feedName: feedName, feedType: feedType);
    print('[NavigationService] MainTabScaffold.updatePendingFeedId called');
  }
}
