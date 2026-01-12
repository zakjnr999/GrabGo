import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:confetti/confetti.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'dart:math';

/// Full-screen celebration animation shown when order is delivered
class DeliverySuccessScreen extends StatefulWidget {
  final String orderId;
  final VoidCallback onComplete;

  const DeliverySuccessScreen({super.key, required this.orderId, required this.onComplete});

  @override
  State<DeliverySuccessScreen> createState() => _DeliverySuccessScreenState();
}

class _DeliverySuccessScreenState extends State<DeliverySuccessScreen> with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _checkmarkController;
  late Animation<double> _checkmarkScale;
  late Animation<double> _checkmarkOpacity;

  @override
  void initState() {
    super.initState();

    // Confetti controller
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Checkmark animation controller
    _checkmarkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _checkmarkScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _checkmarkController, curve: Curves.elasticOut));

    _checkmarkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkmarkController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Start animations
    _startAnimations();
  }

  void _startAnimations() async {
    // Start confetti immediately
    _confettiController.play();

    // Delay checkmark slightly for better effect
    await Future.delayed(const Duration(milliseconds: 300));
    _checkmarkController.forward();

    // Navigate to rating screen after 3 seconds
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // Down
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
              shouldLoop: false,
              colors: [
                colors.accentOrange,
                colors.accentBlue,
                colors.accentViolet,
                colors.accentGreen,
                const Color(0xFFFFD700), // Gold
                const Color(0xFFFF69B4), // Pink
              ],
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Checkmark
                AnimatedBuilder(
                  animation: _checkmarkController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _checkmarkOpacity.value,
                      child: Transform.scale(
                        scale: _checkmarkScale.value,
                        child: Container(
                          width: 120.w,
                          height: 120.h,
                          decoration: BoxDecoration(
                            color: colors.accentGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.accentGreen.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(Icons.check_rounded, color: Colors.white, size: 70.sp),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: 32.h),

                // Success text
                AnimatedBuilder(
                  animation: _checkmarkController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _checkmarkOpacity.value,
                      child: Column(
                        children: [
                          Text(
                            'Order Delivered!',
                            style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'Enjoy your meal!',
                            style: TextStyle(fontSize: 18.sp, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
