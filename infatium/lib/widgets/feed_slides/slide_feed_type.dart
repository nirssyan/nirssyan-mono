import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/feed_builder_models.dart';
import '../../services/locale_service.dart';
import '../../services/theme_service.dart';
import '../../theme/colors.dart';

/// Slide 1: Full-screen feed type selection with animated previews.
/// Two large glass cards that show how each feed type will display content.
/// Now includes frequency selector for DIGEST type.
class SlideFeedType extends StatefulWidget {
  final LocaleService localeService;
  final FeedType? selectedType;
  final ValueChanged<FeedType> onTypeSelected;
  final int digestIntervalHours;
  final ValueChanged<int> onIntervalChanged;
  final VoidCallback? onNext;

  const SlideFeedType({
    super.key,
    required this.localeService,
    required this.selectedType,
    required this.onTypeSelected,
    this.digestIntervalHours = 6,
    required this.onIntervalChanged,
    this.onNext,
  });

  @override
  State<SlideFeedType> createState() => _SlideFeedTypeState();
}

class _SlideFeedTypeState extends State<SlideFeedType>
    with SingleTickerProviderStateMixin {
  // Animation controller for selection pulse
  late AnimationController _selectionController;

  bool get _isRu => widget.localeService.currentLocale.languageCode == 'ru';
  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();

    // Selection pulse
    _selectionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  void _onTypeSelected(FeedType type) {
    HapticFeedback.mediumImpact();
    _selectionController.forward(from: 0);
    widget.onTypeSelected(type);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textColor = _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = _isDark ? AppColors.accent : AppColors.lightAccent;
    final backgroundColor = _isDark ? AppColors.background : AppColors.lightBackground;

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    // GlassTabBar: 88px from screen bottom. Target: button at 100px from screen.
    // SafeArea adds bottomInset, so subtract it from target.
    final buttonBottom = (100.0 - bottomInset).clamp(12.0, 100.0);

    return SafeArea(
      child: Column(
        children: [
          // Navigation bar with title
          Container(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 12,
            ),
            color: backgroundColor,
            child: Column(
              children: [
                Text(
                  l10n.slideFeedTypeTitle,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.slideFeedTypeSubtitle,
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // Scrollable content
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Feed type cards - compact side by side
                      Row(
                        children: [
                          Expanded(
                            child: _FeedTypeCompactCard(
                              type: FeedType.SINGLE_POST,
                              isSelected: widget.selectedType == FeedType.SINGLE_POST,
                              icon: CupertinoIcons.square_stack_3d_up,
                              title: l10n.slideFeedTypeIndividualPosts,
                              description: l10n.slideFeedTypeIndividualPostsDesc,
                              onTap: () => _onTypeSelected(FeedType.SINGLE_POST),
                              isDark: _isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeedTypeCompactCard(
                              type: FeedType.DIGEST,
                              isSelected: widget.selectedType == FeedType.DIGEST,
                              icon: CupertinoIcons.doc_text_fill,
                              title: l10n.slideFeedTypeDigest,
                              description: l10n.slideFeedTypeDigestDesc,
                              onTap: () => _onTypeSelected(FeedType.DIGEST),
                              isDark: _isDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Animated preview mockup
                      if (widget.selectedType != null)
                        _FeedPreviewSection(
                          feedType: widget.selectedType!,
                          isDark: _isDark,
                          isRu: _isRu,
                          l10n: l10n,
                        ),

                      // Frequency selector below preview (only for DIGEST)
                      if (widget.selectedType == FeedType.DIGEST) ...[
                        const SizedBox(height: 24),
                        _FrequencySelector(
                          localeService: widget.localeService,
                          selectedHours: widget.digestIntervalHours,
                          onHoursChanged: widget.onIntervalChanged,
                          isDark: _isDark,
                        ),
                      ],

                      const SizedBox(height: 160), // Space for floating button
                    ],
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
                      isDark: _isDark,
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

/// Compact feed type selection card (like in the screenshot)
class _FeedTypeCompactCard extends StatefulWidget {
  final FeedType type;
  final bool isSelected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isDark;

  const _FeedTypeCompactCard({
    required this.type,
    required this.isSelected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_FeedTypeCompactCard> createState() => _FeedTypeCompactCardState();
}

class _FeedTypeCompactCardState extends State<_FeedTypeCompactCard>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    // Subtle pulse animation for "alive" feeling
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = widget.isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = widget.isDark ? AppColors.accent : AppColors.lightAccent;
    final surfaceColor = widget.isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = widget.isDark ? AppColors.accentSecondary : AppColors.lightAccentSecondary;

    // Selected state colors
    final selectedBg = accentColor;
    final selectedText = widget.isDark ? CupertinoColors.black : CupertinoColors.white;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
        builder: (context, child) {
          // Subtle floating effect when not selected
          final floatOffset = widget.isSelected ? 0.0 : (2 * _pulseAnimation.value - 1) * 2;

          return Transform.translate(
            offset: Offset(0, floatOffset),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: 180, // Fixed height for consistency
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isSelected ? selectedBg : surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected ? selectedBg : borderColor,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with animated background
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? selectedText.withValues(alpha: 0.2)
                      : (widget.isDark
                          ? AppColors.background
                          : AppColors.lightBackground),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: widget.isSelected ? selectedText : accentColor,
                ),
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                widget.title,
                style: TextStyle(
                  color: widget.isSelected ? selectedText : textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Description - fixed height area
              Expanded(
                child: Text(
                  widget.description,
                  style: TextStyle(
                    color: widget.isSelected
                        ? selectedText.withValues(alpha: 0.8)
                        : secondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.1,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Selection indicator at bottom
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? selectedText
                      : CupertinoColors.transparent,
                  border: Border.all(
                    color: widget.isSelected ? selectedText : borderColor,
                    width: 2,
                  ),
                ),
                child: widget.isSelected
                    ? Icon(
                        CupertinoIcons.checkmark,
                        size: 14,
                        color: accentColor,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview section showing how posts will look
class _FeedPreviewSection extends StatefulWidget {
  final FeedType feedType;
  final bool isDark;
  final bool isRu;
  final AppLocalizations l10n;

  const _FeedPreviewSection({
    required this.feedType,
    required this.isDark,
    required this.isRu,
    required this.l10n,
  });

  @override
  State<_FeedPreviewSection> createState() => _FeedPreviewSectionState();
}

class _FeedPreviewSectionState extends State<_FeedPreviewSection>
    with TickerProviderStateMixin {
  late AnimationController _cardAnimController;
  late List<Animation<double>> _cardAnimations;
  late Animation<double> _mergeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playAnimation();
  }

  @override
  void didUpdateWidget(_FeedPreviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedType != oldWidget.feedType) {
      _cardAnimController.dispose();
      _setupAnimations();
      _playAnimation();
    }
  }

  void _setupAnimations() {
    _cardAnimController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    if (widget.feedType == FeedType.SINGLE_POST) {
      // Stagger cards appearing one by one
      _cardAnimations = List.generate(3, (i) {
        final start = i * 0.15;
        final end = start + 0.4;
        return Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _cardAnimController,
            curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutBack),
          ),
        );
      });
      _mergeAnimation = const AlwaysStoppedAnimation(0.0);
    } else {
      // Cards appear then merge into one
      _cardAnimations = List.generate(3, (i) {
        final start = i * 0.1;
        final end = start + 0.3;
        return Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _cardAnimController,
            curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
          ),
        );
      });
      _mergeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _cardAnimController,
          curve: const Interval(0.5, 1.0, curve: Curves.easeInOutCubic),
        ),
      );
    }
  }

  void _playAnimation() {
    _cardAnimController.forward();
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDark ? AppColors.surface : AppColors.lightSurface;
    final textColor = widget.isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = widget.isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final borderColor = widget.isDark ? AppColors.accentSecondary : AppColors.lightAccentSecondary;
    final accentColor = widget.isDark ? AppColors.accent : AppColors.lightAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview label
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.l10n.slidePostsPreview,
              style: TextStyle(
                color: secondaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Preview container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: AnimatedBuilder(
            animation: _cardAnimController,
            builder: (context, _) {
              if (widget.feedType == FeedType.SINGLE_POST) {
                return _buildSinglePostPreview(
                  textColor: textColor,
                  secondaryColor: secondaryColor,
                  borderColor: borderColor,
                );
              } else {
                return _buildDigestPreview(
                  textColor: textColor,
                  secondaryColor: secondaryColor,
                  borderColor: borderColor,
                  accentColor: accentColor,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePostPreview({
    required Color textColor,
    required Color secondaryColor,
    required Color borderColor,
  }) {
    return Column(
      children: List.generate(3, (index) {
        final animation = _cardAnimations[index];
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.9 + 0.1 * animation.value,
              child: Container(
                margin: EdgeInsets.only(bottom: index < 2 ? 6 : 0),
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.background
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    // Thumbnail placeholder
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        CupertinoIcons.photo,
                        size: 14,
                        color: secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Content placeholder
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 10,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 8,
                            width: 80,
                            decoration: BoxDecoration(
                              color: secondaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDigestPreview({
    required Color textColor,
    required Color secondaryColor,
    required Color borderColor,
    required Color accentColor,
  }) {
    final mergeProgress = _mergeAnimation.value;

    // Calculate positions for merge animation
    final cardHeight = 52.0;
    final cardSpacing = 8.0;

    return SizedBox(
      height: cardHeight * 3 + cardSpacing * 2,
      child: Stack(
        children: [
          // Three cards that merge into one
          ...List.generate(3, (index) {
            final cardAnim = _cardAnimations[index];

            // Position: start spread out, end at center
            final startY = index * (cardHeight + cardSpacing);
            final endY = (3 * (cardHeight + cardSpacing) - cardHeight) / 2;
            final currentY = startY + (endY - startY) * mergeProgress;

            // Scale down as they merge
            final scale = 1.0 - (0.1 * index * mergeProgress);

            // Opacity: first card stays, others fade
            final opacity = index == 0 ? 1.0 : (1.0 - mergeProgress);

            return Positioned(
              top: currentY,
              left: 0,
              right: 0,
              child: Transform.scale(
                scale: (0.9 + 0.1 * cardAnim.value) * scale,
                child: Opacity(
                  opacity: cardAnim.value * opacity,
                  child: Container(
                    height: cardHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.background
                          : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        // Small icon
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: borderColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            CupertinoIcons.doc_text,
                            size: 14,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 10,
                                width: 80 + index * 20.0,
                                decoration: BoxDecoration(
                                  color: textColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 8,
                                width: 50,
                                decoration: BoxDecoration(
                                  color: secondaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // Merged digest card (appears on merge)
          if (mergeProgress > 0.3)
            Positioned(
              top: (3 * (cardHeight + cardSpacing) - 80) / 2,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: ((mergeProgress - 0.3) / 0.7).clamp(0.0, 1.0),
                child: Container(
                  height: 80,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? AppColors.surface
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      // Digest icon - dark icon on light bg for contrast
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          CupertinoIcons.doc_text_fill,
                          size: 22,
                          // Contrasting color: white icon on dark accent, black icon on light accent
                          color: widget.isDark
                              ? CupertinoColors.black
                              : CupertinoColors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.l10n.slideDailyDigest,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.l10n.slidePostsCombined,
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable Next button with animation
class _NextButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isDark;

  const _NextButton({
    required this.label,
    required this.onTap,
    required this.accentColor,
    required this.isDark,
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
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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
        scale: _pulseAnimation.value,
        child: child,
      ),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 16),
          borderRadius: BorderRadius.circular(14),
          color: widget.accentColor,
          onPressed: widget.onTap,
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
      ),
    );
  }
}

/// Frequency selector for DIGEST type
class _FrequencySelector extends StatelessWidget {
  final LocaleService localeService;
  final int selectedHours;
  final ValueChanged<int> onHoursChanged;
  final bool isDark;

  // Preset options in hours
  static const List<int> _presetHours = [1, 6, 12, 24, 48];

  const _FrequencySelector({
    required this.localeService,
    required this.selectedHours,
    required this.onHoursChanged,
    required this.isDark,
  });

  bool get _isRu => localeService.currentLocale.languageCode == 'ru';

  String _getLabel(int hours, AppLocalizations l10n) {
    if (hours == 1) return l10n.slideDigestEveryHour;
    if (hours == 6) return l10n.slideDigestEvery6Hours;
    if (hours == 12) return l10n.slideDigestEvery12Hours;
    if (hours == 24) return l10n.slideDigestDaily;
    if (hours == 48) return l10n.slideDigestEvery2Days;
    return '$hours${_isRu ? 'ч' : 'h'}';
  }

  void _showCustomPicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final surfaceColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;

    int tempHours = selectedHours;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        l10n.slideDigestCancel,
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      l10n.slideDigestFrequency,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onHoursChanged(tempHours);
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        l10n.slideDone,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Custom hour picker (1-72 hours)
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: (selectedHours - 1).clamp(0, 71),
                  ),
                  itemExtent: 40,
                  onSelectedItemChanged: (index) {
                    tempHours = index + 1; // 1-72 hours
                  },
                  children: List.generate(72, (index) {
                    final hours = index + 1;
                    String label;
                    if (hours == 1) {
                      label = _isRu ? '1 час' : '1 hour';
                    } else if (hours < 24) {
                      label = _isRu ? '$hours часов' : '$hours hours';
                    } else if (hours == 24) {
                      label = _isRu ? '1 день (24ч)' : '1 day (24h)';
                    } else if (hours == 48) {
                      label = _isRu ? '2 дня (48ч)' : '2 days (48h)';
                    } else if (hours == 72) {
                      label = _isRu ? '3 дня (72ч)' : '3 days (72h)';
                    } else {
                      label = _isRu ? '$hours часов' : '$hours hours';
                    }
                    return Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                        ),
                      ),
                    );
                  }),
                ),
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
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;
    final surfaceColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark
        ? CupertinoColors.white.withOpacity(0.1)
        : CupertinoColors.black.withOpacity(0.1);

    final isCustomValue = !_presetHours.contains(selectedHours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          l10n.slideDigestFrequency,
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.slideDigestFrequencyHint,
          style: TextStyle(
            color: secondaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),

        // Chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Preset chips
              ..._presetHours.map((hours) {
                final isSelected = selectedHours == hours && !isCustomValue;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FrequencyChip(
                    label: _getLabel(hours, l10n),
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onHoursChanged(hours);
                    },
                    accentColor: accentColor,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    isDark: isDark,
                  ),
                );
              }),

              // Custom chip
              _FrequencyChip(
                label: isCustomValue ? _getLabel(selectedHours, l10n) : l10n.slideDigestCustom,
                isSelected: isCustomValue,
                onTap: () => _showCustomPicker(context),
                accentColor: accentColor,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textColor: textColor,
                isDark: isDark,
                icon: CupertinoIcons.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chip for frequency selection
class _FrequencyChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final bool isDark;
  final IconData? icon;

  const _FrequencyChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.accentColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null && !isSelected) ...[
              Icon(
                icon,
                size: 14,
                color: textColor.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
            ],
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  CupertinoIcons.checkmark,
                  size: 14,
                  color: isDark ? CupertinoColors.black : CupertinoColors.white,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? CupertinoColors.black : CupertinoColors.white)
                    : textColor,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
