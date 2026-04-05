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
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _codeController  = TextEditingController();
  final _api             = ApiService();
  bool   _loading        = false;
  String _freezeType     = 'email';

  late AnimationController _entranceCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _pulseAnim;

  static const _bg         = Color(0xFFFCF9F9);
  static const _surface    = Colors.white;
  static const _surfaceAlt = Color(0xFFF5F3F8);
  static const _red        = Color(0xFFB03030);
  static const _redLight   = Color(0xFFFDF0F0);
  static const _brand      = Color(0xFF2D1B69);
  static const _textPri    = Color(0xFF1A0A0A);
  static const _textSec    = Color(0xFF5A5060);
  static const _textMuted  = Color(0xFFA09AAD);
  static const _textOnBtn  = Colors.white;
  // ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850));
    _fadeAnim  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entranceCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) _freezeType = args['type'] ?? 'email';
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // ── Unfreeze ───────────────────────────────────────────────
  Future<void> _unfreeze() async {
    if (_emailController.text.isEmpty || _codeController.text.length != 6) {
      _snack('الرجاء إدخال البريد والرمز كاملاً', isError: false);
      return;
    }
    setState(() => _loading = true);
    final result = await _api.unfreezeAccount(
      email: _emailController.text.trim(),
      code:  _codeController.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      await _showSuccessDialog();
      if (!mounted) return;
      if (_freezeType == 'password') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => const ResetPasswordScreen(isFromFrozen: true)),
          (r) => false,
        );
      } else {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);
      }
    } else {
      _snack(result['message'] ?? 'حدث خطأ', isError: true);
    }
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic', color: _textOnBtn)),
      backgroundColor: isError ? _red : _brand,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: _surface,
              border: Border.all(color: Colors.green.shade200, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade50,
                    border: Border.all(
                        color: Colors.green.shade300, width: 1.5),
                  ),
                  child: Icon(Icons.lock_open_rounded,
                      color: Colors.green.shade600, size: 36),
                ),
                const SizedBox(height: 20),
                const Text('تم فك التجميد بنجاح',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPri,
                    )),
                const SizedBox(height: 10),
                Text(
                  _freezeType == 'password'
                      ? 'تم فك التجميد.\nيرجى الآن تغيير كلمة المرور\nلكي تتمكن من تسجيل الدخول.'
                      : 'حسابك الآن آمن.\nيمكنك تسجيل الدخول.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 13,
                    color: _textSec,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('حسناً',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          color: _textOnBtn,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height),
              painter: _TrianglePainter(),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildIcon(),
                        const SizedBox(height: 22),
                        _buildTitles(),
                        const SizedBox(height: 18),
                        _buildWarningBanner(),
                        const SizedBox(height: 22),
                        _buildCard(),
                        const SizedBox(height: 16),
                        _buildButton(),
                        const SizedBox(height: 20),
                        _buildFootnote(),
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

  Widget _buildIcon() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: _pulseAnim.value,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: _red.withOpacity(0.2), width: 1.5),
              ),
            ),
          ),
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _redLight,
              border: Border.all(color: _red.withOpacity(0.4), width: 1.5),
            ),
            child: const Icon(Icons.lock_outlined, color: _red, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildTitles() {
    return Column(
      children: [
        const Text('تم تجميد حسابك',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: _textPri,
            )),
        const SizedBox(height: 7),
        Text(
          _freezeType == 'password'
              ? 'تم رصد تغيير مشبوه في كلمة مرورك'
              : 'تم رصد نشاط غير معتاد على حسابك',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 13,
            color: _textSec,
            height: 1.5,
          ),
        ),
      ],
    );
  }

Widget _buildWarningBanner() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: _red.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _red.withOpacity(0.2), width: 1),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _red.withOpacity(0.08),
          ),
          child: const Icon(Icons.warning_amber_rounded, color: _red, size: 18),
        ),
        Expanded(
          child: Text(
            _freezeType == 'password'
                ? 'أدخل بريدك الإلكتروني ورمز فك التجميد المُرسل إليك لاستعادة حسابك.'
                : 'أدخل بريدك الإلكتروني القديم ورمز فك التجميد المُرسل إليك لاستعادة حسابك.',
            textAlign: TextAlign.right,   
            style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12.5,
              color: _red,
              height: 1.65,
            ),
          ),
        ),
        const SizedBox(width: 10),
       
      ],
    ),
  );
}

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          _buildField(
            controller: _emailController,
            label: _freezeType == 'password'
                ? 'بريدك الإلكتروني'
                : 'بريدك الإلكتروني القديم',
            hint: 'example@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _codeController,
            label: 'رمز فك التجميد',
            hint: '• • • • • •',
            icon: Icons.tag_rounded,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            isCode: true,
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : _unfreeze,
        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          disabledBackgroundColor: _surfaceAlt,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: _textOnBtn, strokeWidth: 2.5))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('فك التجميد',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 16,
                        color: _textOnBtn,
                        fontWeight: FontWeight.bold,
                      )),
                  SizedBox(width: 10),
                  Icon(Icons.lock_open_rounded,
                      color: _textOnBtn, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildFootnote() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline_rounded, size: 13, color: _textMuted),
        SizedBox(width: 5),
        Text(
          'إذا لم تتلقَّ الرمز، تحقق من مجلد البريد غير المرغوب فيه',

          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 11.5,
            color: _textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool isCode = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12.5,
              color: _textSec,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          textAlign: isCode ? TextAlign.center : TextAlign.right,
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            color: _textPri,
            fontSize: isCode ? 22 : 14,
            letterSpacing: isCode ? 10.0 : 0,
            fontWeight: isCode ? FontWeight.bold : FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              color: _textMuted.withOpacity(0.7),
              fontSize: isCode ? 18 : 13,
              letterSpacing: isCode ? 8.0 : 0,
            ),
            suffixIcon:
                isCode ? null : Icon(icon, color: _textMuted, size: 18),
            counterText: '',
            filled: true,
            fillColor: _surfaceAlt,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.black.withOpacity(0.07)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.black.withOpacity(0.07)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void tri(List<Offset> pts, Color color) {
      canvas.drawPath(
        Path()..addPolygon(pts, true),
        Paint()..color = color,
      );
    }

    tri([Offset(w, 0), Offset(w * 0.42, 0), Offset(w, h * 0.24)],
        const Color(0xFFB03030).withOpacity(0.09));
    tri([Offset(w, 0), Offset(w * 0.65, 0), Offset(w, h * 0.12)],
        const Color(0xFFB03030).withOpacity(0.06));
    tri([Offset(0, 0), Offset(w * 0.22, 0), Offset(0, h * 0.14)],
        const Color(0xFFB03030).withOpacity(0.04));

    tri([Offset(0, h), Offset(0, h * 0.65), Offset(w * 0.60, h)],
        const Color(0xFF2D1B69).withOpacity(0.12));
    tri([Offset(0, h), Offset(0, h * 0.80), Offset(w * 0.34, h)],
        const Color(0xFF2D1B69).withOpacity(0.08));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}