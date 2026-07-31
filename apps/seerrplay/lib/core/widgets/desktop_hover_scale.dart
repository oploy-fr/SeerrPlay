import 'package:flutter/material.dart';
import 'package:seerrplay/core/platform/platform_capabilities.dart';

class DesktopHoverScale extends StatefulWidget {
  const DesktopHoverScale({required this.child, super.key});

  final Widget child;

  @override
  State<DesktopHoverScale> createState() => _DesktopHoverScaleState();
}

class _DesktopHoverScaleState extends State<DesktopHoverScale> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform) return widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.025 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
