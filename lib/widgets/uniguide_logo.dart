import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

class UniGuideLogo extends StatelessWidget {
  const UniGuideLogo({
    super.key,
    this.size = 40,
  });

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/images/uniguide-logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticsLabel: 'UniGuide logo',
        errorBuilder: (context, error, stackTrace) => Semantics(
          label: 'UniGuide logo',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: SizedBox(
              width: size,
              height: size,
              child: ColoredBox(
                color: AppColors.primary,
                child: Center(
                  child: Text(
                    'U',
                    style: TextStyle(
                      color: AppColors.background,
                      fontSize: size * 0.6,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
