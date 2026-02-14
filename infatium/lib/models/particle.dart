import 'package:flutter/material.dart';

/// Represents a single particle in the summarize animation
/// Each particle travels from a card position to the digest center along a curved Bézier path
class Particle {
  final Offset startPosition; // Card emission point
  final Offset targetPosition; // Digest center
  final Color color; // Theme-aware accent color
  final double size; // Radius: 3-5 pixels
  final Duration lifetime; // 1200-1500ms (randomized)
  final Curve curve; // Animation curve for easing

  // Bézier curve control points for organic curved motion
  final Offset controlPoint1;
  final Offset controlPoint2;

  // Animation state
  double progress = 0.0; // 0.0 → 1.0
  final List<Offset> trail = []; // Last 5 positions for trail effect

  // Lifecycle
  bool isComplete = false;

  Particle({
    required this.startPosition,
    required this.targetPosition,
    required this.color,
    required this.size,
    required this.lifetime,
    required this.curve,
    required this.controlPoint1,
    required this.controlPoint2,
  });

  /// Update particle position along Bézier curve based on elapsed time
  void update(Duration elapsed) {
    progress =
        (elapsed.inMilliseconds / lifetime.inMilliseconds).clamp(0.0, 1.0);
    isComplete = progress >= 1.0;

    // Calculate current position on cubic Bézier curve
    final t = curve.transform(progress);
    final currentPos = _cubicBezier(
      startPosition,
      controlPoint1,
      controlPoint2,
      targetPosition,
      t,
    );

    // Update trail (keep last 5 positions)
    trail.add(currentPos);
    if (trail.length > 5) trail.removeAt(0);
  }

  /// Get current particle position (last position in trail)
  Offset getCurrentPosition() {
    if (trail.isEmpty) return startPosition;
    return trail.last;
  }

  /// Calculate position on cubic Bézier curve at parameter t (0.0 to 1.0)
  /// Uses De Casteljau's algorithm for stability
  Offset _cubicBezier(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  ) {
    final t2 = t * t;
    final t3 = t2 * t;
    final mt = 1 - t;
    final mt2 = mt * mt;
    final mt3 = mt2 * mt;

    return Offset(
      mt3 * p0.dx + 3 * mt2 * t * p1.dx + 3 * mt * t2 * p2.dx + t3 * p3.dx,
      mt3 * p0.dy + 3 * mt2 * t * p1.dy + 3 * mt * t2 * p2.dy + t3 * p3.dy,
    );
  }
}
