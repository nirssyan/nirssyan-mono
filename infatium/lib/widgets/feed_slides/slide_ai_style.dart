import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import '../../l10n/generated/app_localizations.dart';
import '../ai_view_selector.dart';
import '../../services/locale_service.dart';
import '../../services/theme_service.dart';
import '../../theme/colors.dart';

/// Slide 3: AI processing style selection with live preview.
/// Fullscreen dedicated slide for choosing how news will be processed.
class SlideAIStyle extends StatefulWidget {
  final LocaleService localeService;
  final AIViewStyle selectedStyle;
  final ValueChanged<AIViewStyle> onStyleChanged;
  final String? customPrompt;
  final ValueChanged<String?> onCustomPromptChanged;

  const SlideAIStyle({
    super.key,
    required this.localeService,
    required this.selectedStyle,
    required this.onStyleChanged,
    this.customPrompt,
    required this.onCustomPromptChanged,
  });

  @override
  State<SlideAIStyle> createState() => _SlideAIStyleState();
}

class _SlideAIStyleState extends State<SlideAIStyle>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _previewController;
  late AnimationController _glowController;
  late TextEditingController _customPromptController;

  bool _showCustomInput = false;
  int _selectedIndex = 1; // Default to essence

  bool get _isRu => widget.localeService.currentLocale.languageCode == 'ru';
  bool get _isDark => ThemeService().isDarkMode;

  static const _presetStyles = [
    AIViewStyle.brief,
    AIViewStyle.essence,
    AIViewStyle.full,
  ];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _entranceController.forward();

    _previewController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _customPromptController = TextEditingController(text: widget.customPrompt);
    _showCustomInput = widget.selectedStyle == AIViewStyle.custom;

    // Set initial selected index
    if (widget.selectedStyle != AIViewStyle.custom) {
      _selectedIndex = _presetStyles.indexOf(widget.selectedStyle);
      if (_selectedIndex < 0) _selectedIndex = 1;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _previewController.dispose();
    _glowController.dispose();
    _customPromptController.dispose();
    super.dispose();
  }

  void _onStyleSelected(int index) {
    if (_selectedIndex == index && !_showCustomInput) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = index;
      _showCustomInput = false;
    });
    _previewController.forward(from: 0);
    widget.onStyleChanged(_presetStyles[index]);
  }

  void _toggleCustomInput() {
    HapticFeedback.selectionClick();
    setState(() {
      _showCustomInput = !_showCustomInput;
    });

    if (_showCustomInput) {
      widget.onStyleChanged(AIViewStyle.custom);
    } else {
      widget.onStyleChanged(_presetStyles[_selectedIndex]);
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
        return l10n.aiStyleCustom;
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

  IconData _getStyleIcon(AIViewStyle style) {
    switch (style) {
      case AIViewStyle.brief:
        return CupertinoIcons.text_alignleft;
      case AIViewStyle.essence:
        return CupertinoIcons.text_aligncenter;
      case AIViewStyle.full:
        return CupertinoIcons.text_justify;
      case AIViewStyle.custom:
        return CupertinoIcons.sparkles;
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
    final borderColor = _isDark ? AppColors.accentSecondary : AppColors.lightAccentSecondary;

    return SafeArea(
      child: AnimatedBuilder(
        animation: _entranceController,
        builder: (context, child) {
          return Opacity(
            opacity: _entranceController.value,
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Header
              Text(
                l10n.aiStyleHowToProcess,
                style: TextStyle(
                  color: textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.aiStyleAiAdaptsHint,
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 32),

              // Style selector buttons
              Row(
                children: List.generate(3, (index) {
                  final style = _presetStyles[index];
                  final isSelected = _selectedIndex == index && !_showCustomInput;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index < 2 ? 10 : 0,
                      ),
                      child: GestureDetector(
                        onTap: () => _onStyleSelected(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColor
                                : surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? accentColor
                                  : borderColor,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _getStyleIcon(style),
                                size: 24,
                                color: isSelected
                                    ? (_isDark ? CupertinoColors.black : CupertinoColors.white)
                                    : accentColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getStyleTitle(style, l10n),
                                style: TextStyle(
                                  color: isSelected
                                      ? (_isDark ? CupertinoColors.black : CupertinoColors.white)
                                      : textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getStyleDescription(style, l10n),
                                style: TextStyle(
                                  color: isSelected
                                      ? (_isDark ? CupertinoColors.black : CupertinoColors.white).withOpacity(0.7)
                                      : secondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
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
                        : surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _showCustomInput ? accentColor : borderColor,
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
                          l10n.aiStyleCustomProcessingStyle,
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

              // Custom prompt input
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _showCustomInput
                    ? _buildCustomPromptInput(textColor, secondaryColor, accentColor, bgColor, borderColor)
                    : const SizedBox.shrink(),
              ),

              const Spacer(),

              // Live preview
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.08 + 0.04 * _glowController.value),
                          blurRadius: 20,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: _buildLivePreview(textColor, secondaryColor, accentColor, surfaceColor, bgColor, borderColor),
              ),

              const SizedBox(height: 24),

              // Swipe hint
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.aiStyleSwipeRight,
                      style: TextStyle(color: secondaryColor, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Icon(CupertinoIcons.chevron_right, size: 14, color: secondaryColor),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPromptInput(
    Color textColor,
    Color secondaryColor,
    Color accentColor,
    Color bgColor,
    Color borderColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
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
              _buildSuggestionChip('bullet points', accentColor, secondaryColor),
              _buildSuggestionChip(AppLocalizations.of(context)!.aiStyleChipNoAds, accentColor, secondaryColor),
              _buildSuggestionChip(AppLocalizations.of(context)!.aiStyleChipNumbersOnly, accentColor, secondaryColor),
              _buildSuggestionChip(AppLocalizations.of(context)!.aiStyleChipCasual, accentColor, secondaryColor),
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
        final newText = currentText.isEmpty ? text : '$currentText, $text';
        _customPromptController.text = newText;
        widget.onCustomPromptChanged(newText);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.3)),
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

  Widget _buildLivePreview(
    Color textColor,
    Color secondaryColor,
    Color accentColor,
    Color surfaceColor,
    Color bgColor,
    Color borderColor,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final currentStyle = _showCustomInput
        ? AIViewStyle.custom
        : _presetStyles[_selectedIndex];

    // Example news content based on style
    final title = '\u{1F525} ${l10n.aiStylePreviewTitle}';

    String previewText;
    switch (currentStyle) {
      case AIViewStyle.brief:
        previewText = l10n.aiStylePreviewBrief;
        break;
      case AIViewStyle.essence:
        previewText = l10n.aiStylePreviewEssence;
        break;
      case AIViewStyle.full:
        previewText = l10n.aiStylePreviewFull;
        break;
      case AIViewStyle.custom:
        final prompt = _customPromptController.text;
        previewText = prompt.isNotEmpty
            ? (_isRu
                ? 'Обработано: "$prompt"\n\nM4 — 50% быстрее, ноябрь.'
                : 'Processed: "$prompt"\n\nM4 — 50% faster, November.')
            : l10n.aiStyleEnterAbove;
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.eye,
                          size: 14,
                          color: accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.aiStylePreview,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _getStyleTitle(currentStyle, l10n),
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // News card preview
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey(currentStyle),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Text(
                          previewText,
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
