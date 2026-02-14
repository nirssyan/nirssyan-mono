import 'package:flutter/foundation.dart';
import '../models/feed_builder_models.dart';

/// Service for caching session state between tab switches
class FeedBuilderStateService extends ChangeNotifier {
  static final FeedBuilderStateService _instance = FeedBuilderStateService._internal();
  factory FeedBuilderStateService() => _instance;
  FeedBuilderStateService._internal();

  // Active session ID
  String? _activeSessionId;

  // Active session object with messages
  FeedBuilderSession? _activeSession;

  // Flag for showing session list
  bool _showingSessionList = false;

  // Flag for first tab open (to show empty session by default)
  bool _isFirstOpen = true;

  // Additional state for tracking last actions
  DateTime? _lastActivityTime;
  String? _lastUserMessage;

  // Getters
  String? get activeSessionId => _activeSessionId;
  FeedBuilderSession? get activeSession => _activeSession;
  bool get showingSessionList => _showingSessionList;
  bool get isFirstOpen => _isFirstOpen;
  DateTime? get lastActivityTime => _lastActivityTime;

  /// Сохраняет состояние активного чата
  void saveActiveSession(String? sessionId, FeedBuilderSession? session) {
    if (kDebugMode) {
    }

    _activeSessionId = sessionId;
    _activeSession = session;
    _lastActivityTime = DateTime.now();
    _isFirstOpen = false; // После любого сохранения состояния - это уже не первое открытие

    // Сохраняем последнее сообщение пользователя для контекста
    if (session != null && session.messages.isNotEmpty) {
      final userMessages = session.messages.where((m) => m.isUser).toList();
      if (userMessages.isNotEmpty) {
        _lastUserMessage = userMessages.last.message;
      }
    }

    notifyListeners();
  }

  /// Сохраняет состояние показа списка чатов
  void saveShowingSessionList(bool showing) {
    if (kDebugMode) {
    }

    _showingSessionList = showing;
    _lastActivityTime = DateTime.now();
    notifyListeners();
  }

  /// Обновляет чат при создании нового (после первого сообщения)
  void updateSessionAfterCreation(String sessionId, FeedBuilderSession? session) {
    if (kDebugMode) {
    }

    // Сохраняем новый созданный чат как активный
    _activeSessionId = sessionId;
    _activeSession = session;
    _showingSessionList = false; // При создании чата мы точно не в списке
    _lastActivityTime = DateTime.now();
    _isFirstOpen = false;

    notifyListeners();
  }

  /// Обновляет существующий чат при добавлении новых сообщений
  void updateSessionMessages(String sessionId, FeedBuilderSession session) {
    if (_activeSessionId == sessionId) {
      if (kDebugMode) {
      }

      _activeSession = session;
      _lastActivityTime = DateTime.now();

      // Обновляем последнее сообщение пользователя
      final userMessages = session.messages.where((m) => m.isUser).toList();
      if (userMessages.isNotEmpty) {
        _lastUserMessage = userMessages.last.message;
      }

      notifyListeners();
    }
  }

  /// Сбрасывает состояние "первого открытия"
  void markAsOpened() {
    _isFirstOpen = false;
  }

  /// Полностью очищает состояние (при выходе из аккаунта)
  void clear() {
    if (kDebugMode) {
    }

    _activeSessionId = null;
    _activeSession = null;
    _showingSessionList = false;
    _isFirstOpen = true;
    _lastActivityTime = null;
    _lastUserMessage = null;

    notifyListeners();
  }

  /// Проверяет актуальность кеша (например, не старше 30 минут)
  bool isCacheValid() {
    if (_lastActivityTime == null) return false;

    final difference = DateTime.now().difference(_lastActivityTime!);
    final isValid = difference.inMinutes < 30;

    if (kDebugMode) {
    }

    return isValid;
  }

  /// Информация о состоянии для отладки
  Map<String, dynamic> getDebugInfo() {
    return {
      'activeSessionId': _activeSessionId,
      'hasSessionObject': _activeSession != null,
      'messageCount': _activeSession?.messages.length ?? 0,
      'showingSessionList': _showingSessionList,
      'isFirstOpen': _isFirstOpen,
      'lastActivityTime': _lastActivityTime?.toIso8601String(),
      'lastUserMessage': _lastUserMessage?.substring(0, _lastUserMessage!.length > 50 ? 50 : _lastUserMessage!.length),
      'cacheValid': isCacheValid(),
    };
  }
}