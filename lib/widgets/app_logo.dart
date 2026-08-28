import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/splash_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class AppLogoWithText extends StatelessWidget {
  final double logoSize;

  const AppLogoWithText({super.key, this.logoSize = 88});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize),
        const SizedBox(height: 12),
        Text(
          'Bersih, Wangi, Rapi Setiap Saat',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
