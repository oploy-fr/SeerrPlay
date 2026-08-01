import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SeerrBrandLogo extends StatelessWidget {
  const SeerrBrandLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/branding/seerrplay_primary_logo.svg',
      height: compact ? 26 : 38,
      semanticsLabel: 'SeerrPlay',
    );
  }
}
