// lib/shared/widgets/bottom_nav_bar.dart
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../features/dashboard/screens/main_dashboard.dart';
import '/features/contact/screens/contacts_list_screen.dart';
import '/features/massaging/screens/chat_list_screen.dart';
import 'package:waseed/features/account/screens/manage_account_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({super.key, this.currentIndex = 0});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive calculations
    final isSmallScreen = screenWidth < 360;
    final isTinyScreen = screenWidth < 320;
    final isShortScreen = screenHeight < 700;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTinyScreen ? 8 : (isSmallScreen ? 12 : 16),
            vertical: isTinyScreen ? 6 : (isSmallScreen ? 8 : 10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem(
                context,
                Icons.home_rounded,
                'الرئيسية',
                0,
                screenWidth,
                isShortScreen,
              ),
              _buildNavItem(
                context,
                Icons.people_rounded,
                'جهات الاتصال',
                1,
                screenWidth,
                isShortScreen,
              ),
              _buildNavItem(
                context,
                Icons.grid_view_rounded,
                'الخدمات',
                2,
                screenWidth,
                isShortScreen,
              ),
              _buildNavItem(
                context,
                Icons.chat_bubble_rounded,
                'المحادثات',
                3,
                screenWidth,
                isShortScreen,
              ),
              _buildNavItem(
                context,
                Icons.person_rounded,
                'الحساب',
                4,
                screenWidth,
                isShortScreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    double screenWidth,
    bool isShortScreen,
  ) {
    final isActive = currentIndex == index;
    
    // Responsive sizing based on screen width
    final double iconSize;
    final double fontSize;
    final double spacing;
    final double verticalPadding;
    
    if (screenWidth < 320) {
      // Tiny screens
      iconSize = 18.0;
      fontSize = 7.5;
      spacing = 1.0;
      verticalPadding = 4.0;
    } else if (screenWidth < 360) {
      // Small screens
      iconSize = 20.0;
      fontSize = 8.0;
      spacing = 2.0;
      verticalPadding = 5.0;
    } else if (screenWidth < 400) {
      // Medium screens
      iconSize = 22.0;
      fontSize = 9.0;
      spacing = 3.0;
      verticalPadding = 6.0;
    } else {
      // Large screens
      iconSize = 24.0;
      fontSize = 10.0;
      spacing = 4.0;
      verticalPadding = 8.0;
    }
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNavigation(context, index),
          borderRadius: BorderRadius.circular(14),
          splashColor: AppColors.primary.withOpacity(0.1),
          highlightColor: AppColors.primary.withOpacity(0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              vertical: verticalPadding,
              horizontal: 2,
            ),
            decoration: BoxDecoration(
              color: isActive 
                  ? AppColors.primary.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isActive ? AppColors.primary : AppColors.textHint,
                  size: iconSize,
                ),
                SizedBox(height: spacing),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? AppColors.primary : AppColors.textHint,
                      fontFamily: 'IBMPlexSansArabic',
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget? destination;

    switch (index) {
      case 0:
        destination = const MainDashboard();
        break;
      case 1:
        destination = const ContactsListScreen();
        break;
      case 2:
        _showDevMessage(context, 'صفحة الخدمات قيد التطوير');
        return;
      case 3:
        destination = const ChatListScreen();
        break;
      case 4:
        destination = const AccountManagementScreen();
        break;
    }

    if (destination != null) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destination!,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
        ),
      );
    }
  }

  void _showDevMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 4,
      ),
    );
  }
}