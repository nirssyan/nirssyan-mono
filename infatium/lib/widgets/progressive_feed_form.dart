import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/feed_builder_models.dart';
import '../models/source_validation_models.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../theme/colors.dart';
import 'ai_view_selector.dart';
import 'confirmation_modal.dart';
import 'feed_slides/slide_feed_type.dart';
import 'feed_slides/slide_content.dart';
import 'feed_slides/slide_configuration.dart';
import 'feed_slides/slide_finalize.dart';

/// Progressive feed creation form with 4 horizontal slides.
/// Slide 1: Feed Type Selection + Frequency
/// Slide 2: Sources Input
/// Slide 3: Configuration (Views + Filters)
/// Slide 4: Preview + Create
class ProgressiveFeedForm extends StatefulWidget {
  final LocaleService localeService;
  final Future<void> Function({
    String? title,
    String? description,
    List<String>? tags,
    required String prompt,
    required List<String> sources,
    required FeedType type,
    required List<String> filters,
    required List<String> views,
    int? digestIntervalMinutes,
  }) onSubmit;

  // Initial values for pre-filling form from preview (edit mode)
  final String? initialTitle;
  final String? initialPrompt;
  final List<String>? initialSources;
  final FeedType? initialType;
  final List<String>? initialFilters;
  final List<String>? initialViews;
  final int? initialDigestIntervalMinutes;

  // Edit mode - when true, button shows "Save" instead of "Create"
  final bool isEditMode;

  // Callback for generating a title via AI
  final Future<String?> Function()? onGenerateTitle;

  const ProgressiveFeedForm({
    super.key,
    required this.localeService,
    required this.onSubmit,
    this.initialTitle,
    this.initialPrompt,
    this.initialSources,
    this.initialType,
    this.initialFilters,
    this.initialViews,
    this.initialDigestIntervalMinutes,
    this.isEditMode = false,
    this.onGenerateTitle,
  });

  @override
  State<ProgressiveFeedForm> createState() => ProgressiveFeedFormState();
}

class ProgressiveFeedFormState extends State<ProgressiveFeedForm>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  // Form state
  FeedType? _selectedType;
  List<ValidatedSource> _sources = [];
  AIViewStyle _viewStyle = AIViewStyle.essence;
  String? _customPrompt;
  String _feedName = '';
  int _digestIntervalHours = 6;
  List<String> _selectedViews = [];
  List<String> _selectedFilters = [];
  List<String> _customViews = [];
  List<String> _customFilters = [];
  bool _isSubmitting = false;

  bool get _isDark => ThemeService().isDarkMode;

  bool get _hasValidSources =>
      _sources.any((s) => s.status == SourceValidationStatus.valid);

  // Public getters for parent to access form values
  String get promptValue {
    // Only return prompt for custom style, predefined styles don't need views_raw
    if (_viewStyle == AIViewStyle.custom) {
      return _customPrompt ?? '';
    }
    return '';
  }

  /// Returns validated sources as display names (for backward compatibility)
  List<String> get sourcesValue => _sources
      .where((s) => s.status == SourceValidationStatus.valid)
      .map((s) => s.displayName)
      .toList();

  /// Returns validated sources with full info for API calls
  List<ValidatedSource> get validatedSourcesValue => _sources
      .where((s) => s.status == SourceValidationStatus.valid)
      .toList();

  FeedType get feedTypeValue => _selectedType ?? FeedType.SINGLE_POST;

  List<String> get filtersValue => _selectedFilters;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _pageController.addListener(_onPageChanged);

    // Initialize with initial values (edit mode)
    _initializeFromProps();
  }

  void _initializeFromProps() {
    if (widget.initialType != null) {
      _selectedType = widget.initialType;
      _currentPage = widget.initialSources?.isNotEmpty == true ? 2 : 1;
    }

    if (widget.initialSources != null && widget.initialSources!.isNotEmpty) {
      _sources = widget.initialSources!.map((s) => ValidatedSource(
        originalInput: s,
        shortName: s,
        status: SourceValidationStatus.valid,
      )).toList();
    }

    _feedName = widget.initialTitle ?? '';
    _customPrompt = widget.initialPrompt;
    _selectedFilters = widget.initialFilters != null
        ? List.from(widget.initialFilters!)
        : [];
    _selectedViews = widget.initialViews != null
        ? List.from(widget.initialViews!)
        : [];
    // Convert initial minutes to hours for edit mode compatibility
    _digestIntervalHours = widget.initialDigestIntervalMinutes != null
        ? (widget.initialDigestIntervalMinutes! / 60).round().clamp(1, 168)
        : 6;

    // Try to parse view style from initial prompt
    if (widget.initialPrompt != null) {
      _viewStyle = AIViewStyle.custom;
    }

    // Jump to appropriate page in edit mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPage > 0 && _pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    });
  }

  /// Reset form to initial empty state (for after successful creation)
  void resetForm() {
    setState(() {
      _currentPage = 0;
      _selectedType = null;
      _sources = [];
      _viewStyle = AIViewStyle.essence;
      _customPrompt = null;
      _feedName = '';
      _digestIntervalHours = 6;
      _selectedViews = [];
      _selectedFilters = [];
      _customViews = [];
      _customFilters = [];
      _isSubmitting = false;
    });

    // Jump back to first page
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  void didUpdateWidget(ProgressiveFeedForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialType != oldWidget.initialType ||
        widget.initialSources != oldWidget.initialSources ||
        widget.isEditMode != oldWidget.isEditMode) {
      _initializeFromProps();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  void _onTypeSelected(FeedType type) {
    setState(() => _selectedType = type);
    // Don't auto-advance - wait for "Next" button
  }

  void _goToNextPage() {
    if (_pageController.hasClients && _currentPage < 3) {
      HapticFeedback.mediumImpact();
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goToPreviousPage() {
    if (_pageController.hasClients && _currentPage > 0) {
      HapticFeedback.selectionClick();
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onSourcesChanged(List<ValidatedSource> sources) {
    setState(() => _sources = sources);
  }

  void _onViewStyleChanged(AIViewStyle style) {
    setState(() {
      _viewStyle = style;
      if (style != AIViewStyle.custom) {
        _customPrompt = null;
      }
    });
  }

  void _onCustomPromptChanged(String? prompt) {
    setState(() => _customPrompt = prompt);
  }

  void _onNameChanged(String name) {
    setState(() => _feedName = name);
  }

  void _onIntervalChanged(int hours) {
    setState(() => _digestIntervalHours = hours);
  }

  Future<void> _handleSubmit() async {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedType == null) {
      _showError(l10n.formSelectFeedType);
      return;
    }

    if (_sources.isEmpty) {
      _showError(l10n.formAddSource);
      return;
    }

    if (_sources.any((s) => s.status == SourceValidationStatus.validating)) {
      _showError(l10n.formWaitForValidation);
      return;
    }

    final validSources = _sources
        .where((s) => s.status == SourceValidationStatus.valid)
        .map((s) => s.displayName)
        .toList();

    if (validSources.isEmpty) {
      _showError(l10n.formAddValidSource);
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      await widget.onSubmit(
        title: _feedName.isNotEmpty ? _feedName : null,
        description: null,
        tags: null,
        prompt: promptValue,
        sources: validSources,
        type: _selectedType!,
        filters: _selectedFilters,
        views: _selectedViews,
        digestIntervalMinutes:
            _selectedType == FeedType.DIGEST ? _digestIntervalHours * 60 : null,
      );
    } catch (e) {
      _showError(_getUserFriendlyErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Converts exception to a user-friendly message
  String _getUserFriendlyErrorMessage(dynamic error) {
    final l10n = AppLocalizations.of(context)!;
    final errorStr = error.toString();

    // Parse HTTP status code from exception (format: "Exception: ... : 404")
    final statusMatch = RegExp(r': (\d{3})$').firstMatch(errorStr);
    if (statusMatch != null) {
      final statusCode = int.tryParse(statusMatch.group(1) ?? '');
      if (statusCode != null) {
        if (statusCode == 400) {
          return l10n.formCreateFailed;
        } else if (statusCode == 401 || statusCode == 403) {
          return l10n.formAuthError;
        } else if (statusCode == 402) {
          return l10n.formLimitReached;
        } else if (statusCode == 404) {
          return l10n.formSomethingWentWrong;
        } else if (statusCode >= 500) {
          return l10n.formServerError;
        } else if (statusCode >= 400) {
          return l10n.formCreateError;
        }
      }
    }

    // Network errors
    if (errorStr.contains('SocketException') ||
        errorStr.contains('TimeoutException') ||
        errorStr.contains('Connection')) {
      return l10n.formNetworkError;
    }

    // Default message
    return l10n.formUnexpectedError;
  }

  void _showError(String message) {
    final l10n = AppLocalizations.of(context)!;
    HapticFeedback.heavyImpact();
    ConfirmationModal.showAlert(
      context: context,
      icon: CupertinoIcons.exclamationmark_circle,
      title: l10n.error,
      message: message,
      buttonText: 'OK',
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isDark ? AppColors.background : AppColors.lightBackground;

    return Container(
      color: backgroundColor,
      child: Stack(
        children: [
          // PageView with 4 slides - swipes disabled, navigation via buttons only
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Disable swipes
            children: [
              // Slide 1: Feed Type + Frequency
              SlideFeedType(
                localeService: widget.localeService,
                selectedType: _selectedType,
                onTypeSelected: _onTypeSelected,
                digestIntervalHours: _digestIntervalHours,
                onIntervalChanged: _onIntervalChanged,
                onNext: _selectedType != null ? _goToNextPage : null,
              ),

              // Slide 2: Sources Input
              SlideContent(
                localeService: widget.localeService,
                sources: _sources,
                onSourcesChanged: _onSourcesChanged,
                viewStyle: _viewStyle,
                onViewStyleChanged: _onViewStyleChanged,
                customPrompt: _customPrompt,
                onCustomPromptChanged: _onCustomPromptChanged,
                onNext: _hasValidSources ? _goToNextPage : null,
                onBack: _goToPreviousPage,
              ),

              // Slide 3: Configuration (Views + Filters)
              SlideConfiguration(
                localeService: widget.localeService,
                selectedViews: _selectedViews,
                onViewsChanged: (views) => setState(() => _selectedViews = views),
                selectedFilters: _selectedFilters,
                onFiltersChanged: (filters) => setState(() => _selectedFilters = filters),
                customViews: _customViews,
                onCustomViewsChanged: (views) => setState(() => _customViews = views),
                customFilters: _customFilters,
                onCustomFiltersChanged: (filters) => setState(() => _customFilters = filters),
                onNext: _goToNextPage,
                onBack: _goToPreviousPage,
              ),

              // Slide 4: Preview + Create
              SlideFinalize(
                localeService: widget.localeService,
                feedType: _selectedType ?? FeedType.SINGLE_POST,
                digestIntervalHours: _digestIntervalHours,
                sources: _sources,
                selectedViews: _selectedViews,
                selectedFilters: _selectedFilters,
                feedName: _feedName,
                onNameChanged: _onNameChanged,
                onSubmit: _handleSubmit,
                onGenerateTitle: widget.onGenerateTitle,
                isSubmitting: _isSubmitting,
                isEditMode: widget.isEditMode,
                onBack: _goToPreviousPage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
