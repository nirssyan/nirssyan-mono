import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/particle.dart';
import '../painters/particle_painter.dart';
import '../theme/colors.dart';

/// Particle transformation animation overlay
/// Shows particles flowing from card to digest center with Lottie background glow
class ParticleAnimationOverlay extends StatefulWidget {
  final Offset cardPosition; // Top-left of card
  final Size cardSize;
  final Offset targetCenter; // Center of digest placeholder
  final VoidCallback onComplete;
  final int durationMs; // Total animation duration in milliseconds

  const ParticleAnimationOverlay({
    required this.cardPosition,
    required this.cardSize,
    required this.targetCenter,
    required this.onComplete,
    this.durationMs = 1800, // Default: 1.8 seconds
    Key? key,
  }) : super(key: key);

  @override
  State<ParticleAnimationOverlay> createState() =>
      _ParticleAnimationOverlayState();
}

class _ParticleAnimationOverlayState extends State<ParticleAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Total animation duration (adaptive based on post count)
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.durationMs),
      vsync: this,
    );

    // Update particles on every frame
    _controller.addListener(_updateParticles);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Generate particles only once
    if (_particles.isEmpty) {
      _generateParticles();

      // Start animation after particles are generated
      _controller.forward().then((_) {
        // Notify completion after brief delay
        Future.delayed(const Duration(milliseconds: 100), widget.onComplete);
      });
    }
  }

  void _generateParticles() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final particleColor = isDark ? AppColors.accent : AppColors.lightAccent;

    // Generate 30-40 particles (random count for organic feel)
    final particleCount = 30 + _random.nextInt(11);

    for (int i = 0; i < particleCount; i++) {
      // Random emission point on card surface
      final startX = widget.cardPosition.dx +
          _random.nextDouble() * widget.cardSize.width;
      final startY = widget.cardPosition.dy +
          _random.nextDouble() * widget.cardSize.height;
      final startPos = Offset(startX, startY);

      // Random size: 1-2 pixels (ultra-minimal)
      final size = 1.0 + _random.nextDouble() * 1.0;

      // Random lifetime: 67%-83% of total duration (for variety)
      final minLifetime = (widget.durationMs * 0.67).toInt();
      final maxLifetime = (widget.durationMs * 0.83).toInt();
      final lifetime = Duration(milliseconds: minLifetime + _random.nextInt(maxLifetime - minLifetime));

      // Random curve for varied speed
      final curves = [
        Curves.easeInOut,
        Curves.easeInCubic,
        Curves.easeInOutQuad
      ];
      final curve = curves[_random.nextInt(curves.length)];

      // Generate Bezier control points for curved trajectory
      final controlPoint1 =
          _generateControlPoint(startPos, widget.targetCenter, 0.33);
      final controlPoint2 =
          _generateControlPoint(startPos, widget.targetCenter, 0.66);

      _particles.add(Particle(
        startPosition: startPos,
        targetPosition: widget.targetCenter,
        color: particleColor,
        size: size,
        lifetime: lifetime,
        curve: curve,
        controlPoint1: controlPoint1,
        controlPoint2: controlPoint2,
      ));
    }
  }

  /// Generate control point with random perpendicular offset for organic curves
  Offset _generateControlPoint(Offset start, Offset end, double t) {
    final midX = start.dx + (end.dx - start.dx) * t;
    final midY = start.dy + (end.dy - start.dy) * t;

    // Add random perpendicular offset (±50-100 pixels)
    final offsetMagnitude = 50 + _random.nextDouble() * 50;
    final angle =
        math.atan2(end.dy - start.dy, end.dx - start.dx) + math.pi / 2;
    final offsetX =
        offsetMagnitude * math.cos(angle) * (_random.nextBool() ? 1 : -1);
    final offsetY =
        offsetMagnitude * math.sin(angle) * (_random.nextBool() ? 1 : -1);

    return Offset(midX + offsetX, midY + offsetY);
  }

  void _updateParticles() {
    final elapsed =
        Duration(milliseconds: (_controller.value * widget.durationMs).toInt());
    for (var particle in _particles) {
      particle.update(elapsed);
    }
    setState(() {}); // Trigger repaint
  }

  @override
  void dispose() {
    _controller.removeListener(_updateParticles);
    _controller.dispose();
    _particles.clear(); // Free memory
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        children: [
          // Particles layer
          Positioned.fill(
            child: CustomPaint(
              painter: ParticlePainter(
                particles: _particles,
                isDark: isDark,
              ),
            ),
          ),

          // Final pulse effect (appears at 85% progress)
          if (_controller.value > 0.85) _buildFinalPulse(),
        ],
      ),
    );
  }

  Widget _buildFinalPulse() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final pulseColor = isDark ? AppColors.accent : AppColors.lightAccent;

    // Pulse animation: scale from 0.5 to 1.2 in last 15% of animation
    final pulseProgress = ((_controller.value - 0.85) / 0.15).clamp(0.0, 1.0);
    final scale = 0.5 + (pulseProgress * 0.7); // 0.5 → 1.2
    final opacity = (1.0 - pulseProgress).clamp(0.0, 1.0); // Fade out

    return Positioned(
      left: widget.targetCenter.dx - 100,
      top: widget.targetCenter.dy - 100,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                pulseColor.withOpacity(opacity * 0.4),
                pulseColor.withOpacity(opacity * 0.2),
                pulseColor.withOpacity(0.0),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
