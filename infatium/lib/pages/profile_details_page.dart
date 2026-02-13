import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../models/analytics_event_schema.dart';
import '../l10n/generated/app_localizations.dart';
import 'profile_page.dart'; // For ProfileAvatar

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({super.key});

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  final AuthService _authService = AuthService();

  void _showDeleteAccountDialog() {
    HapticFeedback.mediumImpact();
    AnalyticsService().capture(EventSchema.deleteAccountButtonTapped);

    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _DeleteAccountConfirmDialog(
          isDark: isDark,
          l10n: l10n,
          onConfirm: _deleteAccount,
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    // Show loading dialog
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(radius: 16),
                const SizedBox(height: 16),
                Text(
                  l10n.deleteAccountProcessing,
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final result = await _authService.deleteAccount();

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (result.success) {
        // Account deleted successfully, user is already signed out
        // Clear navigation stack to return to root, where AuthWrapper will show AuthPage
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        // Show error dialog
        _showErrorDialog(result.error ?? l10n.deleteAccountError);
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      _showErrorDialog(l10n.deleteAccountError);
    }
  }

  void _showErrorDialog(String error) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final contentColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final cardBackground = isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.08)
        : const Color(0xFFFFFFFF).withOpacity(0.92);
    final borderColor = isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.2)
        : const Color(0xFF000000).withOpacity(0.08);

    showCupertinoDialog(
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
                          color: CupertinoColors.destructiveRed.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CupertinoColors.destructiveRed.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.exclamationmark_circle,
                          color: CupertinoColors.destructiveRed,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.error,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        error,
                        style: TextStyle(
                          color: contentColor,
                          fontSize: 15,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Container(
                          width: double.infinity,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isDark ? AppColors.accent : AppColors.lightAccent,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'OK',
                            style: TextStyle(
                              color: isDark ? AppColors.background : AppColors.lightBackground,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.background : AppColors.lightBackground;

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: backgroundColor.withOpacity(0.8),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(
            CupertinoIcons.back,
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
        middle: Text(
          l10n.profileDetails,
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 20, bottom: 100),
          children: [
            // Account info section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                l10n.accountInfo,
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const ProfileAvatar(size: 80),
                  const SizedBox(height: 16),
                  Text(
                    _authService.currentUser?.email ?? '',
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Danger Zone section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                l10n.dangerZone,
                style: const TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CupertinoColors.destructiveRed.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showDeleteAccountDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: CupertinoColors.destructiveRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.trash,
                          size: 18,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.deleteAccount,
                          style: const TextStyle(
                            color: CupertinoColors.destructiveRed,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: CupertinoColors.destructiveRed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delete Account Confirmation Dialog with 5-second timer
class _DeleteAccountConfirmDialog extends StatefulWidget {
  final bool isDark;
  final AppLocalizations l10n;
  final VoidCallback onConfirm;

  const _DeleteAccountConfirmDialog({
    required this.isDark,
    required this.l10n,
    required this.onConfirm,
  });

  @override
  State<_DeleteAccountConfirmDialog> createState() => _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState extends State<_DeleteAccountConfirmDialog> {
  Timer? _timer;
  int _secondsRemaining = 5;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _secondsRemaining = 0;
          _isButtonEnabled = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final contentColor = widget.isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final cardBackground = widget.isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.08)
        : const Color(0xFFFFFFFF).withOpacity(0.92);
    final borderColor = widget.isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.2)
        : const Color(0xFF000000).withOpacity(0.08);

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
                    color: const Color(0xFF000000).withOpacity(widget.isDark ? 0.35 : 0.06),
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
                      color: CupertinoColors.destructiveRed.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CupertinoColors.destructiveRed.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      color: CupertinoColors.destructiveRed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.l10n.deleteAccountConfirmTitle,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.l10n.deleteAccountConfirmMessage,
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
                          onPressed: () => Navigator.of(context).pop(),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: 1),
                              color: CupertinoColors.transparent,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.l10n.cancel,
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
                          onPressed: _isButtonEnabled
                              ? () {
                                  Navigator.of(context).pop();
                                  widget.onConfirm();
                                }
                              : null,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: _isButtonEnabled
                                  ? CupertinoColors.destructiveRed
                                  : CupertinoColors.destructiveRed.withOpacity(0.3),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _isButtonEnabled
                                  ? widget.l10n.yes
                                  : widget.l10n.pleaseWaitSeconds(_secondsRemaining),
                              style: const TextStyle(
                                color: CupertinoColors.white,
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
  }
}
