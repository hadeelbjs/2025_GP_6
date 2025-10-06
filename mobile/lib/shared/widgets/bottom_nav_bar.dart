import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const BottomNavBar({super.key, this.currentIndex = 4, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 0),              // الرئيسية
          _buildNavItem(Icons.notifications, 1),     // الإشعارات
          _buildNavItem(Icons.grid_view, 2),         // الأدوات
          _buildNavItem(Icons.mail_outline, 3),      // المحادثات
          _buildNavItem(Icons.person, 4),            // جهات الاتصال
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap?.call(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.primary : AppColors.textHint,
            size: 26,
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 3,
              width: 10,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}