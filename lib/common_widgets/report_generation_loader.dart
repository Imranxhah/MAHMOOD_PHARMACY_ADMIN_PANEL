import 'package:flutter/material.dart';

class ReportGenerationLoader extends StatefulWidget {
  final Color? color;

  const ReportGenerationLoader({
    super.key,
    this.color,
  });

  @override
  State<ReportGenerationLoader> createState() => _ReportGenerationLoaderState();
}

class _ReportGenerationLoaderState extends State<ReportGenerationLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // Animate from 0.0 to 0.95 (95%) with a slowdown at the end
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.75)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60.0, // 60% of the 10s (6 seconds)
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.75, end: 0.95)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 40.0, // 40% of the 10s (4 seconds) - much slower crawl
      ),
    ]).animate(_controller);

    _controller.forward();
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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_rounded,
              size: 32,
              color: effectiveColor,
            ),
          ),
          const SizedBox(height: 20),
          
          const Text(
            "Generating Report...",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Please wait while we prepare your file",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 24),

          // Progress Bar
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _animation.value,
                      minHeight: 8,
                      backgroundColor: effectiveColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${(_animation.value * 100).toInt()}%",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: effectiveColor,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
