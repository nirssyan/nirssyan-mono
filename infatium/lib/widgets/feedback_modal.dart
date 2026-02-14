import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:async';
import 'dart:ui';

import '../theme/colors.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/feedback_service.dart';
import '../services/analytics_service.dart';
import '../models/analytics_event_schema.dart';

/// Minimalistic feedback modal with SwiftUI-like sheet behavior
class FeedbackModal extends StatefulWidget {
  const FeedbackModal({super.key});

  @override
  State<FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<FeedbackModal>
    with SingleTickerProviderStateMixin {
  // Controllers
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Services
  final FeedbackService _feedbackService = FeedbackService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Animation controller (only for success state)
  late AnimationController _successController;
  late Animation<double> _successScaleAnimation;

  // State
  bool _showSuccess = false;
  int _characterCount = 0;
  static const int _maxCharacters = 250;
  Timer? _dismissTimer;
  Timer? _rateLimitTimer;

  @override
  void initState() {
    super.initState();

    _setupAnimations();

    _textController.addListener(_onTextChanged);
    _feedbackService.addListener(_onServiceStateChanged);

    _analyticsService.capture(EventSchema.feedbackModalOpened);
  }

  void _setupAnimations() {
    _successController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _successScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.easeOutBack,
    ));
  }

  void _onTextChanged() {
    setState(() {
      _characterCount = _textController.text.length;
    });
  }

  void _onServiceStateChanged() {
    if (mounted) {
      setState(() {});

      if (!_feedbackService.canSubmit && _rateLimitTimer == null) {
        _startRateLimitTimer();
      }
    }
  }

  void _startRateLimitTimer() {
    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_feedbackService.canSubmit) {
        timer.cancel();
        _rateLimitTimer = null;
      }

      setState(() {});
    });
  }

  Future<void> _handleSubmit() async {
    final message = _textController.text.trim();
    if (message.isEmpty) {
      HapticFeedback.lightImpact();
      return;
    }

    _focusNode.unfocus();
    HapticFeedback.heavyImpact();

    final success = await _feedbackService.submitFeedback(message);

    if (success && mounted) {
      setState(() {
        _showSuccess = true;
      });

      _successController.forward();
      _textController.clear();
      _startRateLimitTimer();

      _dismissTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _closeModal();
        }
      });
    } else if (!success && mounted) {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _closeModal() async {
    _dismissTimer?.cancel();
    _rateLimitTimer?.cancel();

    _analyticsService.capture(EventSchema.feedbackModalClosed, properties: {
      'closed_by_user': true,
      'time_open_seconds': 0, // TODO: Track modal open time if needed
    });

    if (_showSuccess) {
      _feedbackService.resetRateLimit();
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _rateLimitTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    _feedbackService.removeListener(_onServiceStateChanged);
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    // Padding поднимает модалку над клавиатурой
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            // Фиксированная высота для стабильного layout
            height: 340,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.92),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.08),
                  width: 1,
                ),
              ),
            ),
            child: _showSuccess
                ? _buildSuccessView(l10n, isDark, textColor, secondaryTextColor)
                : _buildFormView(l10n, isDark, textColor, secondaryTextColor),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(
    AppLocalizations l10n,
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3A3A3C)
                      : CupertinoColors.systemGrey3,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l10n.shareYourFeedback,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Text field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildTextField(l10n, isDark, textColor, secondaryTextColor),
          ),

          // Character counter
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 20),
            child: _buildCharacterCounter(secondaryTextColor),
          ),

          // Error message
          if (_feedbackService.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
              child: _buildErrorMessage(),
            ),

          const SizedBox(height: 24),

          // Submit button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSubmitButton(l10n, isDark),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 20),
        ],
      ),
    );
  }

  Widget _buildTextField(
    AppLocalizations l10n,
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return CupertinoTextField(
      controller: _textController,
      focusNode: _focusNode,
      cursorColor: textColor,
      placeholder: l10n.feedbackPlaceholder,
      placeholderStyle: TextStyle(
        color: secondaryTextColor.withOpacity(0.6),
        fontSize: 16,
      ),
      style: TextStyle(
        color: textColor,
        fontSize: 16,
        height: 1.4,
      ),
      maxLines: null,
      minLines: 3,
      maxLength: _maxCharacters,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3A3A3C)
              : CupertinoColors.systemGrey4,
          width: 0.5,
        ),
      ),
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      autofocus: true,
      enabled: !_feedbackService.isSubmitting,
      onTapOutside: (_) => _focusNode.unfocus(),
    );
  }

  Widget _buildCharacterCounter(Color secondaryTextColor) {
    final percentage = _characterCount / _maxCharacters;

    Color counterColor;
    if (percentage < 0.7) {
      counterColor = secondaryTextColor;
    } else if (percentage < 0.9) {
      counterColor = CupertinoColors.systemOrange;
    } else {
      counterColor = CupertinoColors.destructiveRed;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$_characterCount / $_maxCharacters',
          style: TextStyle(
            color: counterColor.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.destructiveRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: CupertinoColors.destructiveRed,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _feedbackService.errorMessage!,
              style: const TextStyle(
                color: CupertinoColors.destructiveRed,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n, bool isDark) {
    final hasText = _textController.text.trim().isNotEmpty;
    final isSubmitting = _feedbackService.isSubmitting;
    final isRateLimited = !_feedbackService.canSubmit;
    final secondsLeft = _feedbackService.secondsUntilCanSubmit;

    // Button looks active when has text (even during submission)
    final isActive = hasText && !isRateLimited;
    // But can only press when not submitting
    final canPress = isActive && !isSubmitting;

    return GestureDetector(
      onTap: canPress ? _handleSubmit : null,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: isSubmitting
              ? LoadingAnimationWidget.staggeredDotsWave(
                  color: isDark ? CupertinoColors.black : CupertinoColors.white,
                  size: 22,
                )
              : isRateLimited
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.timer,
                          color: isDark
                              ? const Color(0xFF8E8E93)
                              : CupertinoColors.systemGrey,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Wait $secondsLeft s',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF8E8E93)
                                : CupertinoColors.systemGrey,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      l10n.sendFeedback,
                      style: TextStyle(
                        color: isActive
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark
                                ? const Color(0xFF8E8E93)
                                : CupertinoColors.systemGrey),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(
    AppLocalizations l10n,
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              ScaleTransition(
                scale: _successScaleAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.checkmark,
                    color: CupertinoColors.activeGreen,
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Success title
              Text(
                l10n.feedbackSent,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 8),

              // Success message
              Text(
                l10n.feedbackSentMessage,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
