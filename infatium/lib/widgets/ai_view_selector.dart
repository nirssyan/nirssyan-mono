import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../theme/colors.dart';

/// AI text processing style options
enum AIViewStyle {
  brief,   // 2-3 lines, just the essence
  essence, // 4-5 lines, main facts
  full,    // 8+ lines, complete text
  custom,  // User-defined prompt
}

/// Morphing card selector for AI text processing style.
/// Horizontal swipe between presets with live preview that morphs between styles.
class AIViewSelector extends StatefulWidget {
  final LocaleService localeService;
  final AIViewStyle selectedStyle;
  final ValueChanged<AIViewStyle> onStyleChanged;
  final String? customPrompt;
  final ValueChanged<String?> onCustomPromptChanged;

  const AIViewSelector({
    super.key,
    required this.localeService,
    required this.selectedStyle,
    required this.onStyleChanged,
    this.customPrompt,
    required this.onCustomPromptChanged,
  });

  @override
  State<AIViewSelector> createState() => _AIViewSelectorState();
}

class _AIViewSelectorState extends State<AIViewSelector>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _morphController;
  late AnimationController _glowController;
  late TextEditingController _customPromptController;

  bool _showCustomInput = false;
  double _currentPage = 0;

  bool get _isRu => widget.localeService.currentLocale.languageCode == 'ru';
  bool get _isDark => ThemeService().isDarkMode;

  // Style presets (excluding custom)
  static const _presetStyles = [
    AIViewStyle.brief,
    AIViewStyle.essence,
    AIViewStyle.full,
  ];

  @override
  void initState() {
    super.initState();

    final initialIndex = widget.selectedStyle == AIViewStyle.custom
        ? 1 // Default to essence when custom
        : _presetStyles.indexOf(widget.selectedStyle);

    _pageController = PageController(
      initialPage: initialIndex >= 0 ? initialIndex : 1,
      viewportFraction: 1.0,
    );
    _pageController.addListener(_onPageScroll);

    _morphController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _customPromptController = TextEditingController(text: widget.customPrompt);
    _showCustomInput = widget.selectedStyle == AIViewStyle.custom;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _morphController.dispose();
    _glowController.dispose();
    _customPromptController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    setState(() {
      _currentPage = _pageController.page ?? 0;
    });
  }

  void _toggleCustomInput() {
    HapticFeedback.selectionClick();
    setState(() {
      _showCustomInput = !_showCustomInput;
    });

    if (_showCustomInput) {
      widget.onStyleChanged(AIViewStyle.custom);
    } else {
      final currentIndex = _currentPage.round().clamp(0, 2);
      widget.onStyleChanged(_presetStyles[currentIndex]);
    }
  }

  String _getStyleTitle(AIViewStyle style, AppLocalizations l10n) {
    switch (style) {
      case AIViewStyle.brief:
        return l10n.aiStyleBrief;
      case AIViewStyle.essence:
        return l10n.aiStyleEssence;
      case AIViewStyle.full:
        return l10n.aiStyleFull;
      case AIViewStyle.custom:
        return l10n.aiStyleCustomStyle;
    }
  }

  String _getStyleDescription(AIViewStyle style, AppLocalizations l10n) {
    switch (style) {
      case AIViewStyle.brief:
        return l10n.aiStyleBriefDesc;
      case AIViewStyle.essence:
        return l10n.aiStyleEssenceDesc;
      case AIViewStyle.full:
        return l10n.aiStyleFullDesc;
      case AIViewStyle.custom:
        return l10n.aiStyleCustomDesc;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textColor = _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = _isDark ? AppColors.accent : AppColors.lightAccent;
    final surfaceColor = _isDark ? AppColors.surface : AppColors.lightSurface;
    final bgColor = _isDark ? AppColors.background : AppColors.lightBackground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          l10n.aiStyleHowToDisplay,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.aiStyleSwipeHint,
          style: TextStyle(
            color: secondaryColor,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 16),

        // Morphing preview card
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.1 + 0.05 * _glowController.value),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isDark
                        ? AppColors.textPrimary.withOpacity(0.1)
                        : AppColors.lightAccent.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    // Style title with morph
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: _buildMorphingTitle(textColor, accentColor, l10n),
                    ),

                    // Preview content area
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          widget.onStyleChanged(_presetStyles[index]);
                          if (_showCustomInput) {
                            setState(() => _showCustomInput = false);
                          }
                        },
                        itemCount: 3,
                        itemBuilder: (context, index) {
                          return _PreviewCard(
                            style: _presetStyles[index],
                            isRu: _isRu,
                            isDark: _isDark,
                            progress: (_currentPage - index).clamp(-1.0, 1.0).abs(),
                          );
                        },
                      ),
                    ),

                    // Page indicators
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final distance = (_currentPage - index).abs();
                          final isActive = distance < 0.5;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? accentColor
                                  : secondaryColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Custom style toggle
        GestureDetector(
          onTap: _toggleCustomInput,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _showCustomInput
                  ? accentColor.withOpacity(0.1)
                  : surfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showCustomInput
                    ? accentColor
                    : (_isDark
                        ? AppColors.textPrimary.withOpacity(0.1)
                        : AppColors.lightAccent.withOpacity(0.1)),
                width: _showCustomInput ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.sparkles,
                  size: 20,
                  color: _showCustomInput ? accentColor : secondaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.aiStyleCustomStyle,
                    style: TextStyle(
                      color: _showCustomInput ? accentColor : textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  _showCustomInput
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 18,
                  color: secondaryColor,
                ),
              ],
            ),
          ),
        ),

        // Custom prompt input (expandable)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: _showCustomInput
              ? _buildCustomPromptInput(
                  textColor, secondaryColor, accentColor, bgColor)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMorphingTitle(Color textColor, Color accentColor, AppLocalizations l10n) {
    final currentIndex = _currentPage.round().clamp(0, 2);
    final style = _presetStyles[currentIndex];

    return Row(
      children: [
        // Style icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            style == AIViewStyle.brief
                ? CupertinoIcons.text_alignleft
                : style == AIViewStyle.essence
                    ? CupertinoIcons.text_aligncenter
                    : CupertinoIcons.text_justify,
            size: 20,
            color: accentColor,
          ),
        ),
        const SizedBox(width: 12),

        // Title and description with crossfade
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getStyleTitle(style, l10n),
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getStyleDescription(style, l10n),
                style: TextStyle(
                  color: _isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomPromptInput(
    Color textColor,
    Color secondaryColor,
    Color accentColor,
    Color bgColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input field
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDark
                    ? AppColors.textPrimary.withOpacity(0.1)
                    : AppColors.lightAccent.withOpacity(0.1),
              ),
            ),
            child: CupertinoTextField(
              controller: _customPromptController,
              placeholder: AppLocalizations.of(context)!.aiStyleCustomPlaceholder,
              placeholderStyle: TextStyle(
                color: secondaryColor.withOpacity(0.6),
                fontSize: 15,
              ),
              style: TextStyle(
                color: textColor,
                fontSize: 15,
              ),
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(),
              maxLines: 2,
              onChanged: widget.onCustomPromptChanged,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ),

          const SizedBox(height: 12),

          // Quick suggestions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestionChip(
                'bullet points',
                accentColor,
                secondaryColor,
              ),
              _buildSuggestionChip(
                AppLocalizations.of(context)!.aiStyleChipNoAds,
                accentColor,
                secondaryColor,
              ),
              _buildSuggestionChip(
                AppLocalizations.of(context)!.aiStyleChipNumbersOnly,
                accentColor,
                secondaryColor,
              ),
              _buildSuggestionChip(
                AppLocalizations.of(context)!.aiStyleChipCasual,
                accentColor,
                secondaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, Color accentColor, Color secondaryColor) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        final currentText = _customPromptController.text;
        final newText = currentText.isEmpty
            ? text
            : '$currentText, $text';
        _customPromptController.text = newText;
        widget.onCustomPromptChanged(newText);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: accentColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Preview card showing example text in selected style
class _PreviewCard extends StatelessWidget {
  final AIViewStyle style;
  final bool isRu;
  final bool isDark;
  final double progress; // 0 = centered, 1 = fully off-screen

  const _PreviewCard({
    required this.style,
    required this.isRu,
    required this.isDark,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final bgColor = isDark ? AppColors.background : AppColors.lightBackground;
    final borderColor = isDark
        ? AppColors.textPrimary.withOpacity(0.08)
        : AppColors.lightAccent.withOpacity(0.08);

    final l10n = AppLocalizations.of(context)!;

    // Example news content
    final title = '\u{1F525} ${l10n.aiStylePreviewTitle}';

    final briefText = l10n.aiStylePreviewBrief;

    final essenceText = l10n.aiStylePreviewEssence;

    final fullText = l10n.aiStylePreviewFull;

    String displayText;
    int maxLines;

    switch (style) {
      case AIViewStyle.brief:
        displayText = briefText;
        maxLines = 2;
        break;
      case AIViewStyle.essence:
        displayText = essenceText;
        maxLines = 4;
        break;
      case AIViewStyle.full:
        displayText = fullText;
        maxLines = 8;
        break;
      case AIViewStyle.custom:
        displayText = essenceText;
        maxLines = 4;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Transform.scale(
        scale: 1.0 - (progress * 0.05),
        child: Opacity(
          opacity: 1.0 - (progress * 0.3),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 8),

                // Content with animated height
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
