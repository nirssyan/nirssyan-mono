import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';

import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../services/news_service.dart';
import '../services/feed_cache_service.dart';
import '../models/feed_models.dart';
import '../models/feed_builder_models.dart'; // For FeedType enum
import '../theme/colors.dart';
import '../l10n/generated/app_localizations.dart';
import '../navigation/main_tab_scaffold.dart';
import '../widgets/feed_edit_bottom_sheet.dart';
import '../widgets/confirmation_modal.dart';

class FeedsManagerPage extends StatefulWidget {
  final LocaleService localeService;

  const FeedsManagerPage({
    super.key,
    required this.localeService,
  });

  @override
  State<FeedsManagerPage> createState() => FeedsManagerPageState();
}

class FeedsManagerPageState extends State<FeedsManagerPage>
    with TickerProviderStateMixin {
  List<Feed> _feeds = [];
  bool _isLoading = true;
  bool _hasError = false;

  late AnimationController _emptyStateController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _emptyStateController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Listen to cache changes to update feed status
    FeedCacheService().addListener(_onCacheChanged);

    _loadFeeds();
  }

  @override
  void dispose() {
    FeedCacheService().removeListener(_onCacheChanged);
    _emptyStateController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadFeeds() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // First refresh from backend
      await NewsService.fetchUserFeedsHTTP(forceRefresh: true);
      final feeds = await NewsService.getUserFeeds();
      if (mounted) {
        setState(() {
          _feeds = feeds;
          _isLoading = false;
        });
        if (feeds.isEmpty) {
          _emptyStateController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// Handle cache changes to update feed status in real-time
  void _onCacheChanged() {
    if (!mounted) return;

    // Refresh feeds from cache
    final updatedFeeds = FeedCacheService().getCachedFeeds();
    if (updatedFeeds != null && updatedFeeds.isNotEmpty) {
      setState(() {
        _feeds = updatedFeeds;
      });
    }
  }

  /// Public method for refreshing feeds from outside
  void refreshFeeds() {
    _loadFeeds();
  }

  void _navigateToCreateTab() {
    context.findAncestorStateOfType<MainTabScaffoldState>()?.navigateToFeedCreator();
  }

  Future<void> _navigateToFeedDetail(Feed feed) async {
    final result = await FeedEditBottomSheet.show(
      context: context,
      feed: feed,
      localeService: widget.localeService,
    );

    // Refresh if feed was modified or deleted
    if (result == true) {
      _loadFeeds();
    }
  }

  Future<bool> _confirmDeleteFeed(Feed feed) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await ConfirmationModal.showConfirmation(
      context: context,
      icon: CupertinoIcons.trash,
      title: l10n.feedEditDeleteFeedTitle,
      message: l10n.feedEditDeleteFeedMessage(feed.name),
      cancelText: l10n.cancel,
      confirmText: l10n.delete,
      isDestructive: true,
    );
    return result ?? false;
  }

  Future<void> _performDeleteFeed(Feed feed) async {
    HapticFeedback.mediumImpact();
    try {
      await NewsService.deleteFeedSubscription(feed.id);
      if (mounted) {
        setState(() {
          _feeds.removeWhere((f) => f.id == feed.id);
        });
        if (_feeds.isEmpty) {
          _emptyStateController.forward();
        }
      }
    } catch (e) {
      print('FeedsManagerPage: Error deleting feed: $e');
      // Reload feeds on error to restore state
      if (mounted) {
        _loadFeeds();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final backgroundColor = isDark ? AppColors.background : AppColors.lightBackground;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  l10n.myFeeds,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: _buildContent(
                textColor,
                secondaryTextColor,
                backgroundColor,
                isDark,
                l10n,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    Color textColor,
    Color secondaryTextColor,
    Color backgroundColor,
    bool isDark,
    AppLocalizations l10n,
  ) {
    if (_isLoading) {
      return _buildSkeletonLoading(secondaryTextColor, backgroundColor, isDark);
    }

    if (_hasError) {
      return _buildErrorState(secondaryTextColor, l10n);
    }

    if (_feeds.isEmpty) {
      return _buildEmptyState(textColor, secondaryTextColor, isDark, l10n);
    }

    return _buildFeedsList(textColor, secondaryTextColor, backgroundColor, isDark);
  }

  Widget _buildSkeletonLoading(
    Color secondaryTextColor,
    Color backgroundColor,
    bool isDark,
  ) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: List.generate(4, (index) {
              return _SkeletonCard(
                shimmerValue: _shimmerController.value,
                secondaryTextColor: secondaryTextColor,
                backgroundColor: backgroundColor,
                isDark: isDark,
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(Color secondaryTextColor, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: secondaryTextColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.loadingError,
            style: TextStyle(color: secondaryTextColor),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            onPressed: _loadFeeds,
            child: Text(l10n.retryButton),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    Color textColor,
    Color secondaryTextColor,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;

    return FadeTransition(
      opacity: _emptyStateController,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Empty state icon (Lottie file was corrupted)
              Icon(
                CupertinoIcons.tray,
                size: 80,
                color: secondaryTextColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                l10n.noFeedsYet,
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                l10n.createFirstFeedHint,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // CTA Button
              _CreateFeedButton(
                onPressed: _navigateToCreateTab,
                accentColor: accentColor,
                isDark: isDark,
                label: l10n.createFeed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedsList(
    Color textColor,
    Color secondaryTextColor,
    Color backgroundColor,
    bool isDark,
  ) {
    return AnimationLimiter(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: _loadFeeds,
          ),
          SliverPadding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final feed = _feeds[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 400),
                    child: SlideAnimation(
                      verticalOffset: 30,
                      curve: Curves.easeOutCubic,
                      child: ScaleAnimation(
                        scale: 0.95,
                        curve: Curves.easeOutCubic,
                        child: FadeInAnimation(
                          curve: Curves.easeOut,
                          child: Dismissible(
                            key: Key('feed_${feed.id}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) => _confirmDeleteFeed(feed),
                            onDismissed: (direction) => _performDeleteFeed(feed),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: CupertinoColors.destructiveRed,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                CupertinoIcons.trash,
                                color: CupertinoColors.white,
                                size: 24,
                              ),
                            ),
                            child: _FeedListItem(
                              feed: feed,
                              textColor: textColor,
                              secondaryTextColor: secondaryTextColor,
                              backgroundColor: backgroundColor,
                              isDark: isDark,
                              localeService: widget.localeService,
                              onTap: () => _navigateToFeedDetail(feed),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _feeds.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedListItem extends StatefulWidget {
  final Feed feed;
  final Color textColor;
  final Color secondaryTextColor;
  final Color backgroundColor;
  final bool isDark;
  final LocaleService localeService;
  final VoidCallback onTap;

  const _FeedListItem({
    required this.feed,
    required this.textColor,
    required this.secondaryTextColor,
    required this.backgroundColor,
    required this.isDark,
    required this.localeService,
    required this.onTap,
  });

  @override
  State<_FeedListItem> createState() => _FeedListItemState();
}

class _FeedListItemState extends State<_FeedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _tapController.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    _tapController.reverse();
  }

  void _handleTapCancel() {
    _tapController.reverse();
  }

  void _handleTap() {
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sourcesCount = widget.feed.rawFeedsCount;
    final createdAt = widget.feed.createdAt;
    final feedType = widget.feed.type;

    final dateFormat = DateFormat('dd.MM.yyyy');
    final dateStr = dateFormat.format(createdAt);

    final typeStr = feedType == FeedType.DIGEST
        ? l10n.digestType
        : l10n.singlePostType;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // Clean white on light theme for better contrast
            color: widget.isDark
                ? AppColors.surfaceElevated
                : CupertinoColors.white,
            // More visible border on light theme
            border: Border.all(
              color: widget.isDark
                  ? CupertinoColors.white.withValues(alpha: 0.1)
                  : CupertinoColors.black.withValues(alpha: 0.08),
              width: 1,
            ),
            // Subtle shadow for depth on light theme
            boxShadow: widget.isDark
                ? null
                : [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row - clean minimalist design without icon
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.feed.name,
                          style: TextStyle(
                            color: widget.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          typeStr,
                          style: TextStyle(
                            color: widget.isDark
                                ? widget.secondaryTextColor.withValues(alpha: 0.7)
                                : widget.secondaryTextColor.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Chevron - more visible on light theme
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: widget.isDark
                        ? widget.secondaryTextColor.withValues(alpha: 0.5)
                        : widget.secondaryTextColor.withValues(alpha: 0.6),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stats row with pill badges
              Row(
                children: [
                  _TextBadge(
                    label: l10n.sourceCount(sourcesCount),
                    isDark: widget.isDark,
                  ),
                  const SizedBox(width: 8),
                  _ModernStatBadge(
                    icon: CupertinoIcons.calendar,
                    label: dateStr,
                    isDark: widget.isDark,
                  ),
                  const Spacer(),
                  // Status indicator (only for creating feeds)
                  if (widget.feed.isCreatingFinished == false)
                    _PulsingStatusIndicator(
                      label: l10n.feedItemCreating,
                      isDark: widget.isDark,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernStatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _ModernStatBadge({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        // Better contrast on light theme
        color: isDark
            ? CupertinoColors.white.withValues(alpha: 0.08)
            : CupertinoColors.black.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            // Better icon visibility on light theme
            color: isDark
                ? CupertinoColors.white.withValues(alpha: 0.5)
                : CupertinoColors.black.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              // Better text visibility on light theme
              color: isDark
                  ? CupertinoColors.white.withValues(alpha: 0.6)
                  : CupertinoColors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBadge extends StatelessWidget {
  final String label;
  final bool isDark;

  const _TextBadge({
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isDark
            ? CupertinoColors.white.withValues(alpha: 0.08)
            : CupertinoColors.black.withValues(alpha: 0.06),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark
              ? CupertinoColors.white.withValues(alpha: 0.6)
              : CupertinoColors.black.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _PulsingStatusIndicator extends StatefulWidget {
  final String label;
  final bool isDark;

  const _PulsingStatusIndicator({
    required this.label,
    required this.isDark,
  });

  @override
  State<_PulsingStatusIndicator> createState() => _PulsingStatusIndicatorState();
}

class _PulsingStatusIndicatorState extends State<_PulsingStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isDark ? CupertinoColors.white : CupertinoColors.black;
    final textColor = widget.isDark
        ? CupertinoColors.white.withValues(alpha: 0.7)
        : CupertinoColors.black.withValues(alpha: 0.6);
    final bgColor = widget.isDark
        ? CupertinoColors.white.withValues(alpha: 0.08)
        : CupertinoColors.black.withValues(alpha: 0.05);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: bgColor,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor.withValues(alpha: 0.4 + _controller.value * 0.6),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.2 + _controller.value * 0.3),
                      blurRadius: 4 + _controller.value * 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CreateFeedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color accentColor;
  final bool isDark;
  final String label;

  const _CreateFeedButton({
    required this.onPressed,
    required this.accentColor,
    required this.isDark,
    required this.label,
  });

  @override
  State<_CreateFeedButton> createState() => _CreateFeedButtonState();
}

class _CreateFeedButtonState extends State<_CreateFeedButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? CupertinoColors.black : CupertinoColors.white;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: BoxDecoration(
            color: widget.accentColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double shimmerValue;
  final Color secondaryTextColor;
  final Color backgroundColor;
  final bool isDark;

  const _SkeletonCard({
    required this.shimmerValue,
    required this.secondaryTextColor,
    required this.backgroundColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.06)
        : CupertinoColors.black.withValues(alpha: 0.04);
    final highlightColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : CupertinoColors.black.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Flat solid color - matching _FeedListItem
        color: isDark
            ? AppColors.surfaceElevated
            : AppColors.lightSurface,
        // Subtle border for separation
        border: Border.all(
          color: isDark
              ? CupertinoColors.white.withValues(alpha: 0.08)
              : CupertinoColors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row skeleton with icon
          Row(
            children: [
              // Icon skeleton
              _ShimmerBar(
                width: 36,
                height: 36,
                shimmerValue: shimmerValue,
                baseColor: baseColor,
                highlightColor: highlightColor,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBar(
                      width: double.infinity,
                      height: 18,
                      shimmerValue: shimmerValue,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      borderRadius: 6,
                    ),
                    const SizedBox(height: 6),
                    _ShimmerBar(
                      width: 80,
                      height: 12,
                      shimmerValue: shimmerValue,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ),
              // Chevron skeleton - simple small bar
              _ShimmerBar(
                width: 16,
                height: 16,
                shimmerValue: shimmerValue,
                baseColor: baseColor,
                highlightColor: highlightColor,
                borderRadius: 4,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stats row skeleton with pills
          Row(
            children: [
              _ShimmerBar(
                width: 60,
                height: 28,
                shimmerValue: shimmerValue,
                baseColor: baseColor,
                highlightColor: highlightColor,
                borderRadius: 8,
              ),
              const SizedBox(width: 8),
              _ShimmerBar(
                width: 90,
                height: 28,
                shimmerValue: shimmerValue,
                baseColor: baseColor,
                highlightColor: highlightColor,
                borderRadius: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double width;
  final double height;
  final double shimmerValue;
  final Color baseColor;
  final Color highlightColor;
  final double borderRadius;

  const _ShimmerBar({
    required this.width,
    required this.height,
    required this.shimmerValue,
    required this.baseColor,
    required this.highlightColor,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2.5 * shimmerValue, 0),
          end: Alignment(-0.3 + 2.5 * shimmerValue, 0),
          colors: [
            baseColor,
            highlightColor,
            highlightColor,
            baseColor,
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ),
      ),
    );
  }
}
