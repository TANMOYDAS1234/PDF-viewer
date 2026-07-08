import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated, theme-aware launch screen: the document mark draws in, its corner
/// folds, a red "PDF" badge pops, then the wordmark rises. Background and text
/// colours follow the current light/dark theme.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _sheet;
  late final Animation<double> _badge;
  late final Animation<double> _text;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _sheet = CurvedAnimation(
        parent: _c, curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack));
    _badge = CurvedAnimation(
        parent: _c, curve: const Interval(0.45, 0.78, curve: Curves.elasticOut));
    _text = CurvedAnimation(
        parent: _c, curve: const Interval(0.62, 1.0, curve: Curves.easeOut));

    _c.forward().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) widget.onComplete();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.brandGradientDiagonal,
          color: isDark ? AppColors.darkBg : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  return Opacity(
                    opacity: _sheet.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * _sheet.value.clamp(0.0, 1.0),
                      child: _DocumentMark(
                        badgeScale: _badge.value.clamp(0.0, 1.0),
                        accent: isDark ? AppColors.gradEnd : AppColors.primary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _text,
                builder: (context, child) => Opacity(
                  opacity: _text.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - _text.value)),
                    child: child,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'PDF Viewer Pro',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        color: isDark ? AppColors.onDark : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Read · Annotate · Organize',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: (isDark ? AppColors.onDark : Colors.white)
                            .withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The folded document + PDF badge, drawn with widgets so it stays crisp.
class _DocumentMark extends StatelessWidget {
  final double badgeScale;
  final Color accent;
  const _DocumentMark({required this.badgeScale, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 164,
      child: Stack(
        children: [
          // Sheet with folded top-right corner
          Positioned.fill(
            child: CustomPaint(painter: _SheetPainter()),
          ),
          // Text lines
          Positioned(
            left: 22,
            right: 22,
            top: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(0.5),
                const SizedBox(height: 9),
                _line(1.0),
                const SizedBox(height: 9),
                _line(0.8),
              ],
            ),
          ),
          // PDF badge
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Center(
              child: Transform.scale(
                scale: badgeScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.pdfRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(double widthFactor) => FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 7,
          decoration: BoxDecoration(
            color: const Color(0xFFD8DCE6),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}

class _SheetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fold = size.width * 0.28;
    final white = Paint()..color = Colors.white;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final body = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(body.shift(const Offset(0, 6)), shadow);
    canvas.drawPath(body, white);

    // Fold flap (underside)
    final flap = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width - fold, fold)
      ..close();
    canvas.drawPath(flap, Paint()..color = const Color(0xFFCED4E0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
