import 'package:flutter/cupertino.dart';

import '../services/theme_service.dart';

/// Reusable shimmer skeleton bar widget
class ShimmerBar extends StatelessWidget {
  final double width;
  final double height;
  final double shimmerValue;
  final Color? baseColor;
  final Color? highlightColor;
  final double borderRadius;

  const ShimmerBar({
    super.key,
    required this.width,
    required this.height,
    required this.shimmerValue,
    this.baseColor,
    this.highlightColor,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final effectiveBaseColor = baseColor ??
        (isDark
            ? CupertinoColors.white.withValues(alpha: 0.06)
            : CupertinoColors.black.withValues(alpha: 0.04));
    final effectiveHighlightColor = highlightColor ??
        (isDark
            ? CupertinoColors.white.withValues(alpha: 0.12)
            : CupertinoColors.black.withValues(alpha: 0.08));

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2.5 * shimmerValue, 0),
          end: Alignment(-0.3 + 2.5 * shimmerValue, 0),
          colors: [
            effectiveBaseColor,
            effectiveHighlightColor,
            effectiveHighlightColor,
            effectiveBaseColor,
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ),
      ),
    );
  }
}

/// Skeleton for a text field with optional label
class TextFieldSkeleton extends StatelessWidget {
  final double shimmerValue;
  final bool showLabel;
  final double labelWidth;

  const TextFieldSkeleton({
    super.key,
    required this.shimmerValue,
    this.showLabel = true,
    this.labelWidth = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          ShimmerBar(
            width: labelWidth,
            height: 14,
            shimmerValue: shimmerValue,
            borderRadius: 4,
          ),
          const SizedBox(height: 8),
        ],
        ShimmerBar(
          width: double.infinity,
          height: 44,
          shimmerValue: shimmerValue,
          borderRadius: 10,
        ),
      ],
    );
  }
}

/// Skeleton for a list of source items
class SourceListSkeleton extends StatelessWidget {
  final double shimmerValue;
  final int itemCount;

  const SourceListSkeleton({
    super.key,
    required this.shimmerValue,
    this.itemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBar(
          width: 100,
          height: 14,
          shimmerValue: shimmerValue,
          borderRadius: 4,
        ),
        const SizedBox(height: 12),
        ...List.generate(itemCount, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ShimmerBar(
              width: double.infinity,
              height: 42,
              shimmerValue: shimmerValue,
              borderRadius: 10,
            ),
          );
        }),
      ],
    );
  }
}

/// Skeleton for schedule picker options
class SchedulePickerSkeleton extends StatelessWidget {
  final double shimmerValue;
  final int optionCount;

  const SchedulePickerSkeleton({
    super.key,
    required this.shimmerValue,
    this.optionCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBar(
          width: 90,
          height: 14,
          shimmerValue: shimmerValue,
          borderRadius: 4,
        ),
        const SizedBox(height: 12),
        ...List.generate(optionCount, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ShimmerBar(
              width: double.infinity,
              height: 48,
              shimmerValue: shimmerValue,
              borderRadius: 10,
            ),
          );
        }),
      ],
    );
  }
}

/// Skeleton for a button
class ButtonSkeleton extends StatelessWidget {
  final double shimmerValue;
  final double height;

  const ButtonSkeleton({
    super.key,
    required this.shimmerValue,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerBar(
      width: double.infinity,
      height: height,
      shimmerValue: shimmerValue,
      borderRadius: 12,
    );
  }
}
