import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A smooth, continuous pharmacy loader with medical cross
/// Features seamless animations without visible loops
class PharmacyLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;
  final double? value;

  const PharmacyLoader({
    super.key,
    this.size = 60.0,
    this.color,
    this.strokeWidth = 4.0,
    this.value,
  });

  @override
  State<PharmacyLoader> createState() => _PharmacyLoaderState();
}

class _PharmacyLoaderState extends State<PharmacyLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = widget.color ?? theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // The rotating medical loader
        CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _PharmacyLoaderPainter(
            color: effectiveColor,
            strokeWidth: widget.strokeWidth,
            animationValue: _controller.value,
          ),
        ),
        
        // Progress Bar and Text (if value provided)
        if (widget.value != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: widget.size * 2.5, // Wider than the spinner
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.value,
                    backgroundColor: effectiveColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(widget.value! * 100).toInt()}%',
                  style: TextStyle(
                    color: effectiveColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PharmacyLoaderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double animationValue;

  _PharmacyLoaderPainter({
    required this.color,
    required this.strokeWidth,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Smooth rotating arcs (Indeterminate)
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw multiple arcs for smooth continuous rotation
    for (int i = 0; i < 3; i++) {
      final arcProgress = (animationValue + (i * 0.33)) % 1.0;
      final startAngle = arcProgress * 2 * math.pi - math.pi / 2;
      final sweepAngle = math.pi * 0.6;

      final opacity = (math.sin(arcProgress * math.pi * 2) * 0.5 + 0.5);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint..color = color.withValues(alpha: 0.2 + opacity * 0.5),
      );
    }

    // Draw the medical cross in the center with pulse effect
    final pulseScale = 0.95 + (math.sin(animationValue * math.pi * 2) * 0.05);
    
    final crossPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final crossSize = size.width * 0.3 * pulseScale;
    final crossThickness = crossSize * 0.35;

    // Vertical bar of cross
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: crossThickness,
          height: crossSize,
        ),
        Radius.circular(crossThickness / 2),
      ),
      crossPaint,
    );

    // Horizontal bar of cross
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: crossSize,
          height: crossThickness,
        ),
        Radius.circular(crossThickness / 2),
      ),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(_PharmacyLoaderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Alternative: Smooth pill bounce loader
class PharmacyPillLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const PharmacyPillLoader({super.key, this.size = 60.0, this.color});

  @override
  State<PharmacyPillLoader> createState() => _PharmacyPillLoaderState();
}

class _PharmacyPillLoaderState extends State<PharmacyPillLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(3, (index) {
              // Staggered delay for each pill
              final delay = index * 0.25;
              final adjustedValue = (_controller.value - delay) % 1.0;

              // Smooth sine wave for bounce
              final bounce = math.sin(adjustedValue * math.pi * 2).abs();
              final scale = 0.6 + (bounce * 0.4);
              final opacity = 0.4 + (bounce * 0.6);

              return Transform.translate(
                offset: Offset(0, (index - 1) * 16),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// Modern wave loader - very smooth for splash screens
class PharmacyWaveLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const PharmacyWaveLoader({super.key, this.size = 60.0, this.color});

  @override
  State<PharmacyWaveLoader> createState() => _PharmacyWaveLoaderState();
}

class _PharmacyWaveLoaderState extends State<PharmacyWaveLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size / 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (index) {
              // Each bar has a phase offset
              final phase = (index * 0.2);
              final waveValue = (_controller.value + phase) % 1.0;

              // Smooth sine wave
              final height = (math.sin(waveValue * math.pi * 2) * 0.5 + 0.5);
              final barHeight = (widget.size / 2) * (0.3 + height * 0.7);

              return Container(
                width: 6,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
