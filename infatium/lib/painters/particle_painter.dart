import 'package:flutter/material.dart';
import '../models/particle.dart';

/// CustomPainter for rendering particle animation
/// Draws particles with trail, glow, and solid core for smooth 60fps animation
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final bool isDark;

  ParticlePainter({required this.particles, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // Skip particles that haven't started yet
      if (particle.trail.isEmpty) continue;

      // Skip completed particles (optimization)
      if (particle.isComplete) continue;

      // Draw glow (radial gradient around particle) - reduced from 2.5× to 1.8×
      final currentPos = particle.getCurrentPosition();
      final glowRadius = particle.size * 1.8;

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            particle.color.withOpacity(isDark ? 0.3 : 0.2), // Reduced intensity
            particle.color.withOpacity(isDark ? 0.15 : 0.1),
            particle.color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: currentPos, radius: glowRadius));

      canvas.drawCircle(currentPos, glowRadius, glowPaint);

      // Draw solid core
      final corePaint = Paint()
        ..color = particle.color.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(currentPos, particle.size, corePaint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    // Always repaint (particles are constantly moving)
    return true;
  }
}
