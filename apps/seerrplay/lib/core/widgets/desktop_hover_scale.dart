import 'package:flutter/material.dart';
import 'package:seerrplay/core/platform/platform_capabilities.dart';
import 'package:seerrplay/core/widgets/app_page_layout.dart';

class DesktopHoverScale extends StatefulWidget {
  const DesktopHoverScale({required this.child, super.key});

  final Widget child;

  @override
  State<DesktopHoverScale> createState() => _DesktopHoverScaleState();
}

class _DesktopHoverScaleState extends State<DesktopHoverScale> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform && !AppPageLayout.usesLargeScreenLayout(context)) {
      return widget.child;
    }
    return Focus(
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _focused ? 1.045 : (_hovered ? 1.025 : 1),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
