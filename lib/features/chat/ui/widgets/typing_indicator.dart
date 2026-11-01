import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_fonts.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'UniGuide is responding',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'UniGuide is responding',
              style: AppFonts.messageLabel(
                color: AppColors.muted,
                isUser: false,
              ),
            ),
            const SizedBox(width: 10),
            ...List.generate(
              3,
              (index) => AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final animationValue = (_controller.value - (index * 0.18))
                      .clamp(0.0, 1.0)
                      .toDouble();
                  final opacity =
                      (0.35 + (animationValue * 0.65)).clamp(0.35, 1.0);

                  return Container(
                    margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
