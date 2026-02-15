import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors, showModalBottomSheet;
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../services/feed_builder_service.dart';
import '../services/news_service.dart';
import '../models/feed_models.dart';
import '../models/feed_builder_models.dart';
import '../models/source_validation_models.dart';
import '../theme/colors.dart';
import 'confirmation_modal.dart';
import '../l10n/generated/app_localizations.dart';
import 'skeleton_loader.dart';
import 'telegram_icon.dart';

class FeedEditBottomSheet extends StatefulWidget {
  final Feed feed;
  final LocaleService localeService;

  const FeedEditBottomSheet({
    super.key,
    required this.feed,
    required this.localeService,
  });

  /// Static method to show the bottom sheet
  static Future<bool?> show({
    required BuildContext context,
    required Feed feed,
    required LocaleService localeService,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.5),
      enableDrag: true,
      builder: (context) => FeedEditBottomSheet(
        feed: feed,
        localeService: localeService,
      ),
    );
  }

  @override
  State<FeedEditBottomSheet> createState() => _FeedEditBottomSheetState();
}

class _FeedEditBottomSheetState extends State<FeedEditBottomSheet>
    with TickerProviderStateMixin {
  // Form controllers
  final _nameController = TextEditingController();
  final _sourceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sourceInputFocusNode = FocusNode();

  // State
  List<ValidatedSource> _sources = [];
  List<String> _filters = [];
  List<String> _views = [];
  final _filterController = TextEditingController();
  final _filterFocusNode = FocusNode();
  final _viewController = TextEditingController();
  final _viewFocusNode = FocusNode();
  int _digestIntervalMinutes = 360;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isGeneratingTitle = false;
  bool _isAddingSource = false;
  bool _isAddingFilter = false;
  bool _isAddingView = false;
  FeedPreview? _previewData;

  // Animation controllers
  late AnimationController _shimmerController;
  late AnimationController _contentFadeController;

  // Animations
  late Animation<double> _contentFadeAnimation;

  @override
  void initState() {
    super.initState();
    _sourceInputFocusNode.addListener(_onSourceFocusChange);
    _filterFocusNode.addListener(_onFilterFocusChange);
    _viewFocusNode.addListener(_onViewFocusChange);
    _setupAnimations();
    _loadFeedData();
  }

  void _onSourceFocusChange() {
    if (!_sourceInputFocusNode.hasFocus && _isAddingSource) {
      _addSource(clearOnFail: true);
      setState(() => _isAddingSource = false);
    }
  }

  void _onFilterFocusChange() {
    if (!_filterFocusNode.hasFocus && _isAddingFilter) {
      _addFilter();
      setState(() => _isAddingFilter = false);
    }
  }

  void _onViewFocusChange() {
    if (!_viewFocusNode.hasFocus && _isAddingView) {
      _addView();
      setState(() => _isAddingView = false);
    }
  }

  void _setupAnimations() {
    // Shimmer animation for skeleton (1500ms like FeedsManagerPage)
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Content fade animation (for transition from skeleton to form)
    _contentFadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _contentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentFadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _sourceInputFocusNode.removeListener(_onSourceFocusChange);
    _filterFocusNode.removeListener(_onFilterFocusChange);
    _viewFocusNode.removeListener(_onViewFocusChange);
    _nameController.dispose();
    _sourceController.dispose();
    _descriptionController.dispose();
    _filterController.dispose();
    _viewController.dispose();
    _sourceInputFocusNode.dispose();
    _filterFocusNode.dispose();
    _viewFocusNode.dispose();
    _shimmerController.dispose();
    _contentFadeController.dispose();
    super.dispose();
  }

  bool get _isRu => widget.localeService.currentLocale.languageCode == 'ru';
  bool get _isDigest => widget.feed.type == FeedType.DIGEST;

  Future<void> _loadFeedData() async {
    try {
      final preview = await FeedBuilderService.getFeedPreviewByFeedId(widget.feed.id);

      // DEBUG: Log raw sources from preview
      print('=== FeedEditBottomSheet _loadFeedData DEBUG ===');
      print('Preview sources count: ${preview.sources.length}');
      for (var i = 0; i < preview.sources.length; i++) {
        final s = preview.sources[i];
        print('Source $i: en="${s.en}", ru="${s.ru}", url="${s.url}", type="${s.type}"');
      }
      print('==============================================');

      if (mounted) {
        setState(() {
          _previewData = preview;
          _nameController.text = preview.name;
          _descriptionController.text = preview.description;
          // Convert existing sources to ValidatedSource with valid status
          // (they were already validated when the feed was created)
          _sources = preview.sources.map((s) => ValidatedSource(
            originalInput: s.url ?? s.en,  // Use URL if available, fallback to display name
            shortName: s.getLabelSafe(_isRu),
            sourceType: s.type,  // Use type from API for correct icon display
            status: SourceValidationStatus.valid,
          )).toList();
          _filters = (preview.filters ?? []).map((f) => f.getLabel(_isRu)).toList();
          _views = (preview.views ?? []).map((v) => v.getLabel(_isRu)).toList();
          if (preview.digestIntervalHours != null) {
            _digestIntervalMinutes = preview.digestIntervalHours! * 60;
          }
          _isLoading = false;
        });
        // Start content fade animation
        _contentFadeController.forward();
      }
    } catch (e) {
      if (kDebugMode) {
        print('FeedEditBottomSheet: Error loading feed: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        _contentFadeController.forward();
        _showError(AppLocalizations.of(context)!.feedEditFailedToLoad);
      }
    }
  }

  Future<void> _generateTitle() async {
    setState(() => _isGeneratingTitle = true);
    try {
      final title = await FeedBuilderService.generateFeedTitle(widget.feed.id);
      if (title != null && mounted) {
        setState(() {
          _nameController.text = title;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (kDebugMode) {
        print('FeedEditBottomSheet: Error generating title: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingTitle = false);
      }
    }
  }

  void _addSource({bool clearOnFail = false}) {
    final source = _sourceController.text.trim();
    if (source.isEmpty) {
      if (clearOnFail) {
        _sourceController.clear();
      }
      return;
    }

    // Check if source already exists
    if (_sources.any((s) => s.originalInput == source)) {
      if (!clearOnFail) {
        _showError(AppLocalizations.of(context)!.feedEditSourceAlreadyAdded);
      }
      _sourceController.clear();
      return;
    }

    // Add source with validating status
    setState(() {
      _sources.add(ValidatedSource(
        originalInput: source,
        status: SourceValidationStatus.validating,
      ));
      _sourceController.clear();
    });
    HapticFeedback.selectionClick();

    // Start validation
    _validateSource(source, _sources.length - 1);
  }

  Future<void> _validateSource(String source, int index) async {
    try {
      final response = await NewsService.validateSource(source);

      if (!mounted) return;

      // Verify the source is still at the expected index
      if (index >= _sources.length || _sources[index].originalInput != source) {
        return;
      }

      if (response == null) {
        // Network error
        setState(() {
          _sources[index] = _sources[index].copyWith(
            status: SourceValidationStatus.error,
            errorMessage: AppLocalizations.of(context)!.feedEditNetworkError,
          );
        });
      } else if (!response.isValid) {
        // Invalid source
        setState(() {
          _sources[index] = _sources[index].copyWith(
            status: SourceValidationStatus.invalid,
            errorMessage: AppLocalizations.of(context)!.feedEditNotFound,
          );
        });
        HapticFeedback.heavyImpact();

        // Auto-remove invalid sources after 800ms
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _removeSource(index);
        });
      } else {
        // Valid source
        setState(() {
          _sources[index] = _sources[index].copyWith(
            status: SourceValidationStatus.valid,
            shortName: response.shortName,
            sourceType: response.sourceType,
          );
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (!mounted) return;
      if (index < _sources.length && _sources[index].originalInput == source) {
        setState(() {
          _sources[index] = _sources[index].copyWith(
            status: SourceValidationStatus.error,
            errorMessage: AppLocalizations.of(context)!.feedEditError,
          );
        });
      }
    }
  }

  void _retrySource(int index) {
    if (index < _sources.length) {
      final source = _sources[index];
      setState(() {
        _sources[index] = source.copyWith(
          status: SourceValidationStatus.validating,
          errorMessage: null,
        );
      });
      _validateSource(source.originalInput, index);
    }
  }

  void _removeSource(int index) {
    if (index < _sources.length) {
      setState(() {
        _sources.removeAt(index);
      });
      HapticFeedback.selectionClick();
    }
  }

  void _addFilter() {
    final filter = _filterController.text.trim();
    if (filter.isEmpty) {
      return;
    }

    if (_filters.contains(filter)) {
      _showError(AppLocalizations.of(context)!.feedEditFilterAlreadyExists);
      return;
    }

    setState(() {
      _filters.add(filter);
      _filterController.clear();
    });
    HapticFeedback.lightImpact();
  }

  void _removeFilter(int index) {
    setState(() {
      _filters.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  void _addView() {
    final view = _viewController.text.trim();
    if (view.isEmpty) {
      return;
    }

    if (_views.contains(view)) {
      _showError(AppLocalizations.of(context)!.feedEditViewAlreadyExists);
      return;
    }

    setState(() {
      _views.add(view);
      _viewController.clear();
    });
    HapticFeedback.lightImpact();
  }

  void _removeView(int index) {
    setState(() {
      _views.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError(AppLocalizations.of(context)!.feedEditEnterName);
      return;
    }

    // Check if any sources are still validating
    if (_sources.any((s) => s.status == SourceValidationStatus.validating)) {
      _showError(AppLocalizations.of(context)!.feedEditWaitForValidation);
      return;
    }

    // Get only valid sources as objects with url and type
    final validSources = _sources
        .where((s) => s.status == SourceValidationStatus.valid)
        .map((s) => {
          'url': s.originalInput,
          'type': s.sourceType ?? 'TELEGRAM',  // Default to TELEGRAM if type unknown
        })
        .toList();

    if (validSources.isEmpty) {
      _showError(AppLocalizations.of(context)!.feedEditAddSource);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final digestIntervalHours = _isDigest ? (_digestIntervalMinutes / 60).ceil() : null;

      // DEBUG LOGS for "Feed not found" investigation
      print('=== FeedEditBottomSheet DEBUG ===');
      print('Feed ID: ${widget.feed.id}');
      print('Feed Name (original): ${widget.feed.name}');
      print('Feed Type: ${widget.feed.type}');
      print('New Title: $name');
      print('Sources: $validSources');
      print('Filters: $_filters');
      print('Digest Interval Hours: $digestIntervalHours');
      print('=================================');

      final success = await FeedBuilderService.updateExistingFeed(
        feedId: widget.feed.id,
        title: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        sources: validSources,
        digestIntervalHours: digestIntervalHours,
        type: widget.feed.type.apiValue,
        filters: _filters.isEmpty ? null : _filters,
        views: _views.isEmpty ? null : _views,
      );

      if (success && mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('FeedEditBottomSheet: Error saving: $e');
      }
      if (mounted) {
        _showError(AppLocalizations.of(context)!.feedEditFailedToSave);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await ConfirmationModal.showConfirmation(
      context: context,
      icon: CupertinoIcons.trash,
      title: l10n.feedEditDeleteFeedTitle,
      message: l10n.feedEditDeleteFeedMessage(widget.feed.name),
      cancelText: l10n.cancel,
      confirmText: l10n.delete,
      isDestructive: true,
    );

    if (confirmed == true) {
      await _deleteFeed();
    }
  }

  Future<void> _deleteFeed() async {
    setState(() => _isDeleting = true);

    try {
      await NewsService.deleteFeedSubscription(widget.feed.id);
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('FeedEditBottomSheet: Error deleting: $e');
      }
      if (mounted) {
        setState(() => _isDeleting = false);
        _showError(AppLocalizations.of(context)!.feedEditFailedToDelete);
      }
    }
  }

  void _showError(String message) {
    ConfirmationModal.showAlert(
      context: context,
      icon: CupertinoIcons.exclamationmark_circle,
      title: AppLocalizations.of(context)!.feedEditError,
      message: message,
      buttonText: 'OK',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final surfaceColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.15)
        : const Color(0xFF000000).withValues(alpha: 0.1);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.4, 0.85, 0.95],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: borderColor, width: 1),
                  left: BorderSide(color: borderColor, width: 0.5),
                  right: BorderSide(color: borderColor, width: 0.5),
                ),
              ),
              child: _isLoading
                  ? _buildSkeletonContent(scrollController)
                  : _buildFormContent(scrollController),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonContent(ScrollController scrollController) {
    final isDark = ThemeService().isDarkMode;
    final secondaryColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return SingleChildScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                _buildDragHandle(secondaryColor),
                const SizedBox(height: 16),

                // Header skeleton
                _buildHeaderSkeleton(),
                const SizedBox(height: 32),

                // Name field skeleton
                TextFieldSkeleton(
                  shimmerValue: _shimmerController.value,
                  labelWidth: 70,
                ),
                const SizedBox(height: 24),

                // Sources section skeleton
                SourceListSkeleton(
                  shimmerValue: _shimmerController.value,
                  itemCount: 3,
                ),

                // Schedule picker skeleton (if digest)
                if (_isDigest) ...[
                  const SizedBox(height: 24),
                  SchedulePickerSkeleton(
                    shimmerValue: _shimmerController.value,
                    optionCount: 5,
                  ),
                ],

                const SizedBox(height: 32),

                // Save button skeleton
                ButtonSkeleton(shimmerValue: _shimmerController.value),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSkeleton() {
    return Row(
      children: [
        ShimmerBar(
          width: 28,
          height: 28,
          shimmerValue: _shimmerController.value,
          borderRadius: 14,
        ),
        const Spacer(),
        ShimmerBar(
          width: 120,
          height: 20,
          shimmerValue: _shimmerController.value,
          borderRadius: 6,
        ),
        const Spacer(),
        ShimmerBar(
          width: 28,
          height: 28,
          shimmerValue: _shimmerController.value,
          borderRadius: 14,
        ),
      ],
    );
  }

  Widget _buildFormContent(ScrollController scrollController) {
    final isDark = ThemeService().isDarkMode;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;
    final backgroundColor = isDark ? AppColors.background : AppColors.lightBackground;

    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: Column(
        children: [
          // Fixed header with drag handle and actions
          _buildHeader(textColor, secondaryColor),

          // Scrollable form content
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field with AI generate button
                  _buildNameSection(textColor, secondaryColor, accentColor, isDark),
                  const SizedBox(height: 24),

                  // Sources section
                  _buildSourcesSection(textColor, secondaryColor, accentColor, isDark),
                  const SizedBox(height: 24),

                  // Filters section
                  _buildFiltersSection(textColor, secondaryColor, accentColor, isDark),
                  const SizedBox(height: 24),

                  // Views section
                  _buildViewsSection(textColor, secondaryColor, accentColor, isDark),

                  // Schedule picker (digest only)
                  if (_isDigest) ...[
                    const SizedBox(height: 24),
                    _buildScheduleSection(textColor, secondaryColor, isDark),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Fixed bottom actions
          _buildBottomActions(accentColor, isDark, backgroundColor),
        ],
      ),
    );
  }

  Widget _buildDragHandle(Color secondaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: secondaryColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color secondaryColor) {
    return Column(
      children: [
        _buildDragHandle(secondaryColor),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              // Close button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: secondaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.xmark,
                    color: secondaryColor,
                    size: 16,
                  ),
                ),
              ),

              // Title
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.feedEditTitle,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Delete button
              _isDeleting
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CupertinoActivityIndicator(),
                    )
                  : CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _confirmDelete,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: CupertinoColors.destructiveRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.trash,
                          color: CupertinoColors.destructiveRed,
                          size: 16,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildNameSection(
    Color textColor,
    Color secondaryColor,
    Color accentColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppLocalizations.of(context)!.feedEditName, textColor),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _nameController,
                placeholder: AppLocalizations.of(context)!.feedEditNameHint,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surface
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF333333)
                        : const Color(0xFFE5E5E5),
                    width: 1,
                  ),
                ),
                style: TextStyle(color: textColor),
                placeholderStyle: TextStyle(color: secondaryColor),
                cursorColor: textColor,
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.all(10),
              color: accentColor,
              borderRadius: BorderRadius.circular(10),
              onPressed: _isGeneratingTitle ? null : _generateTitle,
              child: _isGeneratingTitle
                  ? CupertinoActivityIndicator(
                      color: isDark ? CupertinoColors.black : CupertinoColors.white,
                    )
                  : Icon(
                      CupertinoIcons.sparkles,
                      color: isDark ? CupertinoColors.black : CupertinoColors.white,
                      size: 20,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourcesSection(
    Color textColor,
    Color secondaryColor,
    Color accentColor,
    bool isDark,
  ) {
    // Lighter card background
    final cardColor = isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF5F5F5);
    final borderColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppLocalizations.of(context)!.feedEditSources, textColor),
        const SizedBox(height: 8),

        // Row with card and + button outside
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Card with chips and inline input
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_isAddingSource) {
                    setState(() => _isAddingSource = true);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _sourceInputFocusNode.requestFocus();
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAddingSource ? accentColor : borderColor,
                      width: 1,
                    ),
                  ),
                  child: _sources.isEmpty && !_isAddingSource
                      ? Text(
                          '@channel, https://...',
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 14,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Source chips
                            ..._sources.asMap().entries.map((entry) => _SourceChip(
                                  key: ValueKey('src_${entry.key}_${entry.value.originalInput}'),
                                  source: entry.value,
                                  onRemove: () => _removeSource(entry.key),
                                  onRetry: entry.value.status == SourceValidationStatus.error
                                      ? () => _retrySource(entry.key)
                                      : null,
                                  isDark: isDark,
                                )),

                            // Inline input field when adding
                            if (_isAddingSource)
                              SizedBox(
                                width: 150,
                                child: CupertinoTextField(
                                  controller: _sourceController,
                                  focusNode: _sourceInputFocusNode,
                                  placeholder: AppLocalizations.of(context)!.slideContentSourceHint,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.background
                                        : AppColors.lightBackground,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  cursorColor: accentColor,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                  ),
                                  placeholderStyle: TextStyle(
                                    color: secondaryColor,
                                    fontSize: 14,
                                  ),
                                  textInputAction: TextInputAction.done,
                                  keyboardType: TextInputType.url,
                                  onSubmitted: (_) {
                                    _addSource();
                                    // Stay in adding mode for more sources
                                    _sourceInputFocusNode.requestFocus();
                                  },
                                  onTapOutside: (_) {
                                    _addSource();
                                    _sourceInputFocusNode.unfocus();
                                  },
                                ),
                              ),
                            // Error message below chips
                            if (_sources.any((s) =>
                                (s.status == SourceValidationStatus.invalid ||
                                 s.status == SourceValidationStatus.error) &&
                                s.errorMessage != null))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _sources.firstWhere((s) =>
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
              ),
            ),

            const SizedBox(width: 12),

            // Circular + button outside the card
            _AddButton(
              isDark: isDark,
              isCircular: true,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isAddingSource = true);
                Future.delayed(const Duration(milliseconds: 100), () {
                  _sourceInputFocusNode.requestFocus();
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScheduleSection(
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppLocalizations.of(context)!.feedEditSchedule, textColor),
        const SizedBox(height: 8),
        _SchedulePicker(
          value: _digestIntervalMinutes,
          onChanged: (value) {
            setState(() => _digestIntervalMinutes = value);
            HapticFeedback.selectionClick();
          },
          textColor: textColor,
          secondaryColor: secondaryColor,
          isDark: isDark,
          l10n: AppLocalizations.of(context)!,
        ),
      ],
    );
  }

  Widget _buildBottomActions(Color accentColor, bool isDark, Color backgroundColor) {
    final borderColor = isDark
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.1)
        : const Color(0xFF000000).withValues(alpha: 0.05);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: GestureDetector(
        onTap: _isSaving ? null : _save,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: _isSaving
                ? LoadingAnimationWidget.staggeredDotsWave(
                    color: isDark ? CupertinoColors.black : CupertinoColors.white,
                    size: 22,
                  )
                : Text(
                    AppLocalizations.of(context)!.feedEditSave,
                    style: TextStyle(
                      color: isDark ? CupertinoColors.black : CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(localizations.feedDescription, textColor),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _descriptionController,
          placeholder: localizations.feedDescriptionPlaceholder,
          padding: const EdgeInsets.all(12),
          maxLines: 3,
          minLines: 3,
          maxLength: 500,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surface
                : AppColors.lightBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF333333)
                  : const Color(0xFFE5E5E5),
              width: 1,
            ),
          ),
          style: TextStyle(color: textColor),
          placeholderStyle: TextStyle(color: secondaryColor),
        ),
      ],
    );
  }

  Widget _buildFiltersSection(
    Color textColor,
    Color secondaryColor,
    Color accentColor,
    bool isDark,
  ) {
    // Lighter card background
    final cardColor = isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF5F5F5);
    final borderColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppLocalizations.of(context)!.feedEditFilters, textColor),
        const SizedBox(height: 8),

        // Row with card and + button outside
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Card with chips and inline input (same structure as Sources)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_isAddingFilter) {
                    setState(() => _isAddingFilter = true);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _filterFocusNode.requestFocus();
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAddingFilter ? accentColor : borderColor,
                      width: 1,
                    ),
                  ),
                  child: _filters.isEmpty && !_isAddingFilter
                      ? Text(
                          AppLocalizations.of(context)!.feedEditFilterHint,
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 14,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Filter chips
                            ..._filters.asMap().entries.map((entry) => _FilterChip(
                                  filter: entry.value,
                                  onRemove: () => _removeFilter(entry.key),
                                  isDark: isDark,
                                  textColor: textColor,
                                )),

                            // Inline input field when adding
                            if (_isAddingFilter)
                              SizedBox(
                                width: 120,
                                child: CupertinoTextField(
                                  controller: _filterController,
                                  focusNode: _filterFocusNode,
                                  placeholder: AppLocalizations.of(context)!.feedEditFilterHint,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.background
                                        : AppColors.lightBackground,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  cursorColor: accentColor,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                  ),
                                  placeholderStyle: TextStyle(
                                    color: secondaryColor,
                                    fontSize: 14,
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) {
                                    _addFilter();
                                    // Stay in adding mode for more filters
                                    _filterFocusNode.requestFocus();
                                  },
                                  onTapOutside: (_) {
                                    _addFilter();
                                    _filterFocusNode.unfocus();
                                  },
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Circular + button outside the card
            _AddButton(
              isDark: isDark,
              isCircular: true,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isAddingFilter = true);
                Future.delayed(const Duration(milliseconds: 100), () {
                  _filterFocusNode.requestFocus();
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildViewsSection(
    Color textColor,
    Color secondaryColor,
    Color accentColor,
    bool isDark,
  ) {
    final cardColor = isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF5F5F5);
    final borderColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppLocalizations.of(context)!.feedEditViews, textColor),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_isAddingView) {
                    setState(() => _isAddingView = true);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _viewFocusNode.requestFocus();
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAddingView ? accentColor : borderColor,
                      width: 1,
                    ),
                  ),
                  child: _views.isEmpty && !_isAddingView
                      ? Text(
                          AppLocalizations.of(context)!.feedEditViewHint,
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 14,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ..._views.asMap().entries.map((entry) => _FilterChip(
                                  filter: entry.value,
                                  onRemove: () => _removeView(entry.key),
                                  isDark: isDark,
                                  textColor: textColor,
                                )),

                            if (_isAddingView)
                              SizedBox(
                                width: 120,
                                child: CupertinoTextField(
                                  controller: _viewController,
                                  focusNode: _viewFocusNode,
                                  placeholder: AppLocalizations.of(context)!.feedEditViewHint,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.background
                                        : AppColors.lightBackground,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  cursorColor: accentColor,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                  ),
                                  placeholderStyle: TextStyle(
                                    color: secondaryColor,
                                    fontSize: 14,
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) {
                                    _addView();
                                    _viewFocusNode.requestFocus();
                                  },
                                  onTapOutside: (_) {
                                    _addView();
                                    _viewFocusNode.unfocus();
                                  },
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            _AddButton(
              isDark: isDark,
              isCircular: true,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isAddingView = true);
                Future.delayed(const Duration(milliseconds: 100), () {
                  _viewFocusNode.requestFocus();
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Source chip with validation states (validating, valid, invalid, error)
class _SourceChip extends StatefulWidget {
  final ValidatedSource source;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;
  final bool isDark;

  const _SourceChip({
    super.key,
    required this.source,
    required this.onRemove,
    this.onRetry,
    required this.isDark,
  });

  @override
  State<_SourceChip> createState() => _SourceChipState();
}

class _SourceChipState extends State<_SourceChip>
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
  void didUpdateWidget(_SourceChip oldWidget) {
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
      chipBorderColor = CupertinoColors.destructiveRed.withValues(alpha: 0.6);
    } else if (isValid) {
      chipBorderColor = accentColor.withValues(alpha: 0.5);
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
                    fontSize: 14,
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

/// Filter chip with checkmark and X button
class _FilterChip extends StatelessWidget {
  final String filter;
  final VoidCallback onRemove;
  final bool isDark;
  final Color textColor;

  const _FilterChip({
    required this.filter,
    required this.onRemove,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.background : AppColors.lightBackground;
    final borderColor = isDark ? AppColors.accentSecondary : AppColors.lightAccentSecondary;
    final secondaryColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Checkmark icon
          Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 14,
            color: accentColor,
          ),
          const SizedBox(width: 6),
          // Filter text
          Flexible(
            child: Text(
              filter,
              style: TextStyle(color: textColor, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          // X button
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 16,
              color: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Beautiful "+" button with tap animation
/// [isCircular] - true for circle shape, false for rounded rectangle
class _AddButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;
  final bool isCircular;

  const _AddButton({
    required this.isDark,
    required this.onTap,
    this.isCircular = true,
  });

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Black button in light mode, white in dark mode
    final buttonColor = widget.isDark
        ? CupertinoColors.white
        : CupertinoColors.black;
    final iconColor = widget.isDark
        ? CupertinoColors.black
        : CupertinoColors.white;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: widget.isCircular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircular ? null : BorderRadius.circular(10),
            color: buttonColor,
          ),
          child: Icon(
            CupertinoIcons.plus,
            color: iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _SchedulePicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final Color textColor;
  final Color secondaryColor;
  final bool isDark;
  final AppLocalizations l10n;

  const _SchedulePicker({
    required this.value,
    required this.onChanged,
    required this.textColor,
    required this.secondaryColor,
    required this.isDark,
    required this.l10n,
  });

  static const _optionMinutes = [60, 180, 360, 720, 1440];

  @override
  Widget build(BuildContext context) {
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;

    final optionLabels = {
      60: l10n.feedEditEveryHour,
      180: l10n.feedEditEvery3Hours,
      360: l10n.feedEditEvery6Hours,
      720: l10n.feedEditEvery12Hours,
      1440: l10n.feedEditOnceADay,
    };

    return Column(
      children: _optionMinutes.map((minutes) {
        final isSelected = value == minutes;
        final label = optionLabels[minutes]!;

        return GestureDetector(
          onTap: () => onChanged(minutes),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.15)
                  : (isDark
                      ? CupertinoColors.systemGrey6.darkColor
                      : CupertinoColors.systemGrey6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? accentColor : Colors.transparent,
                width: isSelected ? 2 : 0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  size: 20,
                  color: isSelected ? accentColor : secondaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
