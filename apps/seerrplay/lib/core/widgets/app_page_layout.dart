import 'package:flutter/material.dart';
import 'package:seerrplay/core/platform/platform_capabilities.dart';

abstract final class AppPageLayout {
  static const double desktopHorizontalInset = 52;

  static bool usesDesktopInsets(BuildContext context) =>
      isDesktopPlatform && MediaQuery.sizeOf(context).width >= 1000;

  static double horizontalInset(BuildContext context, {double compact = 16}) =>
      usesDesktopInsets(context) ? desktopHorizontalInset : compact;
}

class AppPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageAppBar({required this.title, super.key});

  final Widget title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: AppPageLayout.horizontalInset(context),
      title: title,
    );
  }
}
