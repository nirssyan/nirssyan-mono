import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/colors.dart';

class ConfirmationModal {
  /// Shows a custom confirmation modal with icon, title, message and action buttons
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    bool isDestructive = false,
    bool isConfirmEnabled = true,
    Color? iconColor,
    Widget? customIcon,
  }) {
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

    final effectiveIconColor =
        iconColor ??
        (isDestructive ? CupertinoColors.destructiveRed : titleColor);

    return showCupertinoDialog<bool>(
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
                        color: const Color(
                          0xFF000000,
                        ).withOpacity(isDark ? 0.35 : 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: effectiveIconColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: effectiveIconColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: customIcon ?? Icon(icon, color: effectiveIconColor, size: 22),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: contentColor,
                          fontSize: 15,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1,
                                  ),
                                  color: CupertinoColors.transparent,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  cancelText,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Opacity(
                              opacity: isConfirmEnabled ? 1.0 : 0.4,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: isConfirmEnabled
                                    ? () => Navigator.of(context).pop(true)
                                    : null,
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: isDestructive
                                        ? CupertinoColors.destructiveRed
                                        : (isDark
                                              ? AppColors.accent
                                              : AppColors.lightAccent),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    confirmText,
                                    style: TextStyle(
                                      color: isDark ? CupertinoColors.black : CupertinoColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

  /// Shows a custom alert modal with icon, title, message and single OK button
  static Future<void> showAlert({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    Color? iconColor,
  }) async {
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

    final effectiveIconColor = iconColor ?? titleColor;

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
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: effectiveIconColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: effectiveIconColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(icon, color: effectiveIconColor, size: 22),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: contentColor,
                          fontSize: 15,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark ? AppColors.accent : AppColors.lightAccent,
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

  /// Shows a custom input modal with text field
  static Future<String?> showTextInput({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String placeholder,
    required String confirmText,
    required String cancelText,
    String? initialText,
    String? Function(String)? validator,
    Color? iconColor,
  }) {
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

    final effectiveIconColor = iconColor ?? titleColor;
    final textController = TextEditingController(text: initialText);

    return showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setState) {
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
                            color: const Color(
                              0xFF000000,
                            ).withOpacity(isDark ? 0.35 : 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: effectiveIconColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: effectiveIconColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: effectiveIconColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CupertinoTextField(
                            controller: textController,
                            placeholder: placeholder,
                            placeholderStyle: TextStyle(
                              color: contentColor.withOpacity(0.6),
                            ),
                            style: TextStyle(color: titleColor, fontSize: 16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.accent.withOpacity(0.5) : borderColor, width: 1),
                            ),
                            cursorColor: isDark ? AppColors.accent : AppColors.lightAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
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
                                color: CupertinoColors.destructiveRed,
                                fontSize: 14,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () =>
                                      Navigator.of(context).pop(null),
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: borderColor,
                                        width: 1,
                                      ),
                                      color: CupertinoColors.transparent,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      cancelText,
                                      style: TextStyle(
                                        color: titleColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    final text = textController.text.trim();
                                    if (validator != null) {
                                      final error = validator(text);
                                      if (error != null) {
                                        setState(() {
                                          errorMessage = error;
                                        });
                                        return;
                                      }
                                    }
                                    Navigator.of(context).pop(text);
                                  },
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: isDark
                                          ? AppColors.accent
                                          : AppColors.lightAccent,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      confirmText,
                                      style: TextStyle(
                                        color: isDark ? AppColors.lightTextPrimary : CupertinoColors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      },
    );
  }

  /// Shows a custom loading modal
  static void showLoading(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.08)
        : const Color(0xFFFFFFFF).withOpacity(0.92);
    final borderColor = isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.2)
        : const Color(0xFF000000).withOpacity(0.08);

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF000000,
                    ).withOpacity(isDark ? 0.35 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: CupertinoActivityIndicator(radius: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
