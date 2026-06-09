import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';

/// Neo-brutalist button with thick border and drop shadow.
/// Replicates the Stitch CTA style:
/// `border-4 border-primary shadow-[6px_6px_0px_0px_rgba(26,26,26,1)]`
class BrutalistButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final bool isFullWidth;

  const BrutalistButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.isFullWidth = true,
  });

  @override
  State<BrutalistButton> createState() => _BrutalistButtonState();
}

class _BrutalistButtonState extends State<BrutalistButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppColors.primaryContainer;
    final fgColor = widget.foregroundColor ?? AppColors.onPrimaryContainer;
    final bColor = widget.borderColor ?? AppColors.onBackground;

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          setState(() => _isPressed = true);
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null) {
          setState(() => _isPressed = false);
          widget.onPressed!();
        }
      },
      onTapCancel: () {
        if (widget.onPressed != null) {
          setState(() => _isPressed = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.isFullWidth ? double.infinity : null,
        transform: Matrix4.translationValues(
          _isPressed ? 4.0 : 0.0,
          _isPressed ? 4.0 : 0.0,
          0.0,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: bColor,
            width: AppSpacing.borderMedium,
          ),
          boxShadow: _isPressed
              ? null
              : [
                  BoxShadow(
                    color: AppColors.onBackground,
                    offset: const Offset(4, 4),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.leadingIcon != null) ...[
              Icon(
                widget.leadingIcon,
                color: fgColor,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                style: AppTypography.labelLarge.copyWith(
                  color: fgColor,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.trailingIcon != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                widget.trailingIcon,
                color: fgColor,
                size: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
