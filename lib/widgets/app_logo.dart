import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';

/// Company logo (assets/images/logo.png) with a vector fallback.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.rounded = true});

  static const String assetPath = 'assets/images/logo.png';

  final double size;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        color: AppColors.primary,
        child: Text(
          'N',
          style: TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.6,
          ),
        ),
      ),
    );
    if (!rounded) return image;
    return ClipRRect(borderRadius: BorderRadius.circular(size * 0.22), child: image);
  }
}
