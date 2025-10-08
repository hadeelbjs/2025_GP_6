import 'package:flutter/material.dart';
import '/shared/widgets/header_widget.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/api_services.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      final result = await _apiService.getPendingRequests();

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(
            result['requests'].map((req) => {
              'requestId': req['requestId'],
              'userId': req['user']['id'],
              'fullName': req['user']['fullName'],
              'username': req['user']['username'],
              'createdAt': req['createdAt'],
            }),
          );
        });
      } else {
        _showMessage(result['message'] ?? 'فشل تحميل الطلبات', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في تحميل الطلبات', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptRequest(String requestId, String fullName) async {
    try {
      final result = await _apiService.acceptContactRequest(requestId);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _requests.removeWhere((r) => r['requestId'] == requestId);
        });
        _showMessage(result['message'] ?? 'تم قبول الطلب من $fullName', true);
      } else {
        _showMessage(result['message'] ?? 'فشل قبول الطلب', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في قبول الطلب', false);
    }
  }

  Future<void> _rejectRequest(String requestId, String fullName) async {
    try {
      final result = await _apiService.rejectContactRequest(requestId);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _requests.removeWhere((r) => r['requestId'] == requestId);
        });
        _showMessage(result['message'] ?? 'تم رفض الطلب من $fullName', true);
      } else {
        _showMessage(result['message'] ?? 'فشل رفض الطلب', false);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('خطأ في رفض الطلب', false);
    }
  }

  void _showMessage(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: SafeArea(
          child: Column(
            children: [
              const HeaderWidget(
                title: 'الإشعارات',
                showBackButton: true,
                showBackground: false,
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _requests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 80,
                                  color: AppColors.textHint.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد إشعارات',
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.textHint,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'سيتم عرض طلبات الصداقة هنا',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadRequests,
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _requests.length,
                              itemBuilder: (context, index) {
                                final request = _requests[index];
                                return _buildRequestCard(request);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final requestId = request['requestId'];
    final fullName = request['fullName'];
    final username = request['username'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.primary,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          const TextSpan(text: 'قام '),
                          TextSpan(
                            text: '@$username',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'بطلب إضافتك',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(requestId, fullName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'قبول',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _rejectRequest(requestId, fullName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.close, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'رفض',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}