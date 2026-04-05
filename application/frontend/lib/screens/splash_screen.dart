import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _dotsController;

  // Animations
  late Animation<double> _ringsOpacity;
  late Animation<double> _ringsScale;
  late Animation<double> _logoScale;
  late Animation<double> _logoGlow;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineOpacity;
  late Animation<double> _dotsOpacity;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Phase 1: Rings (0.0 - 0.24 -> 0 to 0.6s of 2.5s)
    _ringsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.24, curve: Curves.easeOut),
      ),
    );
    _ringsScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.24, curve: Curves.easeOut),
      ),
    );

    // Phase 2: Logo scale & glow (0.16 - 0.40 -> 0.4s to 1.0s)
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.16, 0.40, curve: Curves.elasticOut),
      ),
    );
    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.16, 0.40, curve: Curves.easeOut),
      ),
    );

    // Phase 3: Title fade & slide (0.32 - 0.48 -> 0.8s to 1.2s)
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.32, 0.48, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.32, 0.48, curve: Curves.easeOutCubic),
      ),
    );

    // Phase 4: Tagline fade (0.40 - 0.56 -> 1.0s to 1.4s)
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.40, 0.56, curve: Curves.easeIn),
      ),
    );

    // Phase 5: Loading dots (0.60 - 1.0 -> 1.5s to 2.5s)
    _dotsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.60, 0.70, curve: Curves.easeIn),
      ),
    );

    _mainController.forward();

    // Start dots bouncing at 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _dotsController.repeat();
    });

    // Phase 6: Navigate after 2.5s + small buffer
    Future.delayed(const Duration(milliseconds: 2700), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const AuthGate(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  Widget _buildBouncingDots() {
    return FadeTransition(
      opacity: _dotsOpacity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _dotsController,
            builder: (context, child) {
              final delay = index * 0.2;
              double bounce = 0.0;

              // Simple staggered bounce math
              double t = (_dotsController.value - delay) % 1.0;
              if (t >= 0 && t < 0.5) {
                bounce = Curves.easeOutSine.transform(t * 2) * -6.0;
              } else if (t >= 0.5 && t < 1.0) {
                bounce = Curves.easeInSine.transform((t - 0.5) * 2) * 6.0 - 6.0;
              }

              return Transform.translate(
                offset: Offset(0, bounce),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: kPrimaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Concentric rings & Logo
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: _ringsOpacity.value,
                              child: Transform.scale(
                                scale: _ringsScale.value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: kPrimaryColor.withValues(alpha: 0.1),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: _ringsOpacity.value,
                              child: Transform.scale(
                                scale: _ringsScale.value * 1.3,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: kPrimaryColor.withValues(alpha: 0.05),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Logo Shield
                            Transform.scale(
                              scale: _logoScale.value,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: kSurfaceColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: kPrimaryColor
                                          .withValues(alpha: _logoGlow.value * 0.3),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: kPrimaryColor.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.health_and_safety,
                                  color: kPrimaryColor,
                                  size: 38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Title
                      SlideTransition(
                        position: _titleSlide,
                        child: Opacity(
                          opacity: _titleOpacity.value,
                          child: Text(
                            'MediGuide',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tagline
                      Opacity(
                        opacity: _taglineOpacity.value,
                        child: Text(
                          'Private · Offline · Secure',
                          style: GoogleFonts.dmSans(
                            color: Colors.white38,
                            fontSize: 14,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Loading dots anchor at bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: SizedBox(
                    height: 20,
                    child: _buildBouncingDots(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
