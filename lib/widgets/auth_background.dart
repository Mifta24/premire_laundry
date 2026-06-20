import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -40,
          child: _bubble(160, AppColors.lightBlue.withValues(alpha: 0.25)),
        ),
        Positioned(
          top: 120,
          left: -50,
          child: _bubble(100, AppColors.secondary.withValues(alpha: 0.15)),
        ),
        Positioned(
          bottom: -50,
          right: -30,
          child: _bubble(140, AppColors.primary.withValues(alpha: 0.1)),
        ),
        child,
      ],
    );
  }

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
