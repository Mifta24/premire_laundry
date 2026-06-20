import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class AuthIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;

  const AuthIconBadge({super.key, required this.icon, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.lightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.45, color: Colors.white),
    );
  }
}
