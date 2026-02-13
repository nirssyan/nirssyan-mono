import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';
import 'analytics_service.dart';
import 'authenticated_http_client.dart';

class TelegramStatus {
  final bool linked;
  final String? telegramUsername;

  TelegramStatus({required this.linked, this.telegramUsername});

  factory TelegramStatus.fromJson(Map<String, dynamic> json) {
    return TelegramStatus(
      linked: json['linked'] as bool? ?? false,
      telegramUsername: json['telegram_username'] as String?,
    );
  }
}

class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  final AuthenticatedHttpClient _httpClient = AuthenticatedHttpClient();

  Map<String, String> get _authHeaders {
    final user = AuthService().currentUser;
    return {
      ...ApiConfig.commonHeaders,
      if (user != null) 'user-id': user.id,
      'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
    };
  }

  /// Проверяет статус привязки Telegram
  Future<TelegramStatus?> getStatus() async {
    final user = AuthService().currentUser;
    if (user == null) return null;

    try {
      final response = await _httpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/telegram/status'),
        headers: _authHeaders,
        timeout: ApiConfig.requestTimeout,
      );

      if (response.statusCode == 200) {
        return TelegramStatus.fromJson(jsonDecode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      print('TelegramService.getStatus: $e');
      return null;
    }
  }

  /// Запрашивает URL для привязки Telegram
  Future<String?> getTelegramLinkUrl() async {
    final user = AuthService().currentUser;
    if (user == null) return null;

    try {
      final response = await _httpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/telegram/link-url'),
        headers: _authHeaders,
        timeout: ApiConfig.requestTimeout,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      } else {
        return null;
      }
    } catch (e) {
      print('TelegramService.getLinkUrl: $e');
      return null;
    }
  }
}
