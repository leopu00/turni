import 'package:flutter/material.dart';

/// Provides reusable brand widgets (logo and mark) so the app stays consistent.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width = 180,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (width * devicePixelRatio).round();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = isDark
        ? 'assets/branding/logo_dark_512.png'
        : 'assets/branding/logo_light_512.png';
    return Image.asset(
      asset,
      width: width,
      cacheWidth: cacheWidth > 0 ? cacheWidth : null,
      fit: BoxFit.contain,
      semanticLabel: 'iTurni',
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 28,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (size * devicePixelRatio).round();
    return Image.asset(
      'assets/branding/favicon_256.png',
      width: size,
      height: size,
      cacheWidth: cacheWidth > 0 ? cacheWidth : null,
      fit: BoxFit.contain,
      semanticLabel: 'iTurni',
    );
  }
}

class BrandAppBarTitle extends StatelessWidget {
  const BrandAppBarTitle({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 28),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
