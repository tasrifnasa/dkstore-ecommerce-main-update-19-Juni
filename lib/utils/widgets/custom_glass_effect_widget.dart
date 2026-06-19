import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';


class CustomGlassEffectWidget extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double thickness;
  final Color glassColor;
  final EdgeInsetsGeometry? padding;

  const CustomGlassEffectWidget({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.blur = 10,
    this.thickness = 60,
    this.glassColor = const Color(0x33FFFFFF),
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLayer(
      settings: LiquidGlassSettings(
        thickness: thickness,
        blur: blur,
        glassColor: glassColor,
      ),
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(
          borderRadius: borderRadius,
        ),
        child: Container(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}