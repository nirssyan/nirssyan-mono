import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class GlassPageToggle extends StatefulWidget {
  final int currentPage;
  final ValueChanged<int>? onPageChanged;
  final List<IconData> icons;
  final List<String>? labels;

  const GlassPageToggle({
    super.key,
    required this.currentPage,
    this.onPageChanged,
    required this.icons,
    this.labels,
  });

  @override
  State<GlassPageToggle> createState() => _GlassPageToggleState();
}

class _GlassPageToggleState extends State<GlassPageToggle>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: widget.currentPage.toDouble(),
      end: widget.currentPage.toDouble(),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _shimmerController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(GlassPageToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _animateToPage(widget.currentPage);
    }
  }

  void _animateToPage(int page) {
    final currentPosition = _slideAnimation.value;
    final targetPosition = page.toDouble();

    _slideAnimation = Tween<double>(
      begin: currentPosition,
      end: targetPosition,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));

    if (_slideController.isAnimating) {
      _slideController.stop();
    }

    _slideController.reset();
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Measure each label and return the max width
  double _getMaxLabelWidth(BuildContext context) {
    if (widget.labels == null || widget.labels!.isEmpty) return 0;

    final textStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    double maxWidth = 0;
    for (final label in widget.labels!) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      maxWidth = math.max(maxWidth, tp.width);
    }
    return maxWidth.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final itemCount = widget.icons.length;
    final hasLabels = widget.labels != null && widget.labels!.isNotEmpty;

    // Calculate segment width: all segments equal width based on widest content
    final double segmentWidth;
    if (hasLabels) {
      final maxLabelWidth = _getMaxLabelWidth(context);
      // icon(14) + spacing(5) + text + padding(24)
      segmentWidth = 14 + 5 + maxLabelWidth + 24;
    } else {
      segmentWidth = 40.0;
    }

    final indicatorWidth = segmentWidth - 4;

    // Colors
    final tabBarBackground = isDark
        ? [
            AppColors.surface.withOpacity(0.9),
            AppColors.background.withOpacity(0.8),
            AppColors.surface.withOpacity(0.9),
          ]
        : [
            AppColors.lightSurface.withOpacity(0.95),
            AppColors.lightBackground.withOpacity(0.9),
            AppColors.lightSurface.withOpacity(0.95),
          ];

    final borderColor = isDark
        ? AppColors.textPrimary.withOpacity(0.15)
        : AppColors.lightAccent.withOpacity(0.1);

    final shadowColor = isDark
        ? Colors.black.withOpacity(0.4)
        : Colors.black.withOpacity(0.08);

    final highlightColor = isDark
        ? AppColors.textPrimary.withOpacity(0.1)
        : AppColors.lightAccent.withOpacity(0.05);

    final indicatorColors = isDark
        ? [
            AppColors.accent.withOpacity(0.95),
            AppColors.accent.withOpacity(0.85),
            AppColors.accentSecondary.withOpacity(0.9),
          ]
        : [
            AppColors.lightAccent.withOpacity(0.95),
            AppColors.lightAccent.withOpacity(0.85),
            AppColors.lightAccentSecondary.withOpacity(0.9),
          ];

    final selectedIconColor = isDark ? AppColors.background : AppColors.lightBackground;
    final unselectedIconColor = isDark
        ? AppColors.textPrimary.withOpacity(0.5)
        : AppColors.lightTextSecondary.withOpacity(0.6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: AnimatedBuilder(
          animation: Listenable.merge([_slideAnimation, _shimmerAnimation, _pulseAnimation]),
          builder: (context, child) {
            return CustomPaint(
              painter: _ToggleBackgroundPainter(
                tabBarBackground: tabBarBackground,
                borderColor: borderColor,
                shadowColor: shadowColor,
                highlightColor: highlightColor,
                isDark: isDark,
                shimmerValue: _shimmerAnimation.value,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: SizedBox(
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Sliding indicator
                      AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, _) {
                          final indicatorLeft = _slideAnimation.value * segmentWidth + 2;
                          return Positioned(
                            left: indicatorLeft,
                            top: 0,
                            bottom: 0,
                            width: indicatorWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: indicatorColors,
                                  stops: const [0.0, 0.7, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? Colors.black : Colors.grey).withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Segments
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(itemCount, (index) {
                          final icon = widget.icons[index];
                          final label = hasLabels && index < widget.labels!.length
                              ? widget.labels![index]
                              : null;
                          final isSelected = index == widget.currentPage;

                          return GestureDetector(
                            onTap: () {
                              if (widget.onPageChanged != null && !isSelected) {
                                HapticFeedback.lightImpact();
                                widget.onPageChanged!(index);
                              }
                            },
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              width: segmentWidth,
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      color: isSelected ? selectedIconColor : unselectedIconColor,
                                      size: 14,
                                    ),
                                    if (label != null) ...[
                                      const SizedBox(width: 5),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          color: isSelected ? selectedIconColor : unselectedIconColor,
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ToggleBackgroundPainter extends CustomPainter {
  final List<Color> tabBarBackground;
  final Color borderColor;
  final Color shadowColor;
  final Color highlightColor;
  final bool isDark;
  final double shimmerValue;

  _ToggleBackgroundPainter({
    required this.tabBarBackground,
    required this.borderColor,
    required this.shadowColor,
    required this.highlightColor,
    required this.isDark,
    required this.shimmerValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    // Shadow
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 10 : 5);
    canvas.drawRRect(rrect.shift(const Offset(0, 4)), shadowPaint);

    // Background gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: tabBarBackground,
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rrect, borderPaint);

    // Shimmer
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(shimmerValue - 1, -1),
        end: Alignment(shimmerValue + 1, 1),
        colors: [
          Colors.transparent,
          (isDark ? Colors.white : Colors.black).withOpacity(0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _ToggleBackgroundPainter oldDelegate) {
    return oldDelegate.shimmerValue != shimmerValue;
  }
}
