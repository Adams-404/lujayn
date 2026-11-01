import 'package:flutter/material.dart';

/// The Lujayn brand mark, tinted with a semantic theme colour.
///
/// The source asset is a white silhouette, so it stays legible on every theme
/// including true-black AMOLED.
class LujaynMark extends StatelessWidget {
  const LujaynMark({super.key, this.size = 40, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      image: true,
      label: 'Lujayn',
      child: Image.asset(
        'assets/images/lujayn_mark.png',
        width: size,
        height: size,
        color: tint,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
