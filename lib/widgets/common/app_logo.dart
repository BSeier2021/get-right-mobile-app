import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_right/constants/asset_paths.dart';
import 'package:get_right/theme/color_constants.dart';

/// Reusable app logo widget
class AppLogo extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final double borderRadius;
  final bool showShadow;
  final EdgeInsets? padding;

  const AppLogo({super.key, this.size = 150, this.backgroundColor, this.borderRadius = 16, this.showShadow = false, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow ? [BoxShadow(color: (backgroundColor ?? AppColors.secondary).withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 3, offset: const Offset(0, 5))] : null,
      ),
      child: Column(
        children: [
          Image.asset("assets/images/logo-04.png", fit: BoxFit.contain),
          10.h.verticalSpace,
          Image.asset("assets/images/logo-05.png", fit: BoxFit.contain),
        ],
      ),
    );
  }
}
