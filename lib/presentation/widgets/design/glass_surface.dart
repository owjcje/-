import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:work_time_tracker/core/theme/app_glass_tokens.dart';

/// 为固定界面区域提供裁剪后的磨砂表面，避免模糊越过圆角边界。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.isBlurred = false,
    this.padding,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppGlassTokens.standardRadius),
    ),
    this.color,
    this.width,
    super.key,
  });

  final Widget child;
  final bool isBlurred;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final Color? color;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppGlassTokens.strongSurface,
        borderRadius: borderRadius,
        border: Border.all(color: AppGlassTokens.glassBorder),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: AppGlassTokens.shadow,
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: isBlurred
              ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: AppGlassTokens.surfaceBlurSigma,
                    sigmaY: AppGlassTokens.surfaceBlurSigma,
                  ),
                  child: surface,
                )
              : surface,
        ),
      ),
    );
  }
}
