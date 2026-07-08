import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-width brand-gradient button used for primary actions (Open, Merge, …).
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  else if (icon != null)
                    Icon(icon, color: Colors.white, size: 22),
                  if (busy || icon != null) const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
