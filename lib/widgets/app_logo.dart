import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool light;

  const AppLogo({super.key, this.size = 88, this.light = false});

  @override
  Widget build(BuildContext context) {
    final badgeColor = light ? Colors.white : AppColors.primary;
    final iconColor = light ? AppColors.primary : Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: light
            ? null
            : LinearGradient(
                colors: [AppColors.primary, AppColors.lightBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: light ? badgeColor : null,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        Icons.checkroom,
        size: size * 0.5,
        color: iconColor,
      ),
    );
  }
}

class AppLogoWithText extends StatelessWidget {
  final double logoSize;
  final bool light;

  const AppLogoWithText({super.key, this.logoSize = 88, this.light = false});

  @override
  Widget build(BuildContext context) {
    final titleColor = light ? Colors.white : AppColors.primary;
    final subtitleColor =
        light ? Colors.white.withValues(alpha: 0.8) : Colors.grey[600];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize, light: light),
        const SizedBox(height: 16),
        Text(
          'PREMIER',
          style: TextStyle(
            fontSize: logoSize * 0.27,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: titleColor,
          ),
        ),
        Text(
          'LAUNDRY',
          style: TextStyle(
            fontSize: logoSize * 0.18,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
            color: light ? Colors.white70 : AppColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bersih, Wangi, Rapi Setiap Saat',
          style: TextStyle(fontSize: 13, color: subtitleColor),
        ),
      ],
    );
  }
}
