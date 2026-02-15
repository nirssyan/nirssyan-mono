import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/feed_builder_models.dart';
import '../../models/subscription_models.dart';
import '../../services/locale_service.dart';
import '../../services/theme_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/colors.dart';
import '../limit_reached_modal.dart';

/// Slide 3: Configuration - Style and Filter selection with chips.
class SlideConfiguration extends StatefulWidget {
  final LocaleService localeService;
  final List<String> selectedViews;
  final ValueChanged<List<String>> onViewsChanged;
  final List<String> selectedFilters;
  final ValueChanged<List<String>> onFiltersChanged;
  final List<String> customViews;
  final ValueChanged<List<String>> onCustomViewsChanged;
  final List<String> customFilters;
  final ValueChanged<List<String>> onCustomFiltersChanged;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const SlideConfiguration({
    super.key,
    required this.localeService,
    required this.selectedViews,
    required this.onViewsChanged,
    required this.selectedFilters,
    required this.onFiltersChanged,
    required this.customViews,
    required this.onCustomViewsChanged,
    required this.customFilters,
    required this.onCustomFiltersChanged,
    this.onNext,
    this.onBack,
  });

  @override
  State<SlideConfiguration> createState() => _SlideConfigurationState();
}

class _SlideConfigurationState extends State<SlideConfiguration>
    with TickerProviderStateMixin {
  late TextEditingController _customViewTextController;
  late TextEditingController _customFilterTextController;
  late FocusNode _viewInputFocusNode;
  late FocusNode _filterInputFocusNode;

  bool _isViewInputVisible = false;
  bool _isFilterInputVisible = false;
  bool _isAnyInputFocused = false;

  bool get _isRu => widget.localeService.currentLocale.languageCode == 'ru';
  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();

    _customViewTextController = TextEditingController();
    _customFilterTextController = TextEditingController();
    _viewInputFocusNode = FocusNode();
    _filterInputFocusNode = FocusNode();

    // Listen to focus changes to hide/show the Next button
    _viewInputFocusNode.addListener(_onFocusChange);
    _filterInputFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final isFocused = _viewInputFocusNode.hasFocus || _filterInputFocusNode.hasFocus;
    if (isFocused != _isAnyInputFocused) {
      setState(() {
        _isAnyInputFocused = isFocused;
      });
    }
  }

  @override
  void dispose() {
    _viewInputFocusNode.removeListener(_onFocusChange);
    _filterInputFocusNode.removeListener(_onFocusChange);
    _customViewTextController.dispose();
    _customFilterTextController.dispose();
    _viewInputFocusNode.dispose();
    _filterInputFocusNode.dispose();
    super.dispose();
  }

  void _addCustomView(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (widget.customViews.contains(trimmed)) return;

    // Check styles limit before adding
    final totalStyles = widget.selectedViews.length + widget.customViews.length;
    if (!SubscriptionService().canAddMore(LimitType.styles, totalStyles)) {
      LimitReachedModal.show(
        context: context,
        limitType: LimitType.styles,
        currentCount: totalStyles,
        isRu: _isRu,
      );
      _customViewTextController.clear();
      return;
    }

    HapticFeedback.selectionClick();
    final updatedCustom = [...widget.customViews, trimmed];
    widget.onCustomViewsChanged(updatedCustom);

    // Also add to selectedViews so it appears in summary
    final updatedSelected = [...widget.selectedViews, trimmed];
    widget.onViewsChanged(updatedSelected);

    _customViewTextController.clear();
  }

  void _removeCustomView(String text) {
    HapticFeedback.selectionClick();
    final updatedCustom = widget.customViews.where((v) => v != text).toList();
    widget.onCustomViewsChanged(updatedCustom);

    // Also remove from selectedViews
    final updatedSelected = widget.selectedViews.where((v) => v != text).toList();
    widget.onViewsChanged(updatedSelected);
  }

  void _addCustomFilter(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (widget.customFilters.contains(trimmed)) return;

    // Check filters limit before adding
    final totalFilters = widget.selectedFilters.length + widget.customFilters.length;
    if (!SubscriptionService().canAddMore(LimitType.filters, totalFilters)) {
      LimitReachedModal.show(
        context: context,
        limitType: LimitType.filters,
        currentCount: totalFilters,
        isRu: _isRu,
      );
      _customFilterTextController.clear();
      return;
    }

    HapticFeedback.selectionClick();
    final updatedCustom = [...widget.customFilters, trimmed];
    widget.onCustomFiltersChanged(updatedCustom);

    // Also add to selectedFilters so it appears in summary
    final updatedSelected = [...widget.selectedFilters, trimmed];
    widget.onFiltersChanged(updatedSelected);

    _customFilterTextController.clear();
  }

  void _removeCustomFilter(String text) {
    HapticFeedback.selectionClick();
    final updatedCustom = widget.customFilters.where((f) => f != text).toList();
    widget.onCustomFiltersChanged(updatedCustom);

    // Also remove from selectedFilters
    final updatedSelected = widget.selectedFilters.where((f) => f != text).toList();
    widget.onFiltersChanged(updatedSelected);
  }

  void _toggleView(String viewId) {
    final current = List<String>.from(widget.selectedViews);
    if (current.contains(viewId)) {
      // Deselecting - always allowed
      HapticFeedback.selectionClick();
      current.remove(viewId);
      widget.onViewsChanged(current);
    } else {
      // Selecting - check limit
      final totalStyles = widget.selectedViews.length + widget.customViews.length;
      if (!SubscriptionService().canAddMore(LimitType.styles, totalStyles)) {
        LimitReachedModal.show(
          context: context,
          limitType: LimitType.styles,
          currentCount: totalStyles,
          isRu: _isRu,
        );
        return;
      }
      HapticFeedback.selectionClick();
      current.add(viewId);
      widget.onViewsChanged(current);
    }
  }

  void _toggleFilter(String filterId) {
    final current = List<String>.from(widget.selectedFilters);
    if (current.contains(filterId)) {
      // Deselecting - always allowed
      HapticFeedback.selectionClick();
      current.remove(filterId);
      widget.onFiltersChanged(current);
    } else {
      // Selecting - check limit
      final totalFilters = widget.selectedFilters.length + widget.customFilters.length;
      if (!SubscriptionService().canAddMore(LimitType.filters, totalFilters)) {
        LimitReachedModal.show(
          context: context,
          limitType: LimitType.filters,
          currentCount: totalFilters,
          isRu: _isRu,
        );
        return;
      }
      HapticFeedback.selectionClick();
      current.add(filterId);
      widget.onFiltersChanged(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textColor = _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = _isDark ? AppColors.accent : AppColors.lightAccent;
    final surfaceColor = _isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = _isDark
        ? CupertinoColors.white.withOpacity(0.1)
        : CupertinoColors.black.withOpacity(0.1);

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    // GlassTabBar: 88px from screen bottom. Target: button at 100px from screen.
    // SafeArea adds bottomInset, so subtract it from target.
    final buttonBottom = (100.0 - bottomInset).clamp(12.0, 100.0);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back button
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
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Header
                      Text(
                        l10n.slideConfigTitle,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.slideConfigSubtitle,
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Views section
                      _buildSectionLabel(
                        l10n.slideConfigProcessingStyle,
                        textColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.slideConfigProcessingHint,
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildChipContainer(
                        presetOptions: ViewOptions.all,
                        selectedPresets: widget.selectedViews,
                        onTogglePreset: _toggleView,
                        customItems: widget.customViews,
                        onAddCustom: _addCustomView,
                        onRemoveCustom: _removeCustomView,
                        controller: _customViewTextController,
                        focusNode: _viewInputFocusNode,
                        isInputVisible: _isViewInputVisible,
                        onInputVisibilityChanged: (v) => setState(() => _isViewInputVisible = v),
                        placeholder: l10n.slideConfigCustomStyle,
                        accentColor: accentColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),

                      const SizedBox(height: 24),

                      // Filters section
                      _buildSectionLabel(
                        l10n.slideConfigFilters,
                        textColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.slideConfigFiltersHint,
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildChipContainer(
                        presetOptions: FilterOptions.all,
                        selectedPresets: widget.selectedFilters,
                        onTogglePreset: _toggleFilter,
                        customItems: widget.customFilters,
                        onAddCustom: _addCustomFilter,
                        onRemoveCustom: _removeCustomFilter,
                        controller: _customFilterTextController,
                        focusNode: _filterInputFocusNode,
                        isInputVisible: _isFilterInputVisible,
                        onInputVisibilityChanged: (v) => setState(() => _isFilterInputVisible = v),
                        placeholder: l10n.slideConfigCustomFilter,
                        accentColor: accentColor,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),

                      const SizedBox(height: 160), // Space for floating button
                    ],
                  ),
                ),

                // Floating button - hidden when input is focused (keyboard visible)
                if (widget.onNext != null && !_isAnyInputFocused)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: buttonBottom,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(12),
                      color: accentColor,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onNext!();
                      },
                      child: Text(
                        l10n.slideNext,
                        style: TextStyle(
                          color: _isDark ? CupertinoColors.black : CupertinoColors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    );
  }

  /// Builds a chip container with preset options, custom chips, and inline input
  /// Similar to the source input in slide_content.dart
  Widget _buildChipContainer({
    required List<ConfigOption> presetOptions,
    required List<String> selectedPresets,
    required void Function(String) onTogglePreset,
    required List<String> customItems,
    required void Function(String) onAddCustom,
    required void Function(String) onRemoveCustom,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isInputVisible,
    required void Function(bool) onInputVisibilityChanged,
    required String placeholder,
    required Color accentColor,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color secondaryColor,
  }) {
    final hasCustomItems = customItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset chips (always visible, outside container)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: presetOptions.map((option) {
            final isSelected = selectedPresets.contains(option.id);
            return _SelectableChip(
              label: option.getLabel(_isRu),
              isSelected: isSelected,
              onTap: () => onTogglePreset(option.id),
              accentColor: accentColor,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              isDark: _isDark,
            );
          }).toList(),
        ),

        // Custom chips container (only if has custom items or input visible)
        if (hasCustomItems || isInputVisible) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TextField (conditionally visible) - at top
                if (isInputVisible)
                  CupertinoTextField(
                    controller: controller,
                    focusNode: focusNode,
                    placeholder: placeholder,
                    padding: const EdgeInsets.all(14),
                    decoration: null,
                    cursorColor: accentColor,
                    style: TextStyle(color: textColor, fontSize: 15),
                    placeholderStyle: TextStyle(
                      color: secondaryColor.withOpacity(0.6),
                      fontSize: 15,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) {
                      onAddCustom(value);
                      onInputVisibilityChanged(false);
                    },
                    onTapOutside: (_) {
                      onAddCustom(controller.text);
                      onInputVisibilityChanged(false);
                      focusNode?.unfocus();
                    },
                  ),

                // Custom chips - below input
                if (customItems.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, isInputVisible ? 8 : 12, 14, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: [
                        ...customItems.map((item) {
                          return _RemovableChip(
                            label: item,
                            onRemove: () => onRemoveCustom(item),
                            accentColor: accentColor,
                            textColor: textColor,
                            isDark: _isDark,
                          );
                        }),
                        // "+" button to add more (only when input not visible)
                        if (!isInputVisible)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onInputVisibilityChanged(true);
                              Future.delayed(const Duration(milliseconds: 100), () {
                                focusNode.requestFocus();
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
                  ),
              ],
            ),
          ),
        ] else ...[
          // Just show "+" button to start adding custom items
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onInputVisibilityChanged(true);
              Future.delayed(const Duration(milliseconds: 100), () {
                focusNode.requestFocus();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.plus, size: 14, color: secondaryColor),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.slideConfigAddCustom,
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectableChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final bool isDark;

  const _SelectableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.accentColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.isDark,
  });

  @override
  State<_SelectableChip> createState() => _SelectableChipState();
}

class _SelectableChipState extends State<_SelectableChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.reverse(),
      onTapUp: (_) {
        _scaleController.forward();
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.forward(),
      child: ScaleTransition(
        scale: _scaleController,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (widget.isDark ? CupertinoColors.white : CupertinoColors.black)
                : (widget.isDark ? CupertinoColors.black : CupertinoColors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isDark ? CupertinoColors.white : CupertinoColors.black,
              width: widget.isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected
                  ? (widget.isDark ? CupertinoColors.black : CupertinoColors.white)
                  : (widget.isDark ? CupertinoColors.white : CupertinoColors.black),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Removable chip for custom user-added items
class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final Color accentColor;
  final Color textColor;
  final bool isDark;

  const _RemovableChip({
    required this.label,
    required this.onRemove,
    required this.accentColor,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), // Black background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFFFFF).withOpacity(0.3), // Thin white border
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFFFFF), // White text
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Icon(
              CupertinoIcons.xmark,
              size: 16,
              color: const Color(0xFFFFFFFF).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
