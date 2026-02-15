import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/locale_service.dart';
import '../services/feed_builder_service.dart';
import '../services/theme_service.dart';
import '../services/navigation_service.dart';
import '../models/feed_builder_models.dart';
import '../theme/colors.dart';
import '../widgets/progressive_feed_form.dart';
import '../widgets/confirmation_modal.dart';
import '../navigation/main_tab_scaffold.dart';
import '../l10n/generated/app_localizations.dart';


/// Обертка для второго таба для создания лент (Feed Builder)
class FeedBuilderTabPage extends StatefulWidget {
  final LocaleService localeService;

  const FeedBuilderTabPage({super.key, required this.localeService});

  @override
  State<FeedBuilderTabPage> createState() => FeedBuilderTabPageState();
}

class FeedBuilderTabPageState extends State<FeedBuilderTabPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Сохраняем состояние виджета при переключении табов

  // Preview data for pre-filling FeedCreatorForm
  FeedPreview? _previewData;

  // Edit mode state - when editing existing feed vs creating new
  bool _isEditMode = false;
  String? _editingFeedId;

  // Key for accessing ProgressiveFeedForm state
  final _formKey = GlobalKey<ProgressiveFeedFormState>();

  @override
  void initState() {
    super.initState();

    // Тестируем API подключение
    if (kDebugMode) {
      FeedBuilderService.testApiConnection();
    }

    // Слушаем изменения темы для перестроения UI
    ThemeService().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    // Принудительно перестраиваем UI при смене темы
    if (mounted) {
      setState(() {});
    }
  }

  /// Handle form submission - creates or updates feed depending on mode
  Future<void> _handleFeedFormSubmit({
    String? title,
    String? description,
    List<String>? tags,
    required String prompt,
    required List<String> sources,
    required FeedType type,
    required List<String> filters,
    required List<String> views,
    int? digestIntervalMinutes,
  }) async {
    try {
      // Check if we're in edit mode
      if (_isEditMode && _editingFeedId != null) {
        // PATCH existing feed
        // Convert minutes to hours for API (round up to nearest hour)
        final digestIntervalHours = digestIntervalMinutes != null
            ? (digestIntervalMinutes / 60).ceil()
            : null;

        // Convert source strings to objects with url and type
        final sourceObjects = sources.map((s) => {
          'url': s,
          'type': 'TELEGRAM',  // Default type for feed builder flow
        }).toList();

        // Combine selected views with custom prompt for edit mode
        final combinedViewsEdit = <String>[...views];
        if (prompt.isNotEmpty) combinedViewsEdit.add(prompt);

        final success = await FeedBuilderService.updateExistingFeed(
          feedId: _editingFeedId!,
          title: title,
          prompt: prompt,
          sources: sourceObjects,
          type: type.apiValue,
          digestIntervalHours: digestIntervalHours,
          filters: filters,
          views: combinedViewsEdit.isNotEmpty ? combinedViewsEdit : null,
        );

        if (success && mounted) {
          HapticFeedback.mediumImpact();
          final l10n = AppLocalizations.of(context)!;
          _showSuccess(l10n.feedSavedSuccess);

          // Reset edit mode and switch to Home tab
          setState(() {
            _isEditMode = false;
            _editingFeedId = null;
            _previewData = null;
          });

          // Switch to Home tab to see the updated feed (with refresh)
          context.findAncestorStateOfType<MainTabScaffoldState>()?.navigateToHomeWithRefresh();
        }
      } else {
        // CREATE new feed - single request via POST /feeds/create
        // Convert minutes to hours for API (round up to nearest hour)
        final digestIntervalHours = digestIntervalMinutes != null
            ? (digestIntervalMinutes / 60).ceil()
            : null;

        // Get validated sources with type info from form state
        final validatedSources = _formKey.currentState?.validatedSourcesValue ?? [];

        // Convert ValidatedSource to SourceItem for API
        final sourceItems = validatedSources.map((vs) => SourceItem(
          url: vs.originalInput,
          type: vs.sourceType ?? 'RSS', // Default to RSS if type unknown
        )).toList();

        // Combine selected views with custom prompt
        final combinedViews = <String>[...views];
        if (prompt.isNotEmpty) combinedViews.add(prompt);

        // STEP 1: Call API FIRST (button shows loader via _isSubmitting in form)
        final createResponse = await FeedBuilderService.createFeedDirect(
          name: title, // Optional - backend generates if null
          sources: sourceItems,
          feedType: type,
          viewsRaw: combinedViews.isNotEmpty ? combinedViews : null,
          filtersRaw: filters.isNotEmpty ? filters : null,
          digestIntervalHours: digestIntervalHours,
        );

        // STEP 2: After API success - navigate to Home with loading overlay
        print('[ChatTabPage] createResponse.feedId: ${createResponse.feedId}');
        if (createResponse.feedId != null) {
          print('[ChatTabPage] Feed created! Navigating to home...');
          HapticFeedback.mediumImpact();
          _formKey.currentState?.resetForm();

          print('[ChatTabPage] Calling navigateToHomeWithPendingFeed...');
          NavigationService().navigateToHomeWithPendingFeed(
            feedName: title,
            feedType: type.apiValue,
          );

          // STEP 3: Pass feedId immediately for WebSocket waiting
          print('[ChatTabPage] Calling updatePendingFeedId with feedId: ${createResponse.feedId}');
          NavigationService().updatePendingFeedId(
            createResponse.feedId!,
            feedName: title,
            feedType: type.apiValue,
          );
          print('[ChatTabPage] updatePendingFeedId called');
        } else {
          print('[ChatTabPage] createResponse.feedId is NULL!');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ChatTabPage: Error in form submission: $e');
      }
      rethrow;
    }
  }

  void _showError(String message) {
    final l10n = AppLocalizations.of(context)!;
    ConfirmationModal.showAlert(
      context: context,
      icon: CupertinoIcons.exclamationmark_circle,
      title: l10n.error,
      message: message,
      buttonText: 'OK',
    );
  }

  void _showSuccess(String message) {
    final l10n = AppLocalizations.of(context)!;
    ConfirmationModal.showAlert(
      context: context,
      icon: CupertinoIcons.checkmark_circle,
      title: l10n.success,
      message: message,
      buttonText: 'OK',
      iconColor: CupertinoColors.activeGreen,
    );
  }

  /// Handle generate title button click - uses direct API without creating chat
  Future<String?> _handleGenerateTitle() async {
    // Edit mode: use existing feed ID directly (legacy API still needed for edits)
    if (_isEditMode && _editingFeedId != null) {
      return await FeedBuilderService.generateFeedTitle(_editingFeedId!);
    }

    // Create mode: use direct API without chat
    final formState = _formKey.currentState;
    if (formState == null) {
      return null;
    }

    final prompt = formState.promptValue;
    final validatedSources = formState.validatedSourcesValue;
    final feedType = formState.feedTypeValue;
    final filters = formState.filtersValue;

    // Validate that we have sources to generate title
    if (validatedSources.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      _showError(l10n.addAtLeastOneSource);
      return null;
    }

    // Convert ValidatedSource to SourceItem for API
    final sourceItems = validatedSources.map((vs) => SourceItem(
      url: vs.originalInput,
      type: vs.sourceType ?? 'RSS',
    )).toList();

    try {
      return await FeedBuilderService.generateTitleDirect(
        sources: sourceItems,
        feedType: feedType,
        viewsRaw: prompt.isNotEmpty ? [prompt] : null,
        filtersRaw: filters.isNotEmpty ? filters : null,
      );
    } catch (e) {
      if (kDebugMode) {
        print('ChatTabPage: Error in handleGenerateTitle: $e');
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Важно для AutomaticKeepAliveClientMixin

    // Main content - only ProgressiveFeedForm
    return AnimatedBuilder(
      animation: ThemeService(),
      builder: (context, child) {
        final isDark = ThemeService().isDarkMode;
        final backgroundColor = isDark ? AppColors.background : AppColors.lightBackground;

        return CupertinoPageScaffold(
          backgroundColor: backgroundColor,
          child: SafeArea(
            bottom: false, // Don't shift content when system insets update
            child: Column(
              children: [
                // Header spacer for consistent layout
                const SizedBox(height: 16),

                // Progressive Feed Form (single content)
                Expanded(
                  child: ProgressiveFeedForm(
                    key: _formKey,
                    localeService: widget.localeService,
                    onSubmit: _handleFeedFormSubmit,
                    onGenerateTitle: _handleGenerateTitle,
                    initialTitle: _previewData?.name,
                    initialPrompt: _previewData?.prompt,
                    initialSources: _previewData?.sources.map((s) => s.getLabel(
                        widget.localeService.currentLocale.languageCode == 'ru')).toList(),
                    initialType: _previewData?.type != null
                        ? FeedType.values.firstWhere(
                            (t) => t.apiValue == _previewData!.type,
                            orElse: () => FeedType.SINGLE_POST,
                          )
                        : null,
                    initialFilters: _previewData?.filters?.map((f) => f.getLabel(
                        widget.localeService.currentLocale.languageCode == 'ru')).toList(),
                    initialViews: _previewData?.views?.map((v) => v.getLabel(
                        widget.localeService.currentLocale.languageCode == 'ru')).toList(),
                    initialDigestIntervalMinutes: _previewData?.digestIntervalHours != null
                        ? _previewData!.digestIntervalHours! * 60
                        : null,
                    isEditMode: _isEditMode,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
