import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/source_validation_models.dart';
import '../../models/subscription_models.dart';
import '../../services/locale_service.dart';
import '../../services/news_service.dart';
import '../../services/theme_service.dart';
import '../../services/suggestion_service.dart';
import '../../services/subscription_service.dart';
import '../../models/suggestion_models.dart';
import '../../theme/colors.dart';
import '../ai_view_selector.dart';
import '../limit_reached_modal.dart';
import '../telegram_icon.dart';

/// Slide 2: Sources input only.
/// AI View selection moved to slide 3 (advanced settings).
class SlideContent extends StatefulWidget {
  final LocaleService localeService;
  final List<ValidatedSource> sources;
  final ValueChanged<List<ValidatedSource>> onSourcesChanged;
  final AIViewStyle viewStyle;
  final ValueChanged<AIViewStyle> onViewStyleChanged;
  final String? customPrompt;
  final ValueChanged<String?> onCustomPromptChanged;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const SlideContent({
    super.key,
    required this.localeService,
    required this.sources,
    required this.onSourcesChanged,
    required this.viewStyle,
    required this.onViewStyleChanged,
    this.customPrompt,
    required this.onCustomPromptChanged,
    this.onNext,
    this.onBack,
  });

  @override
  State<SlideContent> createState() => _SlideContentState();
}

class _SlideContentState extends State<SlideContent>
    with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();

  late AnimationController _entranceController;
  bool _isInputVisible = true;

  // Popular sources from API
  List<Suggestion> get _popularSources => SuggestionService().sources;

  bool get _isRu => widget.localeService.currentLocale.languageCode == 'ru';
  bool get _isDark => ThemeService().isDarkMode;
  bool get _isValidating => widget.sources.any(
      (s) => s.status == SourceValidationStatus.validating);

  void _onFocusChange() {
    if (!_inputFocusNode.hasFocus) {
      _addSource(_inputController.text);
    }
  }

  @override
  void initState() {
    super.initState();
    _isInputVisible = widget.sources.isEmpty;

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _inputFocusNode.addListener(_onFocusChange);
    _entranceController.forward();
  }

  @override
  void didUpdateWidget(SlideContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Скрыть поле если добавился источник
    if (widget.sources.length > oldWidget.sources.length && widget.sources.isNotEmpty) {
      setState(() => _isInputVisible = false);
    }
    // Показать поле если все источники удалены
    if (widget.sources.isEmpty && !_isInputVisible) {
      setState(() => _isInputVisible = true);
    }
  }

  @override
  void dispose() {
    _inputFocusNode.removeListener(_onFocusChange);
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _addSource(String input) {
    final source = input.trim();
    if (source.isEmpty) return;

    if (widget.sources.any((s) => s.originalInput == source)) {
      _inputController.clear();
      return;
    }

    // Check source limit before adding
    final validCount = widget.sources.where((s) =>
      s.status == SourceValidationStatus.valid ||
      s.status == SourceValidationStatus.validating
    ).length;

    if (!SubscriptionService().canAddMore(LimitType.sources, validCount)) {
      LimitReachedModal.show(
        context: context,
        limitType: LimitType.sources,
        currentCount: validCount,
        isRu: _isRu,
      );
      _inputController.clear();
      return;
    }

    final newSources = List<ValidatedSource>.from(widget.sources);
    newSources.add(ValidatedSource(
      originalInput: source,
      status: SourceValidationStatus.validating,
    ));
    widget.onSourcesChanged(newSources);
    _inputController.clear();
    HapticFeedback.selectionClick();

    _validateSource(source, newSources.length - 1);
  }

  Future<void> _validateSource(String source, int index) async {
    try {
      final response = await NewsService.validateSource(source);

      if (!mounted) return;

      final currentSources = List<ValidatedSource>.from(widget.sources);
      if (index >= currentSources.length ||
          currentSources[index].originalInput != source) {
        return;
      }

      if (response == null) {
        final l10n = AppLocalizations.of(context);
        currentSources[index] = currentSources[index].copyWith(
          status: SourceValidationStatus.error,
          errorMessage: l10n?.feedEditNetworkError ?? 'Network error',
        );
        widget.onSourcesChanged(currentSources);
      } else if (!response.isValid) {
        final l10n = AppLocalizations.of(context);
        currentSources[index] = currentSources[index].copyWith(
          status: SourceValidationStatus.invalid,
          errorMessage: l10n?.feedEditNotFound ?? 'Not found',
        );
        widget.onSourcesChanged(currentSources);
        HapticFeedback.heavyImpact();

        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _removeSource(index);
        });
      } else {
        currentSources[index] = currentSources[index].copyWith(
          status: SourceValidationStatus.valid,
          shortName: response.shortName,
          sourceType: response.sourceType,
        );
        widget.onSourcesChanged(currentSources);
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (!mounted) return;
      final currentSources = List<ValidatedSource>.from(widget.sources);
      if (index < currentSources.length &&
          currentSources[index].originalInput == source) {
        final l10n = AppLocalizations.of(context);
        currentSources[index] = currentSources[index].copyWith(
          status: SourceValidationStatus.error,
          errorMessage: l10n?.error ?? 'Error',
        );
        widget.onSourcesChanged(currentSources);
      }
    }
  }

  void _removeSource(int index) {
    final newSources = List<ValidatedSource>.from(widget.sources);
    if (index < newSources.length) {
      newSources.removeAt(index);
      widget.onSourcesChanged(newSources);
      HapticFeedback.selectionClick();
    }
  }

  void _retrySource(int index) {
    if (index < widget.sources.length) {
      final source = widget.sources[index];
      final newSources = List<ValidatedSource>.from(widget.sources);
      newSources[index] = source.copyWith(
        status: SourceValidationStatus.validating,
        errorMessage: null,
      );
      widget.onSourcesChanged(newSources);
      _validateSource(source.originalInput, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textColor = _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = _isDark ? AppColors.accent : AppColors.lightAccent;
    final surfaceColor = _isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = _isDark ? AppColors.accentSecondary : AppColors.lightAccentSecondary;

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    // GlassTabBar: 88px from screen bottom. Target: button at 100px from screen.
    // SafeArea adds bottomInset, so subtract it from target.
    final buttonBottom = (100.0 - bottomInset).clamp(12.0, 100.0);

    return SafeArea(
      child: Column(
        children: [
          // Back button at top left
          if (widget.onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: CupertinoButton(
                  padding: const EdgeInsets.all(12),
                  onPressed: widget.onBack,
                  child: Icon(
                    CupertinoIcons.chevron_back,
                    size: 24,
                    color: secondaryColor,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                // Scrollable content
                AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _entranceController.value,
                      child: child,
                    );
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Header
                        Text(
                          l10n.slideContentTitle,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.slideContentSubtitle,
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Input field with chips
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              // Поле ввода — показывать если нет источников ИЛИ _isInputVisible
                              if (widget.sources.isEmpty || _isInputVisible)
                                CupertinoTextField(
                                  controller: _inputController,
                                  focusNode: _inputFocusNode,
                                  placeholder: l10n.slideContentSourceHint,
                                  padding: const EdgeInsets.all(16),
                                  decoration: null,
                                  cursorColor: accentColor,
                                  style: TextStyle(color: textColor, fontSize: 16),
                                  placeholderStyle: TextStyle(
                                    color: secondaryColor.withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (value) {
                                    _addSource(value);
                                  },
                                  onTapOutside: (_) => _inputFocusNode.unfocus(),
                                ),

                              // Чипы + кнопка добавления
                              if (widget.sources.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(12, _isInputVisible ? 0 : 12, 12, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ...widget.sources.asMap().entries.map((entry) {
                                            return _CompactSourceChip(
                                              key: ValueKey('src_${entry.key}_${entry.value.originalInput}'),
                                              source: entry.value,
                                              onRemove: () => _removeSource(entry.key),
                                              onRetry: entry.value.status == SourceValidationStatus.error
                                                  ? () => _retrySource(entry.key)
                                                  : null,
                                              isDark: _isDark,
                                            );
                                          }),
                                          // Кнопка "+" для добавления нового источника
                                          if (!_isInputVisible)
                                            GestureDetector(
                                              onTap: () {
                                                setState(() => _isInputVisible = true);
                                                Future.delayed(const Duration(milliseconds: 100), () {
                                                  _inputFocusNode.requestFocus();
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: borderColor),
                                                ),
                                                child: Icon(CupertinoIcons.plus, size: 16, color: secondaryColor),
                                              ),
                                            ),
                                        ],
                                      ),
                                      // Error message below chips
                                      if (widget.sources.any((s) =>
                                          (s.status == SourceValidationStatus.invalid ||
                                           s.status == SourceValidationStatus.error) &&
                                          s.errorMessage != null))
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            widget.sources.firstWhere((s) =>
                                              s.status == SourceValidationStatus.invalid ||
                                              s.status == SourceValidationStatus.error
                                            ).errorMessage!,
                                            style: const TextStyle(
                                              color: CupertinoColors.destructiveRed,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Popular suggestions - only show if not empty
                        if (_popularSources.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            l10n.slideContentPopular,
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _popularSources.map((source) {
                              final isAdded = widget.sources.any((s) => s.originalInput == source.value);

                              return GestureDetector(
                                onTap: isAdded
                                    ? () {
                                        final index = widget.sources
                                            .indexWhere((s) => s.originalInput == source.value);
                                        if (index >= 0) _removeSource(index);
                                      }
                                    : () => _addSource(source.value),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isAdded ? accentColor.withOpacity(0.15) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isAdded ? accentColor : borderColor,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Type icon
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: _getSourceTypeIcon(
                                          source.sourceType ?? 'TELEGRAM',
                                          size: 14,
                                          color: isAdded ? accentColor : secondaryColor,
                                          isDark: _isDark,
                                        ),
                                      ),
                                      if (isAdded) ...[
                                        Icon(CupertinoIcons.checkmark, size: 14, color: accentColor),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        source.getDisplayName(_isRu ? 'ru' : 'en'),
                                        style: TextStyle(
                                          color: isAdded ? accentColor : textColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 160), // Space for floating button
                      ],
                    ),
                  ),
                ),

                // Floating button - dynamic offset for old Android (hardware buttons)
                if (widget.onNext != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: buttonBottom,
                    child: _NextButton(
                      label: l10n.slideNext,
                      onTap: widget.onNext!,
                      accentColor: accentColor,
                      disabledColor: secondaryColor.withOpacity(0.3),
                      isDark: _isDark,
                      enabled: !_isValidating,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Transparent color for border
class Colors {
  static const transparent = Color(0x00000000);
}

/// Reusable Next button with animation
class _NextButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color accentColor;
  final Color disabledColor;
  final bool isDark;
  final bool enabled;

  const _NextButton({
    required this.label,
    required this.onTap,
    required this.accentColor,
    required this.disabledColor,
    required this.isDark,
    this.enabled = true,
  });

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.enabled) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_NextButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Transform.scale(
        scale: widget.enabled ? _pulseAnimation.value : 1.0,
        child: child,
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        borderRadius: BorderRadius.circular(14),
        color: widget.enabled ? widget.accentColor : widget.disabledColor,
        onPressed: widget.enabled ? widget.onTap : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                color: widget.isDark
                    ? CupertinoColors.black
                    : CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.arrow_right,
              size: 18,
              color: widget.isDark
                  ? CupertinoColors.black
                  : CupertinoColors.white,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact source chip for slide 2
class _CompactSourceChip extends StatefulWidget {
  final ValidatedSource source;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;
  final bool isDark;

  const _CompactSourceChip({
    super.key,
    required this.source,
    required this.onRemove,
    this.onRetry,
    required this.isDark,
  });

  @override
  State<_CompactSourceChip> createState() => _CompactSourceChipState();
}

class _CompactSourceChipState extends State<_CompactSourceChip>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _shakeController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );
    _entranceController.forward();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5, end: -3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3, end: 0), weight: 1),
    ]).animate(_shakeController);

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    if (widget.source.status == SourceValidationStatus.validating) {
      _shimmerController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_CompactSourceChip oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.source.status != widget.source.status) {
      if (widget.source.status == SourceValidationStatus.validating) {
        _shimmerController.repeat(reverse: true);
      } else {
        _shimmerController.stop();
        _shimmerController.value = 0;
      }

      if (widget.source.status == SourceValidationStatus.invalid ||
          widget.source.status == SourceValidationStatus.error) {
        _shakeController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shakeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _handleRemove() async {
    HapticFeedback.selectionClick();
    await _entranceController.reverse();
    widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final isValidating = widget.source.status == SourceValidationStatus.validating;
    final isError = widget.source.status == SourceValidationStatus.error;
    final isInvalid = widget.source.status == SourceValidationStatus.invalid;
    final isValid = widget.source.status == SourceValidationStatus.valid;

    final textColor = widget.isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = widget.isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = widget.isDark ? AppColors.accent : AppColors.lightAccent;
    final bgColor = widget.isDark ? AppColors.background : AppColors.lightBackground;

    Color chipBorderColor = widget.isDark
        ? AppColors.accentSecondary
        : AppColors.lightAccentSecondary;
    if (isError || isInvalid) {
      chipBorderColor = CupertinoColors.destructiveRed.withOpacity(0.6);
    } else if (isValid) {
      chipBorderColor = accentColor.withOpacity(0.5);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _shakeAnimation, _shimmerController]),
      builder: (context, child) {
        final shimmerOpacity = isValidating ? 0.6 + 0.4 * _shimmerController.value : 1.0;

        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(opacity: shimmerOpacity, child: child),
          ),
        );
      },
      child: GestureDetector(
        onTap: isError ? widget.onRetry : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: chipBorderColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isValidating)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CupertinoActivityIndicator(radius: 5),
                  ),
                )
              else if (isValid)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _getSourceTypeIcon(
                    widget.source.sourceType,
                    size: 14,
                    color: accentColor,
                    isDark: widget.isDark,
                  ),
                )
              else if (isError || isInvalid)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    size: 14,
                    color: CupertinoColors.destructiveRed,
                  ),
                ),

              Flexible(
                child: Text(
                  widget.source.displayName,
                  style: TextStyle(
                    color: (isError || isInvalid) ? CupertinoColors.destructiveRed : textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 4),

              GestureDetector(
                onTap: _handleRemove,
                child: Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: secondaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper to get icon widget for source type
Widget _getSourceTypeIcon(String? sourceType, {required double size, required Color color, required bool isDark}) {
  switch (sourceType?.toUpperCase()) {
    case 'TELEGRAM':
      return TelegramIcon(size: size, isDark: isDark, color: color);
    case 'RSS':
      return Icon(CupertinoIcons.antenna_radiowaves_left_right, size: size, color: color);
    case 'WEBSITE':
      return Icon(CupertinoIcons.globe, size: size, color: color);
    default:
      return Icon(CupertinoIcons.link, size: size, color: color);
  }
}

