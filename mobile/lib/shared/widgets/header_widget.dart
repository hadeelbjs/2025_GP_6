import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';

class HeaderWidget extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool showBackground;
  final bool alignTitleRight;

  const HeaderWidget({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBackPressed,
    this.showBackground = true,
    this.alignTitleRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = showBackButton ? 120.0 : 140.0;

    return SizedBox(
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(decoration: BoxDecoration(color: AppColors.background)),

          if (showBackground) ...[
            Align(
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(-30, -0.40 * h),
                child: Image.asset(
                  'assets/images/Rectangle 13.png',
                  width: w * 1.25,
                ),
              ),
            ),

            Positioned(
              top: -0.40 * h,
              right: 0.50 * w,
              child: Image.asset(
                'assets/images/Rectangle 14.png',
                width: w * 0.58,
              ),
            ),
          ],

          Positioned(
            right: 0,
            left: 0,
            top: 40,
            child: showBackButton
                ? Row(
                    children: [
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed:
                            onBackPressed ?? () => Navigator.pop(context),
                        icon: Image.asset(
                          'assets/icons/back_arrow.png',
                          width: 22,
                          height: 22,
                        ),
                      ),
                      const Spacer(),
                      Text(title, style: AppTextStyles.h3),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: alignTitleRight
                          ? Alignment.centerRight
                          : Alignment.center,
                      child: Text(
                        title,
                        style: AppTextStyles.h1,
                        textAlign: alignTitleRight
                            ? TextAlign.right
                            : TextAlign.center,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
