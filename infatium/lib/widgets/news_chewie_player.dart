import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../services/theme_service.dart';
import '../models/media_object.dart';
import '../services/analytics_service.dart';
import '../models/analytics_event_schema.dart';
import '../utils/url_validator.dart';
import 'in_app_browser_modal.dart';
import '../l10n/generated/app_localizations.dart';

class NewsChewiePlayer extends StatefulWidget {
  final MediaObject mediaObject;
  final bool autoPlay;
  final double? aspectRatio;

  const NewsChewiePlayer({
    super.key,
    required this.mediaObject,
    this.autoPlay = false,
    this.aspectRatio,
  });

  @override
  State<NewsChewiePlayer> createState() => _NewsChewiePlayerState();
}

class _NewsChewiePlayerState extends State<NewsChewiePlayer> {
  bool _hasError = false;

  // Цвета темы
  bool get _isDarkMode => ThemeService().isDarkMode;
  Color get _primaryTextColor =>
      _isDarkMode ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _secondaryTextColor =>
      _isDarkMode ? AppColors.textSecondary : AppColors.lightTextSecondary;

  // Aspect ratio
  double get _aspectRatio {
    if (widget.aspectRatio != null) {
      return widget.aspectRatio!;
    }
    if (widget.mediaObject.width != null &&
        widget.mediaObject.height != null &&
        widget.mediaObject.height! > 0) {
      return widget.mediaObject.width! / widget.mediaObject.height!;
    }
    return 16 / 9; // Default aspect ratio
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Открыть видео в модальном in-app браузере (снизу вверх как в Perplexity)
  Future<void> _openVideoInBrowser() async {
    final videoUrl = widget.mediaObject.url;

    // БЕЗОПАСНОСТЬ: Pre-валидация URL перед открытием браузера
    final validationResult = UrlValidator.validate(videoUrl);

    if (!validationResult.isValid) {
      // URL небезопасен - показываем alert и не открываем браузер
      HapticFeedback.mediumImpact();

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        await showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(l10n.videoUnsafeUrl),
            content: Text(
              validationResult.errorMessage ?? l10n.videoUnsafeMessage,
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );

        setState(() {
          _hasError = true;
        });
      }

      return;
    }

    // URL валиден - продолжаем открытие браузера
    // Вибрация при клике
    HapticFeedback.mediumImpact();

    // Analytics: открытие видео в браузере
    AnalyticsService().capture(EventSchema.videoOpenedInBrowser, properties: {
      'video_url': videoUrl,
      'has_preview': widget.mediaObject.previewUrl != null,
    });

    final l10nForTitle = AppLocalizations.of(context)!;
    try {
      // Открываем модальный in-app браузер снизу вверх
      await InAppBrowserModal.show(
        context,
        videoUrl,
        title: l10nForTitle.videoTitle,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  Widget _buildPreview() {
    return GestureDetector(
      onTap: _hasError ? null : _openVideoInBrowser,
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Превью изображение
            if (widget.mediaObject.previewUrl != null)
              Image.network(
                widget.mediaObject.previewUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: _isDarkMode ? Colors.grey[900] : Colors.grey[200],
                    child: Center(
                      child: CupertinoActivityIndicator(
                        color: _primaryTextColor,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: _isDarkMode ? Colors.grey[900] : Colors.grey[200],
                    child: Center(
                      child: Icon(
                        CupertinoIcons.videocam,
                        size: 48,
                        color: _secondaryTextColor.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                color: _isDarkMode ? Colors.grey[900] : Colors.grey[200],
                child: Center(
                  child: Icon(
                    CupertinoIcons.videocam,
                    size: 48,
                    color: _secondaryTextColor.withValues(alpha: 0.5),
                  ),
                ),
              ),

            // Темный оверлей
            Container(
              color: Colors.black.withValues(alpha: 0.3),
            ),

            // Кнопка play (визуальный индикатор)
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: _hasError
                      ? const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: Colors.white,
                          size: 36,
                        )
                      : const Icon(
                          CupertinoIcons.play_fill,
                          color: Colors.white,
                          size: 36,
                        ),
                ),
              ),
            ),

            // Длительность видео в правом нижнем углу
            if (widget.mediaObject.formattedDuration != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.mediaObject.formattedDuration!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Всегда показываем превью с кнопкой play для открытия в браузере
    return _buildPreview();
  }
}