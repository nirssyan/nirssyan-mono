import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/feed_models.dart';

/// Telegram-style folder tabs widget with animated underline indicator,
/// glassmorphism background, and unseen counter badges.
class TelegramFolderTabs extends StatefulWidget {
  final List<Feed> feeds;
  final String? selectedFeedId;
  final Function(String) onFeedSelected;
  final Function(Feed, GlobalKey) onFeedLongPress;
  final int Function(String) getUnseenCount;
  final bool zenModeEnabled;
  final bool isDark;
  final ScrollController scrollController;
  final Map<String, GlobalKey> feedTagKeys;

  const TelegramFolderTabs({
    super.key,
    required this.feeds,
    required this.selectedFeedId,
    required this.onFeedSelected,
    required this.onFeedLongPress,
    required this.getUnseenCount,
    required this.zenModeEnabled,
    required this.isDark,
    required this.scrollController,
    required this.feedTagKeys,
  });

  @override
  State<TelegramFolderTabs> createState() => TelegramFolderTabsState();
}

class TelegramFolderTabsState extends State<TelegramFolderTabs> {
  // Underline position and width
  double _underlineLeft = 0;
  double _underlineWidth = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Listen to scroll for underline position sync
    widget.scrollController.addListener(_onScroll);

    // Schedule underline position calculation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateUnderlinePosition();
    });
  }

  @override
  void didUpdateWidget(TelegramFolderTabs oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update scroll listener if controller changed
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }

    // Update underline when selection or feeds change
    // Compare by length and IDs since list reference may stay the same after removeWhere()
    final feedCountChanged = oldWidget.feeds.length != widget.feeds.length;
    final selectionChanged = oldWidget.selectedFeedId != widget.selectedFeedId;

    if (selectionChanged || feedCountChanged) {
      // When feed list changes (deletion), we need to wait for ListView to fully rebuild
      // before calculating new positions. Double postFrameCallback ensures RenderBoxes are ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (feedCountChanged) {
          // Feed was added/removed - wait one more frame for ListView to settle
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateUnderlinePosition();
          });
        } else {
          _updateUnderlinePosition();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  /// Called on every scroll event to sync underline position
  void _onScroll() {
    _updateUnderlinePosition();
  }

  /// Updates the underline position based on the selected tab
  void _updateUnderlinePosition() {
    if (!mounted) return;

    final selectedId = widget.selectedFeedId ??
        (widget.feeds.isNotEmpty ? widget.feeds.first.id : null);

    if (selectedId == null) return;

    // Verify selected feed exists in current list (prevents stale key issues during deletion)
    final feedExists = widget.feeds.any((f) => f.id == selectedId);
    if (!feedExists) return;

    final key = widget.feedTagKeys[selectedId];
    if (key?.currentContext == null) return;

    final RenderBox? tabBox = key!.currentContext!.findRenderObject() as RenderBox?;
    final RenderBox? containerBox = context.findRenderObject() as RenderBox?;

    if (tabBox == null || containerBox == null) return;

    final tabPosition = tabBox.localToGlobal(Offset.zero, ancestor: containerBox);

    // Only update if position actually changed (optimization)
    if (_underlineLeft != tabPosition.dx || _underlineWidth != tabBox.size.width) {
      setState(() {
        _underlineLeft = tabPosition.dx;
        _underlineWidth = tabBox.size.width;
        _isInitialized = true;
      });
    }
  }

  /// Public method to update underline (called from parent)
  void updateUnderline() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateUnderlinePosition();
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.75);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              bottom: BorderSide(
                color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Tab items
              ListView.builder(
                controller: widget.scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.feeds.length,
                itemBuilder: (context, index) {
                  final feed = widget.feeds[index];
                  final isSelected = widget.selectedFeedId == feed.id ||
                      (widget.selectedFeedId == null && index == 0);

                  return _buildTabItem(feed, isSelected);
                },
              ),

              // Animated underline indicator
              if (_isInitialized)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: _underlineLeft,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: _underlineWidth,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, -1),
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

  Widget _buildTabItem(Feed feed, bool isSelected) {
    final unseenCount = widget.getUnseenCount(feed.id);
    final hasUnseen = unseenCount > 0;

    // Ensure key exists in parent's map
    widget.feedTagKeys[feed.id] ??= GlobalKey();
    final tabKey = widget.feedTagKeys[feed.id]!;

    // Text colors
    final selectedTextColor = widget.isDark ? Colors.white : Colors.black;
    final unselectedTextColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.45);

    return GestureDetector(
      key: tabKey,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onFeedSelected(feed.id);
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onFeedLongPress(feed, tabKey);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tab name with animated styling
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? selectedTextColor : unselectedTextColor,
                letterSpacing: -0.2,
              ),
              child: Text(feed.name),
            ),

            // Unseen counter badge
            if (hasUnseen && !widget.zenModeEnabled) ...[
              const SizedBox(width: 5),
              _buildUnseenBadge(unseenCount, isSelected),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnseenBadge(int count, bool isSelected) {
    final badgeBackground = widget.isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);

    final badgeTextColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.65);

    // AAA-level pulse animation when count changes
    return TweenAnimationBuilder<double>(
      key: ValueKey(count), // Triggers animation when count changes
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      tween: Tween(begin: 0.7, end: 1.0), // Pulse from 70% to 100%
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(minWidth: 18),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeTextColor,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
          ),
        );
      },
    );
  }
}
