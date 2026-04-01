import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_services.dart';
import 'package:waseed/main.dart';
import 'package:waseed/features/authentication/screens/reset_password.dart';

class FrozenAccountScreen extends StatefulWidget {
  const FrozenAccountScreen({super.key});
  @override
  State<FrozenAccountScreen> createState() => _FrozenAccountScreenState();
}

class _FrozenAccountScreenState extends State<FrozenAccountScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  String _freezeType = 'email';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final args = ModalRoute.of(context)?.settings.arguments;
  if (args != null && args is Map) {
    _freezeType = args['type'] ?? 'email';
  }
}
  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _unfreeze() async {
    if (_emailController.text.isEmpty || _codeController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('الرجاء إدخال البريد والرمز كاملاً',
            style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    setState(() => _loading = true);
    final result = await _api.unfreezeAccount(
      email: _emailController.text.trim(),
      code: _codeController.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1035),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade900.withOpacity(0.3),
                    border: Border.all(color: Colors.green.shade600, width: 2),
                  ),
                  child: Icon(Icons.check, color: Colors.green.shade400, size: 38),
                ),
                const SizedBox(height: 20),
                const Text('تم فك التجميد بنجاح',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
                const SizedBox(height: 12),
                Text(
                  _freezeType == 'password'
                    ? 'تم فك التجميد بنجاح.\nيرجى الآن تغيير كلمة المرور\nلكي تتمكن من تسجيل الدخول واستخدام وصيد.'
                    : 'حسابك الآن آمن.\nيمكنك تسجيل الدخول.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 13,
                    color: Colors.white60,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D1B69),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('حسناً',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
     if (_freezeType == 'password') {
  // ننتقل لصفحة إعادة الضبط ونخبرها أننا قادمون من "تجميد"
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => const ResetPasswordScreen(isFromFrozen: true),
    ),
    (route) => false,
  );
} else {
  // الحالة العادية (تجميد إيميل مثلاً) يروح للوجن
  navigatorKey.currentState?.pushNamedAndRemoveUntil(
    '/login',
    (r) => false,
  );
}
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'حدث خطأ',
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0A1E),
        body: Stack(
          children: [
            Positioned(
              top: -80, right: -80,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.shade900.withOpacity(0.15),
                ),
              ),
            ),
            Positioned(
              bottom: -60, left: -60,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2D1B69).withOpacity(0.4),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.shade900.withOpacity(0.2),
                            border: Border.all(color: Colors.red.shade700.withOpacity(0.5), width: 1.5),
                          ),
                          child: Icon(Icons.lock_outlined, color: Colors.red.shade400, size: 46),
                        ),
                        const SizedBox(height: 28),
                        const Text('تم تجميد حسابك',
                            style: TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            )),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.shade800.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 20),
                              const SizedBox(width: 10),
                               Expanded(
                                child: Text(
                                _freezeType == 'password'
                                  ? 'تم رصد تغيير في كلمة مرورك.\nأدخل بريدك الإلكتروني ورمز فك التجميد.'
                                  : 'تم رصد نشاط مشبوه على حسابك.\nأدخل بريدك القديم ورمز فك التجميد.',
                                  style: TextStyle(
                                    fontFamily: 'IBMPlexSansArabic',
                                    fontSize: 13,
                                    color: Colors.red,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        _buildField(
                          controller: _emailController,
                         label: _freezeType == 'password' ? 'بريدك الإلكتروني' : 'بريدك الإلكتروني القديم',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _codeController,
                          label: 'رمز فك التجميد',
                          icon: Icons.vpn_key_outlined,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          isCode: true,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _unfreeze,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _loading
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.lock_open_outlined, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('فك التجميد',
                                          style: TextStyle(
                                            fontFamily: 'IBMPlexSansArabic',
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          )),
                                    ],
                                  ),
                          ),
                        ),
                      ],
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool isCode = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      textAlign: isCode ? TextAlign.center : TextAlign.right,
      style: TextStyle(
        fontFamily: 'IBMPlexSansArabic',
        color: Colors.white,
        fontSize: isCode ? 22 : 15,
        letterSpacing: isCode ? 8 : 0,
        fontWeight: isCode ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic', color: Colors.white38, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white30, size: 20),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade700, width: 1.5)),
      ),
    );
  }
}