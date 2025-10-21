import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/api_services.dart';
import '/shared/widgets/header_widget.dart';
import '/shared/widgets/bottom_nav_bar.dart';
import '../../../services/biometric_service.dart';
import '../../../services/crypto/signal_protocol_manager.dart';
class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final _apiService = ApiService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  // قائمة الـ Memojis
  final List<String> _memojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '😚',
    '😙',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '🤨',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '🤥',
    '😌',
    '😔',
    '😪',
    '🤤',
    '😴',
    '😷',
    '🤒',
    '🤕',
    '🤢',
    '🤮',
    '🤧',
    '🥵',
    '🥶',
    '🥴',
    '😵',
    '🤯',
    '🤠',
    '🥳',
    '😎',
    '🤓',
    '🧐',
    '😕',
    '😟',
    '🙁',
    '☹️',
    '😮',
    '😯',
    '😲',
    '😳',
    '🥺',
    '😦',
    '😧',
    '😨',
    '😰',
    '😥',
    '😢',
    '😭',
    '😱',
    '😖',
    '😣',
    '😞',
    '😓',
    '😩',
    '😫',
    '🥱',
    '😤',
    '😡',
    '😠',
    '🤬',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _apiService.getUserData();

      if (!mounted) return;

      if (data == null) {
        _handleSessionExpired();
        return;
      }

      setState(() {
        _userData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage('خطأ في تحميل بيانات الحساب', false);
    }
  }

  void _handleSessionExpired() {
    _showMessage('انتهت صلاحية الجلسة، الرجاء تسجيل الدخول مرة أخرى', false);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const HeaderWidget(
                title: 'إدارة الحساب',
                showBackground: true,
                alignTitleRight: true,
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            _buildProfileCard(),
                            const SizedBox(height: 20),
                            _buildSecuritySettings(),
                            _buildEditOptions(),
                            const SizedBox(height: 20),
                            _buildLogoutButton(context),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
              ),
              const BottomNavBar(currentIndex: 4),
            ],
          ),
        ),
      ),
    );
  }

  /**Widget _buildProfileCard() {
    final fullName = _userData?['fullName'] ?? 'المستخدم';
    final email = _userData?['email'] ?? 'example@email.com';
    final username = _userData?['username'] ?? '';
    final memoji = _userData?['memoji'] ?? '😊';

    return Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF6B5B95),
            Color(0xFF2D1B69),
          ],
        ),
        borderRadius: BorderRadius.circular(45),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D1B69).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // خلفية زخرفية
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            right: -50,
            bottom: -50,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
          
          // المحتوى
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // الصورة الرمزية
                GestureDetector(
                  onTap: _showMemojiPicker,
                  child: Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Container(
                            color: const Color(0xFF2D1B69),
                            child: Center(
                              child: Text(
                                memoji,
                                style: const TextStyle(fontSize: 40),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B7AB8), Color(0xFF6B5B95)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // معلومات المستخدم
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (username.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '@$username',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // من عائلة وصيد مع اللوقو
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                
                                
                                const SizedBox(width: 6),
                                Text(
                                  '  من عائلة وصيد',
                                  style: TextStyle(
                                    fontFamily: 'IBMPlexSansArabic',
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w500,

                                  ),
                                ),
                                const SizedBox(width: 6),
                                SvgPicture.asset(
                              'assets/images/logo-white.svg',
                              width: 28,
                              height: 28,
                            ),
                              ],

                            ),
                          ),
                          const SizedBox(width: 10),
                          
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }**/
  Widget _buildProfileCard() {
    final fullName = _userData?['fullName'] ?? 'المستخدم';
    final username = _userData?['username'] ?? '';
    // حرف أول ثابت بدل الإيموجي
    final String initial = fullName.trim().isNotEmpty
        ? fullName.trim()[0].toUpperCase()
        : '؟';

    return Container(
      // حجم أصغر للكارد
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF6B5B95), Color(0xFF2D1B69)],
        ),
        borderRadius: BorderRadius.circular(24), // كان 45
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D1B69).withOpacity(0.20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // زخارف أصغر
          Positioned(
            left: -20,
            top: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),

          // المحتوى – مضغوط
          Padding(
            padding: const EdgeInsets.all(16), // كان 24
            child: Row(
              children: [
                // أفاتار بحرف ثابت (بدون onTap وبدون زر تعديل)
                Container(
                  width: 56, // كان 80
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Container(
                      color: const Color(0xFF2D1B69),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 24, // كان 40
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14), // كان 20
                // معلومات المستخدم (مقاسات أصغر)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 20, // كان 24
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (username.isNotEmpty) ...[
                        const SizedBox(height: 4), // كان 6
                        Text(
                          '@$username',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 13, // كان 16
                            color: Colors.white.withOpacity(0.85),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8), // كان 12
                      // من عائلة وصيد + اللوجو (تصغير بسيط)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'من عائلة وصيد',
                            style: TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              fontSize: 12, // كان 13
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            'assets/images/logo-white.svg',
                            width: 22, // كان 28
                            height: 22,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditOptions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEditTile(
            icon: Icons.person_outline,
            title: 'تعديل اسم المستخدم',
            subtitle: '@${_userData?['username'] ?? ''}',
            onTap: _showEditUsernameDialog,
          ),
          _buildDivider(),
          _buildEditTile(
            icon: Icons.email_outlined,
            title: 'تعديل البريد الإلكتروني',
            subtitle: _userData?['email'] ?? '',
            onTap: _showEditEmailDialog,
            verified: _userData?['isEmailVerified'] ?? false,
          ),
          _buildDivider(),
          _buildEditTile(
            icon: Icons.phone_outlined,
            title: 'تعديل رقم الهاتف',
            subtitle: _userData?['phone'] ?? '',
            onTap: _showEditPhoneDialog,
            verified: _userData?['isPhoneVerified'] ?? false,
          ),
          _buildDivider(),
          _buildEditTile(
            icon: Icons.lock_outline,
            title: 'تغيير كلمة المرور',
            subtitle: '••••••••',
            onTap: _showChangePasswordDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildEditTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool verified = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (verified)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'مؤكد',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.arrow_back_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
      indent: 70,
    );
  }

  // ============= Memoji Picker =============
  void _showMemojiPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'اختر صورة رمزية',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _memojis.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        _updateMemoji(_memojis[index]);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            _memojis[index],
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateMemoji(String memoji) async {
    setState(() => _isLoading = true);

    final result = await _apiService.updateMemoji(memoji);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _userData?['memoji'] = memoji;
      });
      _showMessage('تم تحديث الصورة الرمزية بنجاح', true);
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', false);
    }
  }

  // ============= Edit Username =============
  void _showEditUsernameDialog() {
    final controller = TextEditingController(
      text: _userData?['username'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'تعديل اسم المستخدم',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'اسم المستخدم الجديد',
              labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: AppColors.textHint,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateUsername(controller.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'حفظ',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUsername(String username) async {
    if (username.isEmpty || username.length < 3) {
      _showMessage('اسم المستخدم يجب أن يكون 3 أحرف على الأقل', false);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.updateUsername(username);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _userData?['username'] = username;
      });
      _showMessage('تم تحديث اسم المستخدم بنجاح', true);
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', false);
    }
  }

  // ============= Edit Email =============
  void _showEditEmailDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'تعديل البريد الإلكتروني',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سيتم إرسال رمز تحقق إلى البريد الإلكتروني الجديد',
                style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني الجديد',
                  labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: AppColors.textHint,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _requestEmailChange(controller.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'إرسال رمز التحقق',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestEmailChange(String newEmail) async {
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      _showMessage('الرجاء إدخال بريد إلكتروني صالح', false);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.requestEmailChange(newEmail);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      _showMessage('تم إرسال رمز التحقق', true);
      _showVerifyEmailChangeDialog(newEmail);
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', false);
    }
  }

  void _showVerifyEmailChangeDialog(String newEmail) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'أدخل رمز التحقق',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تم إرسال رمز التحقق إلى $newEmail',
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'رمز التحقق',
                  labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key),
                ),
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: AppColors.textHint,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _verifyEmailChange(newEmail, controller.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'تأكيد',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyEmailChange(String newEmail, String code) async {
    if (code.length != 6) {
      _showMessage('الرجاء إدخال رمز التحقق كاملاً', false);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.verifyEmailChange(newEmail, code);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _userData?['email'] = newEmail;
        _userData?['isEmailVerified'] = true;
      });
      _showMessage('تم تحديث البريد الإلكتروني بنجاح', true);
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', false);
    }
  }

  // ============= Edit Phone =============
  void _showEditPhoneDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'تعديل رقم الهاتف',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سيتم إرسال رمز تحقق عبر SMS إلى الرقم الجديد',
                style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف الجديد',
                  labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                  hintText: '+966551234567',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: AppColors.textHint,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _requestPhoneChange(controller.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'إرسال رمز التحقق',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPhoneChange(String newPhone) async {
    if (newPhone.isEmpty || !newPhone.startsWith('+')) {
      _showMessage('الرجاء إدخال رقم هاتف صالح مع كود الدولة', false);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.requestPhoneChange(newPhone);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      _showMessage('تم إرسال رمز التحقق', true);
      _showVerifyPhoneChangeDialog(newPhone);
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', false);
    }
  }

  void _showVerifyPhoneChangeDialog(String newPhone) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'أدخل رمز التحقق',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تم إرسال رمز التحقق إلى $newPhone',
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'رمز التحقق',
                  labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key),
                ),
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: AppColors.textHint,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _verifyPhoneChange(newPhone, controller.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'تأكيد',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyPhoneChange(String newPhone, String code) async {
    if (code.length != 6) {
      _showMessage('الرجاء إدخال رمز التحقق كاملاً', false);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.verifyPhoneChange(newPhone, code);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _userData?['phone'] = newPhone;
        _userData?['isPhoneVerified'] = true;
      });
      _showMessage('تم تحديث رقم الهاتف بنجاح', true);
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', false);
    }
  }

  // ============= Change Password =============
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'تغيير كلمة المرور',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    labelStyle: const TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    labelStyle: const TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    labelStyle: const TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: AppColors.textHint,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  Navigator.pop(context);
                  _showMessage('كلمة المرور غير متطابقة', false);
                  return;
                }
                Navigator.pop(context);
                _changePassword(
                  currentPasswordController.text,
                  newPasswordController.text,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'تغيير',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (newPassword.length < 6) {
      _showMessage('كلمة المرور يجب أن تكون 6 أحرف على الأقل', false);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.changePassword(
      currentPassword,
      newPassword,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      _showMessage('تم تغيير كلمة المرور بنجاح', true);
    } else {
      _showMessage(result['message'] ?? 'حدث خطأ', false);
    }
  }

  Widget _buildSecuritySettings() {
  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
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
        const Text(
          'الأمان',
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D1B69),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<bool>(
          future: BiometricService.isBiometricEnabled(),
          builder: (context, snapshot) {
            final isEnabled = snapshot.data ?? false;

            return ListTile(
              leading: Icon(
                Icons.fingerprint,
                color: isEnabled ? const Color(0xFF2D1B69) : Colors.grey,
              ),
              title: const Text(
                'المصادقة الحيوية',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                isEnabled ? 'مفعلة - دخول سريع' : 'غير مفعلة',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: isEnabled ? Colors.green : Colors.grey,
                ),
              ),
              trailing: Switch(
                value: isEnabled,
                onChanged: (value) async {
                  await _toggleBiometric(value);
                  // ✅ تحديث الـ widget بالكامل بعد انتهاء العملية
                  if (mounted) {
                    setState(() {});
                  }
                },
                activeColor: const Color(0xFF2D1B69),
              ),
            );
          },
        ),
      ],
    ),
  );
}

Future<void> _toggleBiometric(bool enable) async {
  if (enable) {
    // تفعيل البايومتركس
    final isSupported = await BiometricService.isDeviceSupported();
    final canUse = await BiometricService.canCheckBiometrics();

    if (!canUse) {
      if (mounted) {
        _showMessage('البصمة غير متاحة على هذا الجهاز', false);
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    final result = await _apiService.requestBiometricEnable();
    if (mounted) setState(() => _isLoading = false);

    if (!mounted) return;

    if (!result['success']) {
      _showMessage(result['message'] ?? 'فشل في الإرسال', false);
      return;
    }

    _showMessage('تم إرسال رمز التحقق لبريدك', true);
    _showBiometricVerificationDialog();
  } else {
    // إلغاء البايومتركس
    final success = await BiometricService.authenticateWithBiometrics(
      reason: 'تأكيد إلغاء المصادقة الحيوية',
    );

    if (!success) {
      if (mounted) {
        _showMessage('فشل التحقق من الهوية', false);
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    final result = await _apiService.disableBiometric();
    if (mounted) setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      await BiometricService.disableBiometric();
      _showMessage('تم إلغاء المصادقة الحيوية بنجاح', true);
    } else {
      _showMessage(result['message'] ?? 'فشل الإلغاء', false);
    }
  }
}

void _showBiometricVerificationDialog() {
  final controller = TextEditingController();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'تأكيد تفعيل المصادقة الحيوية',
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل رمز التحقق المرسل لبريدك الإلكتروني',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 24,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                labelText: 'رمز التحقق',
                labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.length != 6) {
                if (mounted) {
                  _showMessage('أدخل الرمز كاملاً (6 أرقام)', false);
                }
                return;
              }

              Navigator.pop(context);

              if (mounted) setState(() => _isLoading = true);
              final result = await _apiService.verifyBiometricEnable(code);
              if (mounted) setState(() => _isLoading = false);

              if (!mounted) return;

              if (!result['success']) {
                _showMessage(result['message'] ?? 'الرمز غير صحيح', false);
                return;
              }

              final userData = await _apiService.getUserData();
              if (userData == null) {
                if (mounted) {
                  _showMessage('حدث خطأ في جلب بيانات المستخدم', false);
                }
                return;
              }

              final biometricSuccess = await BiometricService.enableBiometric(
                userData['email'],
              );

              if (!mounted) return;

              if (biometricSuccess) {
                _showMessage('تم تفعيل المصادقة الحيوية بنجاح', true);
                setState(() {});
              } else {
                _showMessage('فشل في حفظ البصمة', false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D1B69),
            ),
            child: const Text(
              'تأكيد',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  
  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout, size: 20),
        label: const Text(
          'تسجيل الخروج',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'IBMPlexSansArabic',
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'تأكيد تسجيل الخروج',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    color: AppColors.textHint,
                    fontSize: 15,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleLogout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    // علامة إنك للتو سويتي logout
    await BiometricService.setJustLoggedOut(true);

    await _apiService.logout();

    if (!mounted) return;

    _showMessage('تم تسجيل الخروج بنجاح', true);

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _showMessage(String message, [bool isSuccess = false]) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          textAlign: TextAlign.center,
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
