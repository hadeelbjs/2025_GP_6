import 'package:flutter/material.dart';
import '/services/api_services.dart';
import '../../../services/biometric_service.dart';

class BiometricSetupDialog extends StatefulWidget {
  const BiometricSetupDialog({super.key});

  @override
  State<BiometricSetupDialog> createState() => _BiometricSetupDialogState();
}

class _BiometricSetupDialogState extends State<BiometricSetupDialog> {
  final _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _setupBiometric() async {
    setState(() => _isLoading = true);

    try {
      final isSupported = await BiometricService.isDeviceSupported();
      if (!isSupported) {
        _showMessage('هذا الجهاز لا يدعم البصمة');
        _closeDialog();
        return;
      }

      final canCheck = await BiometricService.canCheckBiometrics();
      if (!canCheck) {
        _showMessage('لا توجد بصمات محفوظة في الجهاز');
        _closeDialog();
        return;
      }

final userData = await _apiService.getUserData();
if (userData == null) {
  _showMessage('خطأ في بيانات المستخدم');
  _closeDialog();
  return;
}

final success = await BiometricService.enableBiometric(userData['email']);      
      if (success) {
        _showMessage('تم تفعيل البصمة بنجاح!');
        Navigator.of(context).pop(true);
      } else {
        _showMessage('فشل في تفعيل البصمة');
        _closeDialog();
      }

    } catch (e) {
      _showMessage('حدث خطأ: $e');
      _closeDialog();
    }

    setState(() => _isLoading = false);
  }

  void _closeDialog() {
    Navigator.of(context).pop(false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          textAlign: TextAlign.center,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2D1B69).withOpacity(0.1),
              ),
              child: const Icon(
                Icons.fingerprint,
                size: 40,
                color: Color(0xFF2D1B69),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'تفعيل الدخول السريع',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'IBMPlexSansArabic',
                color: Color(0xFF2D1B69),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'هل تريدين تفعيل البصمة للدخول السريع؟\nستوفر عليك الوقت في المرات القادمة',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'IBMPlexSansArabic',
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : _closeDialog,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'لاحقاً',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'IBMPlexSansArabic',
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _setupBiometric,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D1B69),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'تفعيل',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}