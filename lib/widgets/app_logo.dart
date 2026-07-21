import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SSD Manager Logo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Container(
            width: size * 0.58,
            height: size * 0.58,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.medical_services_outlined,
              color: Colors.white,
              size: size * 0.34,
            ),
          ),
        ),
      ),
    );
  }
}
