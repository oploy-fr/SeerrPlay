import 'package:flutter/material.dart';
import 'package:seerrplay/core/theme/app_theme.dart';

const profileAvatarCount = 8;

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.avatarIndex,
    required this.size,
    super.key,
    this.selected = false,
  });

  final int avatarIndex;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final normalizedIndex = avatarIndex % profileAvatarCount;
    final palette = _palettes[normalizedIndex];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      padding: EdgeInsets.all(selected ? 3 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        border: selected ? Border.all(color: AppColors.white, width: 2) : null,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette,
            ),
          ),
          child: CustomPaint(painter: _AvatarPainter(index: normalizedIndex)),
        ),
      ),
    );
  }
}

const _palettes = <List<Color>>[
  [AppColors.magenta, AppColors.violet],
  [AppColors.violet, AppColors.cyan],
  [Color(0xFFFF8243), AppColors.magenta],
  [Color(0xFF1AC97A), AppColors.cyan],
  [Color(0xFFFFC043), Color(0xFFFF6B6B)],
  [Color(0xFF536DFE), AppColors.violet],
  [AppColors.cyan, Color(0xFF3F51B5)],
  [Color(0xFFFF5E7D), Color(0xFFFFC371)],
];

class _AvatarPainter extends CustomPainter {
  const _AvatarPainter({required this.index});

  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = AppColors.white.withValues(alpha: 0.94);
    final dark = Paint()..color = AppColors.background.withValues(alpha: 0.78);
    final accent = Paint()..color = AppColors.white.withValues(alpha: 0.24);
    canvas.drawCircle(
      Offset(size.width * (index.isEven ? 0.18 : 0.82), size.height * 0.18),
      size.width * 0.26,
      accent,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.54),
      size.width * 0.31,
      white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.39, size.height * 0.5),
      size.width * 0.035,
      dark,
    );
    canvas.drawCircle(
      Offset(size.width * 0.61, size.height * 0.5),
      size.width * 0.035,
      dark,
    );
    final smile = Path()
      ..moveTo(size.width * 0.37, size.height * 0.63)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * (index % 3 == 0 ? 0.76 : 0.7),
        size.width * 0.64,
        size.height * 0.62,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = dark.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.035
        ..strokeCap = StrokeCap.round,
    );
    if (index % 2 == 1) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.38),
          width: size.width * 0.58,
          height: size.height * 0.45,
        ),
        3.2,
        3.0,
        false,
        dark,
      );
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) => oldDelegate.index != index;
}
