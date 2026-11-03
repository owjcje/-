import 'package:flutter/material.dart';
import 'package:work_time_tracker/core/theme/app_glass_tokens.dart';

/// 承载玻璃表面的低对比渐变画布与装饰光晕。
class GlassBackground extends StatelessWidget {
  const GlassBackground({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppGlassTokens.canvasBase,
            Color(0xFFF7F8FC),
            AppGlassTokens.canvasBase,
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: -170, // 顶部蓝色光晕超出画布，避免出现边缘
            right: -100,
            child: _BackgroundGlow(
              color: AppGlassTokens.canvasBlueGlow,
              size: 390,
            ),
          ),
          const Positioned(
            bottom: -220, // 底部薄荷光晕用于平衡页面冷暖层次
            left: -130,
            child: _BackgroundGlow(
              color: AppGlassTokens.canvasMintGlow,
              size: 430,
            ),
          ),
          const Positioned(
            top: 250, // 中部粉紫光晕增加玻璃材质下的色彩层次
            left: 360,
            child: _BackgroundGlow(
              color: AppGlassTokens.canvasRoseGlow,
              size: 250,
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: SizedBox(width: size, height: size),
      ),
    );
  }
}
