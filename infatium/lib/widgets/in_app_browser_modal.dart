import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/colors.dart';
import '../services/theme_service.dart';
import '../utils/url_validator.dart';
import '../l10n/generated/app_localizations.dart';

class InAppBrowserModal extends StatefulWidget {
  final String url;
  final String? title;

  const InAppBrowserModal({
    super.key,
    required this.url,
    this.title,
  });

  /// Открыть модальный браузер снизу вверх
  static Future<void> show(BuildContext context, String url, {String? title}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => InAppBrowserModal(
        url: url,
        title: title,
      ),
    );
  }

  @override
  State<InAppBrowserModal> createState() => _InAppBrowserModalState();
}

class _InAppBrowserModalState extends State<InAppBrowserModal> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _pageTitle = '';
  double _loadingProgress = 0;
  String? _validationError;
  bool _hasValidationError = false;

  // Цвета темы
  bool get _isDarkMode => ThemeService().isDarkMode;
  Color get _primaryTextColor =>
      _isDarkMode ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _backgroundColor =>
      _isDarkMode ? AppColors.background : AppColors.lightBackground;

  @override
  void initState() {
    super.initState();
    _pageTitle = widget.title ?? '';
    _initializeWebView();
  }

  void _initializeWebView() {
    // БЕЗОПАСНОСТЬ: Валидация URL перед загрузкой (CWE-79, CWE-749)
    final validationResult = UrlValidator.validate(widget.url);

    if (!validationResult.isValid) {
      // URL не прошел валидацию - показываем ошибку
      setState(() {
        _hasValidationError = true;
        _validationError = validationResult.errorMessage;
        _isLoading = false;
      });
      return;
    }

    // URL валиден - инициализируем WebView
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          // БЕЗОПАСНОСТЬ: Проверяем каждый запрос навигации
          onNavigationRequest: (NavigationRequest request) {
            final requestValidation = UrlValidator.validate(request.url);

            // Блокируем опасные URL при попытке навигации
            if (!requestValidation.isValid) {
              setState(() {
                _hasValidationError = true;
                _validationError = null; // Will use l10n.unsafeUrlBlocked in _buildErrorView
              });
              return NavigationDecision.prevent;
            }

            // Разрешаем навигацию для безопасных URL
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _loadingProgress = 0;
            });
          },
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _loadingProgress = 1;
            });
            // Получаем заголовок страницы
            _controller.getTitle().then((title) {
              if (title != null && title.isNotEmpty) {
                setState(() {
                  _pageTitle = title;
                });
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            // Ошибки загрузки ресурсов обрабатываются WebView
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Виджет для отображения ошибки валидации URL
  Widget _buildErrorView() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: _backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Иконка ошибки
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.shield_slash,
                  size: 40,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 24),

              // Заголовок
              Text(
                l10n.unsafeUrl,
                style: TextStyle(
                  color: _primaryTextColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Сообщение об ошибке
              Text(
                _validationError ?? l10n.contentLoadFailed,
                style: TextStyle(
                  color: _primaryTextColor.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Дополнительная информация
              Text(
                l10n.videoBlockedForSafety,
                style: TextStyle(
                  color: _primaryTextColor.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Кнопка закрытия
              CupertinoButton.filled(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: Text(l10n.closeButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.5, 0.95],
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Индикатор для перетаскивания
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _primaryTextColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),

            // Заголовок и кнопка закрытия
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Кнопка закрытия
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _primaryTextColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        color: _primaryTextColor,
                        size: 16,
                      ),
                    ),
                  ),

                  // Заголовок
                  Expanded(
                    child: Center(
                      child: Text(
                        _pageTitle.isNotEmpty ? _pageTitle : l10n.loadingText,
                        style: TextStyle(
                          color: _primaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Пустое место для баланса
                  const SizedBox(width: 32),
                ],
              ),
            ),

            // Progress bar
            if (_isLoading)
              LinearProgressIndicator(
                value: _loadingProgress,
                backgroundColor: _primaryTextColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isDarkMode ? AppColors.accent : AppColors.lightAccent,
                ),
                minHeight: 2,
              ),

            const Divider(height: 1),

            // WebView или сообщение об ошибке
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                child: _hasValidationError
                    ? _buildErrorView()
                    : WebViewWidget(controller: _controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}