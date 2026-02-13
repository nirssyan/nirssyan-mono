import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../services/news_service.dart';
import '../services/analytics_service.dart';
import '../models/analytics_event_schema.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/feed_models.dart';

class FeedManagementService {
  static final _instance = FeedManagementService._internal();
  factory FeedManagementService() => _instance;
  FeedManagementService._internal();

  /// Показывает action sheet с опциями управления лентой
  Future<void> showFeedManagementSheet({
    required BuildContext context,
    required Feed feed,
    required VoidCallback onFeedDeleted,
    required VoidCallback onFeedRenamed,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    
    // Haptic feedback for long press
    HapticFeedback.mediumImpact();
    
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(l10n.feedManagement),
          message: Text(feed.name),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                _showRenameFeedDialog(
                  context: context,
                  feed: feed,
                  onRenamed: onFeedRenamed,
                );
              },
              child: Text(l10n.renameFeed),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(context).pop();
                _showDeleteFeedDialog(
                  context: context,
                  feed: feed,
                  onDeleted: onFeedDeleted,
                );
              },
              child: Text(l10n.deleteFeed),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        );
      },
    );
  }

  /// Показывает диалог переименования ленты
  Future<void> _showRenameFeedDialog({
    required BuildContext context,
    required Feed feed,
    required VoidCallback onRenamed,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final textController = TextEditingController(text: feed.name);
    String? errorMessage;

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return CupertinoAlertDialog(
              title: Text(l10n.renameFeed),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: textController,
                    placeholder: l10n.enterNewName,
                    autofocus: true,
                    onChanged: (value) {
                      if (errorMessage != null) {
                        setState(() {
                          errorMessage = null;
                        });
                      }
                    },
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                CupertinoDialogAction(
                  onPressed: () async {
                    final newName = textController.text.trim();
                    if (newName.isEmpty) {
                      setState(() {
                        errorMessage = l10n.feedNameRequired;
                      });
                      return;
                    }

                    // Закрываем диалог
                    Navigator.of(context).pop();
                    
                    // Показываем индикатор загрузки
                    showCupertinoDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const CupertinoAlertDialog(
                        content: CupertinoActivityIndicator(),
                      ),
                    );

                    try {
                      final success = await NewsService.renameFeed(feed.id, newName);
                      
                      // Закрываем индикатор загрузки
                      Navigator.of(context).pop();
                      
                      if (success) {
                        // Analytics
                        AnalyticsService().capture(
                          EventSchema.feedRenamed,
                          properties: {
                            'feed_id': feed.id,
                          },
                        );
                        
                        // Success feedback
                        HapticFeedback.lightImpact();
                        _showSuccessMessage(context, l10n.feedRenamed);
                        onRenamed();
                      } else {
                        // Error feedback
                        HapticFeedback.heavyImpact();
                        _showErrorMessage(context, l10n.errorRenamingFeed);
                      }
                    } catch (e) {
                      // Закрываем индикатор загрузки в случае ошибки
                      Navigator.of(context).pop();
                      HapticFeedback.heavyImpact();
                      _showErrorMessage(context, l10n.errorRenamingFeed);
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Показывает диалог подтверждения удаления ленты
  Future<void> _showDeleteFeedDialog({
    required BuildContext context,
    required Feed feed,
    required VoidCallback onDeleted,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(l10n.confirmDeleteFeed),
          content: Text(l10n.confirmDeleteFeedMessage),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                // Закрываем диалог подтверждения
                Navigator.of(context).pop();
                
                // Показываем индикатор загрузки
                showCupertinoDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const CupertinoAlertDialog(
                    content: CupertinoActivityIndicator(),
                  ),
                );

                try {
                  final success = await NewsService.deleteFeedSubscription(feed.id);
                  
                  // Закрываем индикатор загрузки
                  Navigator.of(context).pop();
                  
                  if (success) {
                    // Analytics
                    AnalyticsService().capture(
                      EventSchema.feedDeleted,
                      properties: {
                        'feed_id': feed.id,
                      },
                    );
                    
                    // Success feedback
                    HapticFeedback.lightImpact();
                    _showSuccessMessage(context, l10n.feedDeleted);
                    onDeleted();
                  } else {
                    // Error feedback
                    HapticFeedback.heavyImpact();
                    _showErrorMessage(context, l10n.errorDeletingFeed);
                  }
                } catch (e) {
                  // Закрываем индикатор загрузки в случае ошибки
                  Navigator.of(context).pop();
                  HapticFeedback.heavyImpact();
                  _showErrorMessage(context, l10n.errorDeletingFeed);
                }
              },
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
  }

  /// Показывает сообщение об успехе
  void _showSuccessMessage(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // Автоматически закрыть через 2 секунды
    Future.delayed(const Duration(seconds: 2), () {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Показывает сообщение об ошибке
  void _showErrorMessage(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
