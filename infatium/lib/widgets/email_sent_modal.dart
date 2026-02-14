import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;

import '../theme/colors.dart';
import '../l10n/generated/app_localizations.dart';

/// Beautiful email sent confirmation modal with animations and iOS-first design
class EmailSentModal extends StatefulWidget {
  final String title;
  final String message;
  final bool autoDismiss;

  const EmailSentModal({
    super.key,
    required this.title,
    required this.message,
    this.autoDismiss = true,
  });

  @override
  State<EmailSentModal> createState() => _EmailSentModalState();
}

class _EmailSentModalState extends State<EmailSentModal>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _buttonGlowController;
  late AnimationController _rotationController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _buttonGlowAnimation;
  late Animation<double> _rotationAnimation;

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _setupAnimations();

    // Start initial animations
    _slideController.forward();
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
    _buttonGlowController.repeat(reverse: true);
    _rotationController.repeat();

    // Auto dismiss after 3 seconds if enabled
    if (widget.autoDismiss) {
      _dismissTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _closeModal();
        }
      });
    }
  }

  void _setupAnimations() {
    // Slide animation for modal
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Pulse animation for email icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Button glow animation
    _buttonGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _buttonGlowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonGlowController,
      curve: Curves.easeInOut,
    ));

    // Subtle rotation for sparkle effect
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
  }

  Future<void> _closeModal() async {
    _dismissTimer?.cancel();

    await Future.wait([
      _slideController.reverse(),
      _fadeController.reverse(),
    ]);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _buttonGlowController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    // Colors
    final backgroundColor = isDark ? AppColors.background : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final accentColor = isDark ? AppColors.accent : AppColors.lightAccent;
    final borderColor = isDark
        ? const Color(0xFFFFFFFF).withOpacity(0.15)
        : const Color(0xFF000000).withOpacity(0.1);

    return GestureDetector(
      onTap: _closeModal,
      child: Container(
        color: CupertinoColors.black.withOpacity(0.5),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping modal
              child: SlideTransition(
                position: _slideAnimation,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor.withOpacity(0.95),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        border: Border(
                          top: BorderSide(color: borderColor, width: 1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                            offset: const Offset(0, -10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: secondaryTextColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Animated email icon
                          Padding(
                            padding: const EdgeInsets.only(top: 24, bottom: 20),
                            child: _buildAnimatedIcon(isDark, accentColor),
                          ),

                          // Title
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Message
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // OK Button with glow
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildOkButton(
                              l10n,
                              isDark,
                              accentColor,
                              backgroundColor,
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(bool isDark, Color accentColor) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rotationAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  accentColor.withOpacity(0.2),
                  accentColor.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main email icon
                Icon(
                  CupertinoIcons.envelope_fill,
                  color: accentColor,
                  size: 50,
                ),

                // Sparkle effect (small rotating stars around)
                Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: CustomPaint(
                    size: const Size(100, 100),
                    painter: _SparklePainter(accentColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOkButton(
    AppLocalizations l10n,
    bool isDark,
    Color accentColor,
    Color backgroundColor,
  ) {
    return AnimatedBuilder(
      animation: _buttonGlowAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _closeModal();
          },
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        accentColor,
                        accentColor.withOpacity(0.9),
                      ]
                    : [
                        AppColors.lightAccent,
                        AppColors.lightAccent.withOpacity(0.9),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3 * _buttonGlowAnimation.value),
                  blurRadius: 20 * _buttonGlowAnimation.value,
                  spreadRadius: 2 * _buttonGlowAnimation.value,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'OK',
                style: TextStyle(
                  color: isDark ? backgroundColor : AppColors.lightBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for sparkle effect around the email icon
class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw small sparkles at 45, 135, 225, 315 degrees
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + (math.pi / 4);
      final x = center.dx + radius * 0.8 * math.cos(angle);
      final y = center.dy + radius * 0.8 * math.sin(angle);

      _drawSparkle(canvas, Offset(x, y), paint, 3);
    }
  }

  void _drawSparkle(Canvas canvas, Offset position, Paint paint, double size) {
    final path = Path();

    // Draw a simple star/sparkle
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final x = position.dx + size * math.cos(angle);
      final y = position.dy + size * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => false;
}
