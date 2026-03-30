import 'package:flutter/material.dart';
import 'package:waseed/features/authentication/screens/splash_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_services.dart';

class BreachLookup extends StatefulWidget {
  const BreachLookup({super.key});

  @override
  State<BreachLookup> createState() => _BreachLookupState();
}

class _BreachLookupState extends State<BreachLookup> {
  final ApiService _apiService = new ApiService();
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<String?> _showOTPDialog() async {
    final otpController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'أدخل رمز التحقق',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'IBMPlexSansArabic',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تم إرسال رمز التحقق إلى بريدك الإلكتروني',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '------',
                  hintStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, otpController.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text(
                'تحقق',
                style: TextStyle(
                  color: Color(0xFF2D1B69),
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: appBar(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 5),
                Text(
                  "أدخل عنوان بريدك الإلكتروني للبحث في تسريبات البيانات",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: "example@email.com",
                    hintTextDirection: TextDirection.ltr,
                    labelText: "البريد الإلكتروني",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final email = _emailController.text.trim();

                      if (email.isEmpty) return;

                      setState(() => _isLoading = true);

                      try {
                        // 1- أرسل OTP
                        final sendRes = await _apiService
                            .sendOTPforIdentityVerification(email);
                        if (sendRes['success'] != true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                sendRes['message'] ?? 'فشل إرسال الرمز',
                              ),
                            ),
                          );
                          return;
                        }

                        // 2- اعرض Dialog لإدخال OTP
                        final code = await _showOTPDialog();
                        if (code == null || code.isEmpty) return;

                        // 3- تحقق من OTP
                        final verifyRes = await _apiService
                            .verifyOTPforIdentityVerification(code);
                        if (verifyRes['success'] != true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'رمز التحقق خاطئ أو منتهي الصلاحية',
                              ),
                            ),
                          );
                          return;
                        }

                        // 4- بعد نجاح التحقق فقط، روح للـ HIBP
                        final breaches = await _apiService.checkEmailBreach(
                          email,
                        );

                        if (breaches.isEmpty) {
                          showDialog(
                            context: context,
                            builder: (context) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                backgroundColor: const Color(0xFF2D1B69),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Text(
                                      "بريدك آمن",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'IBMPlexSansArabic',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  "لم يتم العثور على أي تسريبات لهذا البريد الإلكتروني",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'IBMPlexSansArabic',
                                    height: 1.8,
                                    fontSize: 13,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'حسناً',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'IBMPlexSansArabic',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          return;
                        }
                        // 5- اعرض النتائج

                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => Container(
                            height: MediaQuery.of(context).size.height * 0.85,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "نتائج البحث (${breaches.length})",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: "IBMPlexSansArabic",
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: breaches.length,
                                      itemBuilder: (_, index) =>
                                          BreachCard(breach: breaches[index]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'ابحث الآن',
                            style: TextStyle(color: Colors.white),
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

  AppBar appBar() {
    return AppBar(
      title: Text(
        "كشف تسريب بياناتك",
        style: TextStyle(
          color: AppColors.primary,
          fontFamily: "IBMPlexSansArabic",
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: true,
    );
  }
}

class BreachCard extends StatelessWidget {
  final Map<String, dynamic> breach;

  const BreachCard({super.key, required this.breach});

  static const _fontFamily = "IBMPlexSansArabic";
  static const _purple = Color(0xFF6C63FF);
  static const _purpleLight = Color(0xFFEEEDFF);
  static const _purpleDark = Color(0xFF4B44CC);
  static const _grey = Color(0xFF6B7280);
  static const _greyLight = Color(0xFFF3F4F6);
  static const _greyBorder = Color(0xFFE5E7EB);

  String _translateDataClass(String item) {
    const translations = {
      'Bios': 'السيرة الذاتية',
      'Dates of birth': 'تواريخ الميلاد',
      'Email addresses': 'البريد الإلكتروني',
      'Genders': 'الجنس',
      'Geographic locations': 'المواقع الجغرافية',
      'IP addresses': 'عناوين IP',
      'Names': 'الأسماء',
      'Passwords': 'كلمات المرور',
      'Social media profiles': 'حسابات التواصل الاجتماعي',
      'User website URLs': 'روابط المواقع الشخصية',
      'Usernames': 'أسماء المستخدمين',
      'Phone numbers': 'أرقام الهواتف',
      'Physical addresses': 'العناوين الفيزيائية',
      'Credit cards': 'بطاقات الائتمان',
      'Bank account numbers': 'أرقام الحسابات البنكية',
      'Payment histories': 'سجلات الدفع',
      'Personal health data': 'البيانات الصحية',
      'Photos': 'الصور',
      'Private messages': 'الرسائل الخاصة',
      'Security questions and answers': 'أسئلة الأمان',
      'Device information': 'معلومات الجهاز',
      'Browser user agent details': 'بيانات المتصفح',
      'Spoken languages': 'اللغات',
      'Job titles': 'المسميات الوظيفية',
    };
    return translations[item] ?? item;
  }

  List<Map<String, dynamic>> _getAdvice(List dataClasses) {
    final advice = <Map<String, dynamic>>[];

    if (dataClasses.contains('Passwords')) {
      advice.add({
        'icon': Icons.lock_reset_rounded,
        'text': 'غيّر كلمة مرورك فوراً في هذا الموقع وأي موقع يشارك نفس الكلمة',
      });
    }
    if (dataClasses.contains('Email addresses')) {
      advice.add({
        'icon': Icons.mark_email_unread_rounded,
        'text': 'كن حذراً من رسائل التصيد الاحتيالي على بريدك الإلكتروني',
      });
    }
    if (dataClasses.contains('Credit cards') ||
        dataClasses.contains('Bank account numbers')) {
      advice.add({
        'icon': Icons.credit_card_off_rounded,
        'text': 'راجع كشف حسابك البنكي وأبلغ البنك عن أي معاملات مشبوهة',
      });
    }
    if (dataClasses.contains('Phone numbers')) {
      advice.add({
        'icon': Icons.phone_locked_rounded,
        'text': 'احذر من مكالمات أو رسائل SMS مجهولة المصدر',
      });
    }
    if (dataClasses.contains('Security questions and answers')) {
      advice.add({
        'icon': Icons.security_rounded,
        'text': 'غيّر أسئلة الأمان في حساباتك المهمة فوراً',
      });
    }

    advice.add({
      'icon': Icons.verified_user_rounded,
      'text': 'فعّل المصادقة الثنائية (2FA) على حساباتك',
    });
    advice.add({
      'icon': Icons.manage_search_rounded,
      'text': 'راقب حساباتك بانتظام للكشف عن أي نشاط غير معتاد',
    });

    return advice;
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    final n = int.tryParse(number.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final List dataClasses = breach['DataClasses'] ?? [];
    final advice = _getAdvice(dataClasses);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _greyBorder),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── الهيدر ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_purple, _purpleDark],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        breach['LogoPath'] ?? '',
                        width: 44,
                        height: 44,
                        errorBuilder: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: _greyLight,
                          child: const Icon(Icons.language, color: _grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          breach['Name'] ?? '',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: _fontFamily,
                          ),
                        ),
                        Text(
                          breach['Domain'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.75),
                            fontFamily: _fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // عدد الحسابات المخترقة
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatNumber(breach['PwnCount']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: _fontFamily,
                          ),
                        ),
                        const Text(
                          "حساب مخترق",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontFamily: _fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── تاريخ التسريب ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _greyLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: _grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "تاريخ التسريب:  ${breach['BreachDate'] ?? 'غير معروف'}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: _grey,
                            fontFamily: _fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── البيانات المسربة ──
                  const Text(
                    "البيانات المسربة",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: _fontFamily,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: dataClasses.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _purpleLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _translateDataClass(item.toString()),
                          style: const TextStyle(
                            fontSize: 12,
                            color: _purpleDark,
                            fontFamily: _fontFamily,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // ── النصائح ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _greyLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _greyBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _purpleLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                size: 16,
                                color: _purple,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "ماذا تفعل الآن؟",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: _fontFamily,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...advice.map(
                          (tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _purpleLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    tip['icon'] as IconData,
                                    size: 16,
                                    color: _purple,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tip['text']!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontFamily: _fontFamily,
                                      color: _grey,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
