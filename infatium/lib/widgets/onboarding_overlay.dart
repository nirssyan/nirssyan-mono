import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../l10n/generated/app_localizations.dart';

/// Position of the tooltip relative to the spotlight
enum TooltipPosition { top, bottom }

/// Model for a single onboarding step
class OnboardingStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final TooltipPosition position;

  const OnboardingStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.position = TooltipPosition.top,
  });
}

/// Fullscreen onboarding overlay with spotlight cutouts
class OnboardingOverlay extends StatefulWidget {
  final List<OnboardingStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const OnboardingOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Rect? _spotlightRect;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Pulse animation for AAA-quality glow breathing effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Start animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSpotlightRect();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateSpotlightRect() {
    if (_currentStep >= widget.steps.length) return;

    final targetKey = widget.steps[_currentStep].targetKey;
    final renderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      setState(() {
        _spotlightRect = Rect.fromLTWH(
          position.dx,
          position.dy,
          size.width,
          size.height,
        );
      });
    }
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      _animationController.reverse().then((_) {
        setState(() {
          _currentStep++;
        });
        _updateSpotlightRect();
        _animationController.forward();
      });
    } else {
      _animationController.reverse().then((_) {
        widget.onComplete();
      });
    }
  }

  void _skip() {
    _animationController.reverse().then((_) {
      widget.onSkip();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final currentStepData = widget.steps[_currentStep];
    final isLastStep = _currentStep == widget.steps.length - 1;

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Stack(
          children: [
            // Dark overlay with spotlight cutout
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  spotlightRect: _spotlightRect,
                  overlayOpacity: 0.85 * _fadeAnimation.value,
                  isDark: isDark,
                  pulseValue: _pulseAnimation.value,
                ),
              ),
            ),

            // Tooltip card
            if (_spotlightRect != null)
              Positioned(
                left: 24,
                right: 24,
                top: currentStepData.position == TooltipPosition.bottom
                    ? _spotlightRect!.bottom + 24
                    : null,
                bottom: currentStepData.position == TooltipPosition.top
                    ? MediaQuery.of(context).size.height -
                        _spotlightRect!.top +
                        24
                    : null,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: _TooltipCard(
                    title: currentStepData.title,
                    description: currentStepData.description,
                    currentStep: _currentStep,
                    totalSteps: widget.steps.length,
                    isLastStep: isLastStep,
                    onNext: _nextStep,
                    onSkip: _skip,
                    nextLabel: isLastStep ? l10n.onboardingFinish : l10n.onboardingNext,
                    skipLabel: l10n.onboardingSkip,
                    isDark: isDark,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Custom painter for the dark overlay with spotlight cutout
/// Features AAA-quality multi-layer glow effect with breathing animation
class _SpotlightPainter extends CustomPainter {
  final Rect? spotlightRect;
  final double overlayOpacity;
  final bool isDark;
  final double pulseValue;

  _SpotlightPainter({
    required this.spotlightRect,
    required this.overlayOpacity,
    required this.isDark,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(overlayOpacity);

    // Draw full overlay
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (spotlightRect != null) {
      // Calculate pill-shaped spotlight matching tab indicator style
      final center = spotlightRect!.center;
      // Match tab indicator size exactly (75% width, 44px height)
      final pillWidth = spotlightRect!.width * 0.75;
      final pillHeight = 44.0;
      final borderRadius = 20.0;

      final pillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: pillWidth, height: pillHeight),
        Radius.circular(borderRadius),
      );

      // Create path with pill-shaped cutout
      final path = Path()
        ..addRect(fullRect)
        ..addRRect(pillRect)
        ..fillType = PathFillType.evenOdd;

      canvas.drawPath(path, paint);

      // AAA-quality multi-layer glow effect with breathing animation
      final glowColor = isDark ? Colors.white : AppColors.lightAccent;

      // Layer 5 - outermost, barely visible atmospheric glow
      final glow5 = Paint()
        ..color = glowColor.withOpacity(0.06 * overlayOpacity * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: pillWidth + 20, height: pillHeight + 20),
          Radius.circular(borderRadius + 10),
        ),
        glow5,
      );

      // Layer 4 - wide soft glow
      final glow4 = Paint()
        ..color = glowColor.withOpacity(0.10 * overlayOpacity * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: pillWidth + 14, height: pillHeight + 14),
          Radius.circular(borderRadius + 7),
        ),
        glow4,
      );

      // Layer 3 - medium glow
      final glow3 = Paint()
        ..color = glowColor.withOpacity(0.15 * overlayOpacity * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: pillWidth + 8, height: pillHeight + 8),
          Radius.circular(borderRadius + 4),
        ),
        glow3,
      );

      // Layer 2 - tighter glow for intensity
      final glow2 = Paint()
        ..color = glowColor.withOpacity(0.22 * overlayOpacity * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: pillWidth + 4, height: pillHeight + 4),
          Radius.circular(borderRadius + 2),
        ),
        glow2,
      );

      // Layer 1 - bright inner glow
      final glow1 = Paint()
        ..color = glowColor.withOpacity(0.35 * overlayOpacity * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: pillWidth + 2, height: pillHeight + 2),
          Radius.circular(borderRadius + 1),
        ),
        glow1,
      );

      // Crisp border for sharp definition
      final borderPaint = Paint()
        ..color = glowColor.withOpacity(0.5 * overlayOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(pillRect, borderPaint);
    } else {
      canvas.drawRect(fullRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return spotlightRect != oldDelegate.spotlightRect ||
        overlayOpacity != oldDelegate.overlayOpacity ||
        pulseValue != oldDelegate.pulseValue;
  }
}

/// Glass-morphism tooltip card
class _TooltipCard extends StatelessWidget {
  final String title;
  final String description;
  final int currentStep;
  final int totalSteps;
  final bool isLastStep;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final String nextLabel;
  final String skipLabel;
  final bool isDark;

  const _TooltipCard({
    required this.title,
    required this.description,
    required this.currentStep,
    required this.totalSteps,
    required this.isLastStep,
    required this.onNext,
    required this.onSkip,
    required this.nextLabel,
    required this.skipLabel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDark
        ? AppColors.surface.withOpacity(0.9)
        : AppColors.lightSurface.withOpacity(0.95);
    final borderColor = isDark
        ? AppColors.textPrimary.withOpacity(0.15)
        : AppColors.lightAccent.withOpacity(0.1);
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                description,
                style: TextStyle(
                  fontSize: 15,
                  color: secondaryTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Step indicators
              Row(
                children: List.generate(
                  totalSteps,
                  (index) => Container(
                    width: index == currentStep ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: index == currentStep
                          ? accentColor
                          : accentColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  // Skip button
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: onSkip,
                      child: Text(
                        skipLabel,
                        style: TextStyle(
                          fontSize: 16,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Next button
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: accentColor,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: onNext,
                      child: Text(
                        nextLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.background
                              : AppColors.lightBackground,
                        ),
                      ),
                    ),
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
