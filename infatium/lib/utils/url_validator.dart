/// Утилита для валидации и проверки безопасности URL перед загрузкой в WebView
///
/// Защищает от CWE-79 (XSS) и CWE-749 (Exposed Dangerous Method)
class UrlValidator {
  /// Список доверенных доменов для видео-платформ
  /// YouTube, Vimeo, Dailymotion, Rutube и другие популярные платформы
  static final Set<String> _trustedVideoDomains = {
    // YouTube
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'youtu.be',
    'youtube-nocookie.com',

    // Vimeo
    'vimeo.com',
    'player.vimeo.com',

    // Dailymotion
    'dailymotion.com',
    'www.dailymotion.com',
    'dai.ly',

    // Rutube (русская платформа)
    'rutube.ru',
    'www.rutube.ru',

    // VK Video
    'vk.com',
    'vkvideo.ru',

    // OK.ru (Одноклассники)
    'ok.ru',

    // Twitch
    'twitch.tv',
    'www.twitch.tv',

    // Twitter/X видео
    'twitter.com',
    'x.com',

    // TikTok
    'tiktok.com',
    'www.tiktok.com',

    // Instagram
    'instagram.com',
    'www.instagram.com',
  };

  /// Опасные протоколы, которые должны быть заблокированы
  static final Set<String> _dangerousSchemes = {
    'javascript',
    'data',
    'file',
    'about',
    'blob',
  };

  /// Результат валидации URL
  /// Returns UrlValidationResult with errorCode enum for localization at display layer.
  /// Callers should use errorCode with AppLocalizations to get translated messages.
  static UrlValidationResult validate(String url) {
    // Проверка на пустую строку
    if (url.isEmpty) {
      return UrlValidationResult(
        isValid: false,
        isTrusted: false,
        errorCode: UrlValidationError.emptyUrl,
      );
    }

    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      return UrlValidationResult(
        isValid: false,
        isTrusted: false,
        errorCode: UrlValidationError.invalidFormat,
      );
    }

    // Проверка на опасные протоколы
    final scheme = uri.scheme.toLowerCase();
    if (_dangerousSchemes.contains(scheme)) {
      return UrlValidationResult(
        isValid: false,
        isTrusted: false,
        errorCode: UrlValidationError.dangerousScheme,
        dangerousScheme: scheme,
      );
    }

    // Разрешены только https и http протоколы
    if (scheme != 'https' && scheme != 'http') {
      return UrlValidationResult(
        isValid: false,
        isTrusted: false,
        errorCode: UrlValidationError.unsupportedScheme,
      );
    }

    // Рекомендуется использовать https
    final isHttps = scheme == 'https';

    // Проверка на доверенный домен
    final isTrusted = _isTrustedDomain(uri.host);

    return UrlValidationResult(
      isValid: true,
      isTrusted: isTrusted,
      isHttps: isHttps,
      errorCode: null,
    );
  }

  /// Проверяет, является ли домен доверенным
  static bool _isTrustedDomain(String host) {
    final lowerHost = host.toLowerCase();

    // Точное совпадение
    if (_trustedVideoDomains.contains(lowerHost)) {
      return true;
    }

    // Проверка на поддомены (например, m.youtube.com)
    for (final trustedDomain in _trustedVideoDomains) {
      if (lowerHost.endsWith('.$trustedDomain')) {
        return true;
      }
    }

    return false;
  }

  /// Быстрая проверка: является ли URL безопасным
  static bool isSecure(String url) {
    final result = validate(url);
    return result.isValid;
  }

  /// Быстрая проверка: является ли URL из доверенного источника
  static bool isTrusted(String url) {
    final result = validate(url);
    return result.isValid && result.isTrusted;
  }
}

/// Результат валидации URL
/// Display layer should use errorCode/warningCode with AppLocalizations for translated messages.
/// ARB keys: urlEmpty, urlInvalidFormat, urlDangerousProtocol, urlOnlyHttpAllowed,
///           urlUnsafeVideoUnknownSource, urlUnsafeVideoUnknown
class UrlValidationResult {
  /// URL прошел базовую валидацию (безопасный протокол, корректный формат)
  final bool isValid;

  /// URL из доверенного домена (whitelist)
  final bool isTrusted;

  /// URL использует HTTPS протокол
  final bool isHttps;

  /// Код ошибки для логирования и localization at display layer
  final UrlValidationError? errorCode;

  /// The dangerous scheme string (e.g., 'javascript') for display interpolation
  final String? dangerousScheme;

  UrlValidationResult({
    required this.isValid,
    required this.isTrusted,
    this.isHttps = false,
    this.errorCode,
    this.dangerousScheme,
  });

  /// English fallback error message derived from errorCode.
  /// Callers should prefer using errorCode with AppLocalizations for proper l10n.
  /// This getter exists for backward compatibility during migration.
  String? get errorMessage {
    if (errorCode == null) return null;
    switch (errorCode!) {
      case UrlValidationError.emptyUrl:
        return 'URL is empty';
      case UrlValidationError.invalidFormat:
        return 'Invalid URL format';
      case UrlValidationError.dangerousScheme:
        return 'Dangerous protocol: ${dangerousScheme ?? ''}://';
      case UrlValidationError.unsupportedScheme:
        return 'Only https:// and http:// protocols are allowed';
    }
  }

  /// Warning code for display layer localization (if URL is valid but not from whitelist).
  /// Returns a UrlValidationWarning enum value, or null if no warning.
  /// Display layer should translate using AppLocalizations:
  ///   untrustedHttpSource -> l10n.urlUnsafeVideoUnknownSource
  ///   untrustedSource -> l10n.urlUnsafeVideoUnknown
  UrlValidationWarning? get warningCode {
    if (!isValid) return null;
    if (isTrusted) return null;

    if (!isHttps) {
      return UrlValidationWarning.untrustedHttpSource;
    }

    return UrlValidationWarning.untrustedSource;
  }

  /// English fallback warning message derived from warningCode.
  /// Callers should prefer using warningCode with AppLocalizations for proper l10n.
  /// This getter exists for backward compatibility during migration.
  String? get warningMessage {
    if (warningCode == null) return null;
    switch (warningCode!) {
      case UrlValidationWarning.untrustedHttpSource:
        return 'This video is from an unknown source and uses an insecure connection (http://)';
      case UrlValidationWarning.untrustedSource:
        return 'This video is from an unknown source';
    }
  }
}

/// Типы ошибок валидации
/// Display layer should map these to AppLocalizations keys:
///   emptyUrl -> l10n.urlEmpty
///   invalidFormat -> l10n.urlInvalidFormat
///   dangerousScheme -> l10n.urlDangerousProtocol(scheme)
///   unsupportedScheme -> l10n.urlOnlyHttpAllowed
enum UrlValidationError {
  emptyUrl,
  invalidFormat,
  dangerousScheme,
  unsupportedScheme,
}

/// Warning types for valid but untrusted URLs
/// Display layer should map these to AppLocalizations keys:
///   untrustedHttpSource -> l10n.urlUnsafeVideoUnknownSource
///   untrustedSource -> l10n.urlUnsafeVideoUnknown
enum UrlValidationWarning {
  untrustedHttpSource,
  untrustedSource,
}
