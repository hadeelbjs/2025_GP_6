import 'package:flutter/material.dart';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/bottom_nav_bar.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/api_services.dart';
import '../../contact/screens/notifications_screen.dart';


class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final _apiService = ApiService();
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final result = await _apiService.getPendingRequests();
      if (result['success'] && mounted) {
        setState(() {
          _notificationCount = result['count'] ?? 0;
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const HeaderWidget(
                title: '',
                showBackground: true,
                alignTitleRight: false,
              ),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.06),
                  child: Transform.translate(
                    offset: Offset(0, -height * 0.045),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),

                        Align(
                          alignment: Alignment.topLeft,
                          child: _Bell(
                            count: _notificationCount,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              );
                              _loadNotificationCount();
                            },
                          ),
                        ),

                        const SizedBox(height: 6),

                        _buildTitle('مرحبًا بك', width * 0.085, context),

                        const SizedBox(height: 10),

                        _buildTitle('لوحة المعلومات', width * 0.05, context),

                        const SizedBox(height: 8),

                        _buildInfoCard(context),

                        const SizedBox(height: 12),

                        _buildTipHeader(context),

                        const SizedBox(height: 8),

                        _buildTipText(context),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const BottomNavBar(currentIndex: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String text, double size, BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AppTextStyles.h1.copyWith(fontSize: size),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    return Container(
      padding: EdgeInsets.all(width * 0.055),
      constraints: BoxConstraints(minHeight: size.height * 0.16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.04),
        boxShadow: [
          BoxShadow(
            blurRadius: 15,
            offset: const Offset(0, 3),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: const Color(0xFFFFB74D), size: width * 0.06),
          SizedBox(width: width * 0.035),
          Expanded(
            child: Text(
              'تم اكتشاف تسجيل دخول مريب',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyLarge.copyWith(
                fontSize: width * 0.042,
                color: AppColors.textPrimary.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipHeader(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lightbulb_outline, color: const Color(0xFFFFD54F), size: width * 0.055),
        SizedBox(width: width * 0.02),
        Text('نصيحة اليوم', style: AppTextStyles.h3.copyWith(fontSize: width * 0.05)),
      ],
    );
  }

  Widget _buildTipText(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: width * 0.01,
            height: width * 0.088,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: width * 0.03),
          Expanded(
            child: Text(
              'لا تستخدم نفس كلمة المرور في أكثر من حساب',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: width * 0.0375,
                color: AppColors.textPrimary.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _Bell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Transform.translate(
      offset: const Offset(0, -20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(w * 0.03),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(w * 0.022),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(w * 0.03),
                border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
              ),
              child: Icon(Icons.notifications, color: AppColors.textPrimary, size: w * 0.066),
            ),
            if (count > 0)
              Positioned(
                top: -5,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: w * 0.05,
                    minHeight: w * 0.05,
                  ),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : count.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: w * 0.028,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}