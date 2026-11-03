import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:work_time_tracker/core/theme/app_glass_tokens.dart';

/// 在弹窗自身边界内提供轻量背景模糊，延续页面玻璃层次。
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppGlassTokens.standardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppGlassTokens.surfaceBlurSigma,
          sigmaY: AppGlassTokens.surfaceBlurSigma,
        ),
        child: child,
      ),
    );
  }
}
