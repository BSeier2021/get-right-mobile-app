import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Modern elevated button with enhanced visual hierarchy and micro-interactions
class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;
  final Widget? icon;
  final bool isPrimary;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
    this.height,
    this.icon,
    this.isPrimary = true,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  @override
  Widget build(BuildContext context) {
    final actualBackgroundColor = widget.backgroundColor ?? (AppColors.accent);
    final isGreenButton = actualBackgroundColor == AppColors.accent;

    return Container(
      width: widget.isFullWidth ? double.infinity : null,
      height: widget.height ?? 46.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: isGreenButton
            ? LinearGradient(
                colors: widget.onPressed == null || widget.isLoading
                    ? [actualBackgroundColor, actualBackgroundColor]
                    : [const Color.fromARGB(255, 29, 68, 43), AppColors.accentVariant.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isGreenButton ? null : actualBackgroundColor,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onPressed,
          borderRadius: BorderRadius.circular(16),

          child: Center(
            child: widget.isLoading
                ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: AppColors.accentVariant, strokeWidth: 2.5))
                : widget.icon != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconTheme(
                        data: IconThemeData(color: AppColors.accent, size: 22),
                        child: widget.icon!,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.text,
                        style: AppTextStyles.buttonLarge.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                    ],
                  )
                : Text(
                    widget.text,
                    style: AppTextStyles.buttonLarge.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Modern outlined button with enhanced visuals
class CustomOutlineButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isFullWidth;
  final Color? borderColor;
  final Color? textColor;
  final double? height;
  final Widget? icon;

  const CustomOutlineButton({super.key, required this.text, this.onPressed, this.isFullWidth = true, this.borderColor, this.textColor, this.height, this.icon});

  @override
  State<CustomOutlineButton> createState() => _CustomOutlineButtonState();
}

class _CustomOutlineButtonState extends State<CustomOutlineButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final actualBorderColor = widget.borderColor ?? AppColors.primaryGray.withValues(alpha: 0.4);
    final actualTextColor = widget.textColor ?? AppColors.onBackground;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.isFullWidth ? double.infinity : null,
        height: widget.height ?? 46.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _isHovered ? AppColors.accent : const Color.fromARGB(255, 7, 7, 8), width: 2),
          color: _isHovered ? AppColors.accent.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(16),

            child: Center(
              child: widget.icon != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconTheme(
                          data: IconThemeData(color: _isHovered ? AppColors.accent : actualTextColor, size: 22),
                          child: widget.icon!,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.text,
                          style: AppTextStyles.buttonLarge.copyWith(
                            color: _isHovered ? AppColors.accent : actualTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      widget.text,
                      style: AppTextStyles.buttonLarge.copyWith(
                        color: _isHovered ? AppColors.accent : AppColors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
