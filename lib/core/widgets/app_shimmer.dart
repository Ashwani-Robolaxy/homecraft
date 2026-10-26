import 'package:flutter/material.dart';

/// A reusable animated shimmer placeholder.
/// Wraps any child [Widget] in a shimmer sweep effect.
///
/// Usage:
///   AppShimmer(child: Container(width: 100, height: 16, color: Colors.white))
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: -1, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => _ShimmerWrapper(offset: _anim.value, child: widget.child),
    );
  }
}

class _ShimmerWrapper extends StatelessWidget {
  const _ShimmerWrapper({required this.offset, required this.child});
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(offset - 1, 0),
        end: Alignment(offset + 1, 0),
        colors: const [
          Color(0xFFEDEDED),
          Color(0xFFF7F7F7),
          Color(0xFFEDEDED),
        ],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// A single rectangular shimmer placeholder box.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
  });
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 16,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A circular shimmer placeholder.
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFEDEDED),
        shape: BoxShape.circle,
      ),
    );
  }
}
