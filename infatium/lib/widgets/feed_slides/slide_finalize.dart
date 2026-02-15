import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/feed_builder_models.dart';
import '../../models/source_validation_models.dart';
import '../../models/subscription_models.dart';
import '../../services/locale_service.dart';
import '../../services/theme_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/colors.dart';
import '../telegram_icon.dart';
import '../limit_reached_modal.dart';

/// Slide 4: Preview and Create - Shows summary of all configurations.
class SlideFinalize extends StatefulWidget {
  final LocaleService localeService;
  final FeedType feedType;
  final int digestIntervalHours;
  final List<ValidatedSource> sources;
  final List<String> selectedViews;
  final List<String> selectedFilters;
  final String feedName;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onSubmit;
  final Future<String?> Function()? onGenerateTitle;
  final bool isSubmitting;
  final bool isEditMode;
  final VoidCallback? onBack;

  const SlideFinalize({
    super.key,
    required this.localeService,
    required this.feedType,
    this.digestIntervalHours = 6,
    required this.sources,
    required this.selectedViews,
    required this.selectedFilters,
    required this.feedName,
    required this.onNameChanged,
    required this.onSubmit,
    this.onGenerateTitle,
    this.isSubmitting = false,
    this.isEditMode = false,
    this.onBack,
  });

  @override
  State<SlideFinalize> createState() => _SlideFinalizeState();
}

class _SlideFinalizeState extends State<SlideFinalize>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _buttonPulseController;
  late TextEditingController _titleController;

  bool _isGeneratingTitle = false;

  bool get _isRu => widget.localeService.currentLocale.languageCode == 'ru';
  bool get _isDark => ThemeService().isDarkMode;
  bool get _isDigest => widget.feedType == FeedType.DIGEST;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.feedName);

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _entranceController.forward();

    _buttonPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SlideFinalize oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedName != _titleController.text && widget.feedName.isNotEmpty) {
      _titleController.text = widget.feedName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _entranceController.dispose();
    _buttonPulseController.dispose();
    super.dispose();
  }

  Future<void> _generateTitle() async {
    if (widget.onGenerateTitle == null || _isGeneratingTitle) return;

    setState(() => _isGeneratingTitle = true);
    HapticFeedback.selectionClick();

    try {
      final title = await widget.onGenerateTitle!();
      if (title != null && mounted) {
        _titleController.text = title;
        widget.onNameChanged(title);
      }
    } catch (e) {
      print('SlideFinalize: Error generating title: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingTitle = false);
      }
    }
  }

  String _formatInterval(int hours, AppLocalizations l10n) {
    if (hours == 1) return l10n.slideDigestEveryHour;
    if (hours == 6) return l10n.slideDigestEvery6Hours;
    if (hours == 12) return l10n.slideDigestEvery12Hours;
    if (hours == 24) return l10n.slideDigestDaily;
    if (hours == 48) return l10n.slideDigestEvery2Days;
    if (hours < 24) return _isRu ? 'Каждые $hoursч' : 'Every ${hours}h';
    return '$hours${_isRu ? 'ч' : 'h'}';
  }

  Widget _getSourceTypeIcon(String? sourceType, {required double size, required Color color}) {
    switch (sourceType?.toUpperCase()) {
      case 'TELEGRAM':
        return TelegramIcon(size: size, isDark: _isDark, color: color);
      case 'RSS':
        return Icon(CupertinoIcons.antenna_radiowaves_left_right, size: size, color: color);
      case 'WEBSITE':
        return Icon(CupertinoIcons.globe, size: size, color: color);
      default:
        return Icon(CupertinoIcons.link, size: size, color: color);
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
          // Static back button row
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
          // Scrollable content with floating create button
          Expanded(
            child: Stack(
              children: [
                // Main content - scrollable
                AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _entranceController.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - _entranceController.value)),
                        child: child,
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Header
                        Text(
                          l10n.slideFinalizeTitle,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.slideFinalizeSubtitle,
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Feed name section
                        _buildSectionLabel(l10n.slideFinalizeName, textColor),
                        const SizedBox(height: 10),
                        _buildNameInput(textColor, secondaryColor, surfaceColor, borderColor, accentColor),

                        const SizedBox(height: 24),

                        // Preview summary
                        _buildSectionLabel(l10n.slideFinalizeSummary, textColor),
                        const SizedBox(height: 10),
                        _buildPreviewSummary(textColor, secondaryColor, surfaceColor, borderColor, accentColor, l10n),

                        const SizedBox(height: 160), // Space for floating button
                      ],
                    ),
                  ),
                ),

                // Floating create button - dynamic offset for old Android (hardware buttons)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: buttonBottom,
                  child: GestureDetector(
                    onTap: widget.isSubmitting ? null : () {
                      // Check feed limit only when creating (not editing)
                      if (!widget.isEditMode && !SubscriptionService().canCreateFeed) {
                        LimitReachedModal.show(
                          context: context,
                          limitType: LimitType.feeds,
                          currentCount: SubscriptionService().activeFeedsCount,
                          isRu: _isRu,
                        );
                        return;
                      }
                      widget.onSubmit();
                    },
                    child: AnimatedBuilder(
                      animation: _buttonPulseController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: widget.isSubmitting
                                ? []
                                : [
                                    // Pulsing shadow only when not loading
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.2 + 0.1 * _buttonPulseController.value),
                                      blurRadius: 16 + 4 * _buttonPulseController.value,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: widget.isSubmitting
                                ? LoadingAnimationWidget.staggeredDotsWave(
                                    color: _isDark
                                        ? CupertinoColors.black
                                        : CupertinoColors.white,
                                    size: 22,
                                  )
                                : Text(
                                    widget.isEditMode
                                        ? l10n.slideFinalizeSave
                                        : l10n.slideFinalizeCreateFeed,
                                    style: TextStyle(
                                      color: _isDark
                                          ? CupertinoColors.black
                                          : CupertinoColors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        );
                      },
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

  Widget _buildSectionLabel(String label, Color textColor) {
    return Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildNameInput(
    Color textColor,
    Color secondaryColor,
    Color surfaceColor,
    Color borderColor,
    Color accentColor,
  ) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _titleController,
              placeholder: AppLocalizations.of(context)!.slideFinalizeNameHint,
              placeholderStyle: TextStyle(color: secondaryColor),
              style: TextStyle(color: textColor, fontSize: 16),
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(),
              cursorColor: textColor,
              onChanged: widget.onNameChanged,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
          // AI generate button
          if (widget.onGenerateTitle != null)
            GestureDetector(
              onTap: _isGeneratingTitle ? null : _generateTitle,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: _isGeneratingTitle
                    ? SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: LoadingAnimationWidget.staggeredDotsWave(
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          CupertinoIcons.sparkles,
                          size: 18,
                          color: _isDark ? CupertinoColors.black : CupertinoColors.white,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewSummary(
    Color textColor,
    Color secondaryColor,
    Color surfaceColor,
    Color borderColor,
    Color accentColor,
    AppLocalizations l10n,
  ) {
    final validSources = widget.sources
        .where((s) => s.status == SourceValidationStatus.valid)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feed type row
          _buildPreviewRow(
            icon: widget.feedType == FeedType.SINGLE_POST
                ? CupertinoIcons.bolt_fill
                : CupertinoIcons.doc_text_fill,
            label: l10n.slideFinalizeType,
            value: widget.feedType == FeedType.SINGLE_POST
                ? l10n.slideFinalizeIndividualPosts
                : l10n.slideFinalizeDigest,
            textColor: textColor,
            secondaryColor: secondaryColor,
            accentColor: accentColor,
          ),

          // Frequency (only for DIGEST)
          if (_isDigest) ...[
            const SizedBox(height: 12),
            _buildPreviewRow(
              icon: CupertinoIcons.clock,
              label: l10n.slideFinalizeFrequency,
              value: _formatInterval(widget.digestIntervalHours, l10n),
              textColor: textColor,
              secondaryColor: secondaryColor,
              accentColor: accentColor,
            ),
          ],

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              height: 1,
              color: borderColor,
            ),
          ),

          // Sources
          _buildPreviewRow(
            icon: CupertinoIcons.link,
            label: l10n.slideFinalizeSources,
            value: '${validSources.length}',
            textColor: textColor,
            secondaryColor: secondaryColor,
            accentColor: accentColor,
          ),
          if (validSources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: validSources.map((s) => _buildSourceChip(
                s,
                textColor,
                secondaryColor,
                borderColor,
              )).toList(),
            ),
          ],

          // Views
          if (widget.selectedViews.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                height: 1,
                color: borderColor,
              ),
            ),
            _buildPreviewRow(
              icon: CupertinoIcons.eye,
              label: l10n.slideFinalizeStyle,
              value: '',
              textColor: textColor,
              secondaryColor: secondaryColor,
              accentColor: accentColor,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selectedViews.map((v) => _buildSmallChip(
                _getViewLabel(v),
                secondaryColor,
              )).toList(),
            ),
          ],

          // Filters
          if (widget.selectedFilters.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPreviewRow(
              icon: CupertinoIcons.slider_horizontal_3,
              label: l10n.slideFinalizeFilters,
              value: '',
              textColor: textColor,
              secondaryColor: secondaryColor,
              accentColor: accentColor,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selectedFilters.map((f) => _buildSmallChip(
                _getFilterLabel(f),
                secondaryColor,
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color secondaryColor,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: secondaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (value.isNotEmpty) ...[
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSourceChip(
    ValidatedSource source,
    Color textColor,
    Color secondaryColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getSourceTypeIcon(
            source.sourceType,
            size: 12,
            color: secondaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            source.displayName,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getViewLabel(String viewId) {
    final view = ViewOptions.all.firstWhere(
      (v) => v.id == viewId,
      orElse: () => ConfigOption(id: viewId, labelRu: viewId, labelEn: viewId),
    );
    return view.getLabel(_isRu);
  }

  String _getFilterLabel(String filterId) {
    final filter = FilterOptions.all.firstWhere(
      (f) => f.id == filterId,
      orElse: () => ConfigOption(id: filterId, labelRu: filterId, labelEn: filterId),
    );
    return filter.getLabel(_isRu);
  }
}
