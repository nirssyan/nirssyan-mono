import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../models/subscription_models.dart';
import '../services/subscription_service.dart';
import '../theme/colors.dart';
import '../l10n/generated/app_localizations.dart';

/// Beautiful glassmorphism modal for subscription limit warnings.
class LimitReachedModal {
  /// Shows the limit reached modal for a specific limit type.
  static Future<void> show({
    required BuildContext context,
    required LimitType limitType,
    required int currentCount,
    required bool isRu,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final contentColor = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;
    final cardBackground = isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.08)
        : const Color(0xFFFFFFFF).withOpacity(0.92);
    final borderColor = isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.2)
        : const Color(0xFF000000).withOpacity(0.08);
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;

    final limit = SubscriptionService().getLimit(limitType);
    final icon = _getIcon(limitType);
    final title = _getTitle(limitType, l10n);
    final message = _getMessage(limitType, limit, l10n);
    final telegramHint = l10n.limitMoreFeaturesSoon;
    final buttonText = l10n.limitGotIt;

    await showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(isDark ? 0.35 : 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon container
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor.withOpacity(0.2),
                              accentColor.withOpacity(0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(icon, color: accentColor, size: 26),
                      ),
                      const SizedBox(height: 14),

                      // Title
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Message
                      Text(
                        message,
                        style: TextStyle(
                          color: contentColor,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),

                      // Hint - subtle text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            size: 14,
                            color: contentColor.withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            telegramHint,
                            style: TextStyle(
                              color: contentColor.withOpacity(0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Got it button
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: accentColor,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              buttonText,
                              style: TextStyle(
                                color: isDark ? CupertinoColors.black : CupertinoColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static IconData _getIcon(LimitType limitType) {
    switch (limitType) {
      case LimitType.sources:
        return CupertinoIcons.link;
      case LimitType.filters:
        return CupertinoIcons.slider_horizontal_3;
      case LimitType.styles:
        return CupertinoIcons.paintbrush;
      case LimitType.feeds:
        return CupertinoIcons.square_stack_3d_up;
    }
  }

  static String _getTitle(LimitType limitType, AppLocalizations l10n) {
    switch (limitType) {
      case LimitType.sources:
        return l10n.limitSourcesTitle;
      case LimitType.filters:
        return l10n.limitFiltersTitle;
      case LimitType.styles:
        return l10n.limitStylesTitle;
      case LimitType.feeds:
        return l10n.limitFeedsTitle;
    }
  }

  static String _getMessage(LimitType limitType, int limit, AppLocalizations l10n) {
    switch (limitType) {
      case LimitType.sources:
        return l10n.limitSourcesMessage(limit);
      case LimitType.filters:
        return l10n.limitFiltersMessage(limit);
      case LimitType.styles:
        return l10n.limitStylesMessage(limit);
      case LimitType.feeds:
        return l10n.limitFeedsMessage(limit);
    }
  }
}
