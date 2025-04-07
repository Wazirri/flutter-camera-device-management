import 'package:flutter/material.dart';
import 'package:camera_device_manager/theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final double? width;
  final EdgeInsetsGeometry contentPadding;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.width,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        validator: validator,
        onChanged: onChanged,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        cursorColor: AppTheme.accentColor,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          contentPadding: contentPadding,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppTheme.accentColor) : null,
          suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: AppTheme.accentColor) : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.accentColor),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.errorColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.errorColor),
          ),
          filled: true,
          fillColor: AppTheme.darkCardColor,
        ),
      ),
    );
  }
}
