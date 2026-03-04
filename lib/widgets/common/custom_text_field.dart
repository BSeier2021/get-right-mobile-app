import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Modern custom text field with enhanced UX and floating label animation
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: 56, // Fixed height for all text fields
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: widget.enabled ? Color(0x19523A21) : Color(0x19523A21).withOpacity(0.5),
            border: Border.all(
              color: _hasError
                  ? AppColors.error
                  : _isFocused
                  ? AppColors.accent
                  : const Color(0xFF666666), // Dark gray border
              width: _isFocused ? 2 : 1.5,
            ),
            boxShadow: _isFocused ? [BoxShadow(color: AppColors.accent.withOpacity(0.15), blurRadius: 12, spreadRadius: 0, offset: const Offset(0, 4))] : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            validator: (value) {
              final error = widget.validator?.call(value);
              setState(() {
                _hasError = error != null;
              });
              return error;
            },
            onChanged: widget.onChanged,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            inputFormatters: widget.inputFormatters,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: widget.hintText,
              errorText: widget.errorText,
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: IconTheme(
                        data: IconThemeData(
                          color: _isFocused
                              ? AppColors.accent
                              : _hasError
                              ? AppColors.error
                              : AppColors.primaryGray,
                          size: 22,
                        ),
                        child: widget.prefixIcon!,
                      ),
                    )
                  : null,
              suffixIcon: widget.suffixIcon != null ? Padding(padding: const EdgeInsets.only(right: 12), child: widget.suffixIcon) : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              filled: false,
              contentPadding: EdgeInsets.symmetric(horizontal: widget.prefixIcon != null ? 0 : 18, vertical: 16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              labelStyle: AppTextStyles.bodyMedium.copyWith(color: _isFocused ? AppColors.accent : AppColors.primaryGray, fontSize: 15, fontWeight: FontWeight.w500),
              floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: _isFocused ? AppColors.accent : AppColors.primaryGray, fontSize: 13, fontWeight: FontWeight.w600),
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: const Color.fromARGB(255, 117, 116, 116), // Consistent light grey hint text color
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              errorStyle: const TextStyle(height: 0.01, color: Colors.transparent),
              counterText: '',
            ),
          ),
        ),
        if (_hasError && widget.errorText == null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              _hasError ? 'Invalid input' : '',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}

/// Modern password text field with animated visibility toggle
class PasswordTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const PasswordTextField({super.key, this.controller, this.labelText, this.hintText, this.errorText, this.validator, this.onChanged});

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscureText = true;

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      hintText: widget.hintText ?? 'Enter your password',
      errorText: widget.errorText,
      obscureText: _obscureText,

      keyboardType: TextInputType.visiblePassword,
      validator: widget.validator,
      onChanged: widget.onChanged,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return RotationTransition(
              turns: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(_obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, key: ValueKey<bool>(_obscureText), color: AppColors.primaryGray, size: 22),
        ),
        onPressed: _toggleVisibility,
        tooltip: _obscureText ? 'Show password' : 'Hide password',
      ),
    );
  }
}
