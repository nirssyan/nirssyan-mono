import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/colors.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// Digest placeholder widget that appears in the feed list
/// when summarizing unseen posts with accordion animation.
/// Shows a clean placeholder with progress bar and status text.
class FunnelAnimationOverlay extends StatefulWidget {
  final int totalPosts;
  final int processedPosts;
  final String statusText;
  final bool isComplete;
  final VoidCallback? onComplete;

  const FunnelAnimationOverlay({
    Key? key,
    required this.totalPosts,
    required this.processedPosts,
    required this.statusText,
    this.isComplete = false,
    this.onComplete,
  }) : super(key: key);

  @override
  State<FunnelAnimationOverlay> createState() => _FunnelAnimationOverlayState();
}

class _FunnelAnimationOverlayState extends State<FunnelAnimationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Expand animation for appearing in list
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
    _expandController.forward();

    // Breathing glow animation (2-second cycle) - more pronounced pulsing
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(FunnelAnimationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Call onComplete callback when complete
    if (widget.isComplete && !oldWidget.isComplete) {
      Future.delayed(const Duration(milliseconds: 800), () {
        widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1C1C1E)  // Dark: dark gray (iOS dark surface)
        : const Color(0xFFF5F5F5);  // Light: light gray
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final progressColor = isDark ? Colors.white : Colors.black;

    final progress = widget.totalPosts > 0
        ? widget.processedPosts / widget.totalPosts
        : 0.0;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
            ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        // Loading indicator on the left
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: widget.isComplete
                              ? Icon(
                                  CupertinoIcons.checkmark_alt,
                                  color: textColor,
                                  size: 24,
                                )
                              : LoadingAnimationWidget.staggeredDotsWave(
                                  color: textColor,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 16),
                        // Text and progress on the right
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Status text
                              Text(
                                widget.statusText,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Progress count
                              if (widget.totalPosts > 0 && !widget.isComplete)
                                Text(
                                  '${widget.processedPosts}/${widget.totalPosts}',
                                  style: TextStyle(
                                    color: secondaryColor,
                                    fontSize: 13,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              // Progress bar
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.05),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: AnimatedFractionallySizedBox(
                                    duration: const Duration(milliseconds: 300),
                                    alignment: Alignment.centerLeft,
                                    widthFactor: widget.isComplete ? 1.0 : progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        color: progressColor.withOpacity(isDark ? 0.6 : 0.3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated FractionallySizedBox for smooth progress bar animation
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final AlignmentGeometry alignment;
  final Widget child;

  const AnimatedFractionallySizedBox({
    Key? key,
    required Duration duration,
    required this.widthFactor,
    required this.alignment,
    required this.child,
  }) : super(key: key, duration: duration);

  @override
  AnimatedFractionallySizedBoxState createState() =>
      AnimatedFractionallySizedBoxState();
}

class AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _widthFactor!.evaluate(animation),
      alignment: widget.alignment,
      child: widget.child,
    );
  }
}
