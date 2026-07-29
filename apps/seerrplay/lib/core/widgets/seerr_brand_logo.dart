import 'package:flutter/material.dart';
import 'package:seerrplay/core/theme/app_theme.dart';

class SeerrBrandLogo extends StatelessWidget {
  const SeerrBrandLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 30.0 : 42.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: markSize,
          height: markSize,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(markSize * 0.3),
            boxShadow: [
              BoxShadow(
                color: AppColors.violet.withValues(alpha: 0.3),
                blurRadius: 18,
                spreadRadius: -4,
              ),
            ],
          ),
          child: CustomPaint(painter: const _SeerrMarkPainter()),
        ),
        SizedBox(width: compact ? 9 : 12),
        Text(
          'Seerr',
          style:
              (compact
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineSmall)
                  ?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
        ),
      ],
    );
  }
}

class _SeerrMarkPainter extends CustomPainter {
  const _SeerrMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.7, size.height * 0.28)
      ..cubicTo(
        size.width * 0.58,
        size.height * 0.18,
        size.width * 0.3,
        size.height * 0.2,
        size.width * 0.3,
        size.height * 0.39,
      )
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.56,
        size.width * 0.7,
        size.height * 0.44,
        size.width * 0.7,
        size.height * 0.64,
      )
      ..cubicTo(
        size.width * 0.7,
        size.height * 0.82,
        size.width * 0.4,
        size.height * 0.84,
        size.width * 0.27,
        size.height * 0.72,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SeerrMarkPainter oldDelegate) => false;
}
