import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Animated three-dot typing indicator shown while waiting for AI response.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true),
    );
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(c))
        .toList();

    // Stagger the animations
    Future.delayed(
        const Duration(milliseconds: 150), () {
          if (mounted) _controllers[0].forward();
        });
    Future.delayed(
        const Duration(milliseconds: 300), () {
          if (mounted) _controllers[1].forward();
        });
    Future.delayed(
        const Duration(milliseconds: 450), () {
          if (mounted) _controllers[2].forward();
        });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _anims[i],
            builder: (ctx, child) {
              return Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.white30,
                    kPrimaryColor,
                    _anims[i].value,
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
