/*import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  double _passwordLength = 8;
  String _generatedPassword = '';
  String? _errorMessage;

  final String upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final String lowerCase = 'abcdefghijklmnopqrstuvwxyz';
  final String numbers = '0123456789';
  final String symbols = '!@#\$%^&*()-_=+[]{};:,.<>?';

  String _generateStrongPassword(int length) {
    if (length < 8 || length > 32) {
      throw Exception('Password length out of range');
    }

    final random = Random.secure();
    final allChars = upperCase + lowerCase + numbers + symbols;

    List<String> passwordChars = [
      upperCase[random.nextInt(upperCase.length)],
      lowerCase[random.nextInt(lowerCase.length)],
      numbers[random.nextInt(numbers.length)],
      symbols[random.nextInt(symbols.length)],
    ];

    for (int i = passwordChars.length; i < length; i++) {
      passwordChars.add(allChars[random.nextInt(allChars.length)]);
    }

    passwordChars.shuffle(random);
    return passwordChars.join();
  }

  void _handleGeneratePassword() {
    try {
      final password = _generateStrongPassword(_passwordLength.toInt());

      setState(() {
        _generatedPassword = password;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _generatedPassword = '';
        _errorMessage = 'تعذر إنشاء كلمة المرور. حاول مرة أخرى.';
      });
    }
  }

  Future<void> _copyPassword() async {
    if (_generatedPassword.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: _generatedPassword));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ كلمة المرور',
          style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
        ),
      ),
    );
  }

  String _getPasswordStrength() {
    if (_generatedPassword.isEmpty) return '';

    int score = 0;

    if (_generatedPassword.length >= 8) score++;
    if (_generatedPassword.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(_generatedPassword)) score++;
    if (RegExp(r'[a-z]').hasMatch(_generatedPassword)) score++;
    if (RegExp(r'[0-9]').hasMatch(_generatedPassword)) score++;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(_generatedPassword)) score++;

    if (score <= 3) return 'ضعيفة';
    if (score <= 5) return 'متوسطة';
    return 'قوية';
  }

  Color _getStrengthColor() {
    final strength = _getPasswordStrength();

    if (strength == 'ضعيفة') return Colors.red;
    if (strength == 'متوسطة') return Colors.orange;
    if (strength == 'قوية') return Colors.green;

    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'مولّد كلمات المرور',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أنشئ كلمة مرور قوية وآمنة بسهولة:',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'حدد طول كلمة المرور:',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'IBMPlexSansArabic',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Text(
                            _passwordLength.toInt().toString(),
                            style: const TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: Colors.grey.shade300,
                                  thumbColor: AppColors.primary,
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: _passwordLength,
                                  min: 8,
                                  max: 32,
                                  divisions: 24,
                                  onChanged: (value) {
                                    setState(() {
                                      _passwordLength = value;
                                    });
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text(
                                      '8',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontFamily: 'IBMPlexSansArabic',
                                      ),
                                    ),
                                    Text(
                                      '32',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontFamily: 'IBMPlexSansArabic',
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
                    const SizedBox(height: 26),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _handleGeneratePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'أنشئ الكلمة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_generatedPassword.isNotEmpty)
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'مؤشر قوة كلمة المرور',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStrengthColor().withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStrengthColor().withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              _getPasswordStrength(),
                              style: TextStyle(
                                color: _getStrengthColor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_generatedPassword.isNotEmpty)
                      const SizedBox(height: 18),
                    const Text(
                      'كلمة المرور المنشأة',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F7FC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          if (_generatedPassword.isNotEmpty)
                            InkWell(
                              onTap: _copyPassword,
                              child: Icon(
                                Icons.copy_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                          if (_generatedPassword.isNotEmpty)
                            const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _generatedPassword,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFCACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleGeneratePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'إعادة المحاولة',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}*/

/*import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  double _passwordLength = 8;
  String _generatedPassword = '';
  String? _errorMessage;

  bool _useMemorableMode = false;
  final TextEditingController _baseTextController = TextEditingController();

  final String upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final String lowerCase = 'abcdefghijklmnopqrstuvwxyz';
  final String numbers = '0123456789';
  final String symbols = '!@#\$%^&*()-_=+[]{};:,.<>?';

  @override
  void dispose() {
    _baseTextController.dispose();
    super.dispose();
  }

  String _generateStrongPassword(int length) {
    if (length < 8 || length > 32) {
      throw Exception('Password length out of range');
    }

    final random = Random.secure();
    final allChars = upperCase + lowerCase + numbers + symbols;

    List<String> passwordChars = [
      upperCase[random.nextInt(upperCase.length)],
      lowerCase[random.nextInt(lowerCase.length)],
      numbers[random.nextInt(numbers.length)],
      symbols[random.nextInt(symbols.length)],
    ];

    for (int i = passwordChars.length; i < length; i++) {
      passwordChars.add(allChars[random.nextInt(allChars.length)]);
    }

    passwordChars.shuffle(random);
    return passwordChars.join();
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _sanitizeBaseText(String input) {
    return input.replaceAll(RegExp(r'\s+'), '');
  }

  String _generateMemorablePassword(int length, String baseText) {
    final random = Random.secure();

    String cleanBase = _sanitizeBaseText(baseText);

    if (cleanBase.isEmpty) {
      throw Exception('Base text is empty');
    }

    cleanBase =
        cleanBase[0].toUpperCase() + cleanBase.substring(1).toLowerCase();

    final String symbol = symbols[random.nextInt(symbols.length)];
    final String number =
        numbers[random.nextInt(numbers.length)] +
        numbers[random.nextInt(numbers.length)];

    String password = '$cleanBase$symbol$number!';

    while (password.length < length) {
      final choice = random.nextInt(3);

      if (choice == 0) {
        password += lowerCase[random.nextInt(lowerCase.length)];
      } else if (choice == 1) {
        password += numbers[random.nextInt(numbers.length)];
      } else {
        password += symbols[random.nextInt(symbols.length)];
      }
    }

    if (password.length > length) {
      password = password.substring(0, length);
    }

    return password;
  }

  void _handleGeneratePassword() {
    try {
      final int length = _passwordLength.toInt();
      String password;

      if (_useMemorableMode) {
        password = _generateMemorablePassword(
          length,
          _baseTextController.text.trim(),
        );
      } else {
        password = _generateStrongPassword(length);
      }

      setState(() {
        _generatedPassword = password;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _generatedPassword = '';
        _errorMessage = _useMemorableMode
            ? 'تعذر إنشاء كلمة المرور. تأكد من إدخال نص أساسي مناسب ثم حاول مرة أخرى.'
            : 'تعذر إنشاء كلمة المرور. حاول مرة أخرى.';
      });
    }
  }

  Future<void> _copyPassword() async {
    if (_generatedPassword.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: _generatedPassword));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ كلمة المرور',
          style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
        ),
      ),
    );
  }

  String _getPasswordStrength() {
    if (_generatedPassword.isEmpty) return '';

    int score = 0;

    if (_generatedPassword.length >= 8) score++;
    if (_generatedPassword.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(_generatedPassword)) score++;
    if (RegExp(r'[a-z]').hasMatch(_generatedPassword)) score++;
    if (RegExp(r'[0-9]').hasMatch(_generatedPassword)) score++;
    if (RegExp(
      r'[!@#\$%^&*()\-\_=+\[\]{};:,.<>?]',
    ).hasMatch(_generatedPassword)) {
      score++;
    }

    if (score <= 3) return 'ضعيفة';
    if (score <= 5) return 'متوسطة';
    return 'قوية';
  }

  Color _getStrengthColor() {
    final strength = _getPasswordStrength();

    if (strength == 'ضعيفة') return Colors.red;
    if (strength == 'متوسطة') return Colors.orange;
    if (strength == 'قوية') return Colors.green;

    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'مولّد كلمات المرور',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أنشئ كلمة مرور قوية وآمنة بسهولة:',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'حدد طول كلمة المرور:',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'IBMPlexSansArabic',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Text(
                            _passwordLength.toInt().toString(),
                            style: const TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: Colors.grey.shade300,
                                  thumbColor: AppColors.primary,
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: _passwordLength,
                                  min: 8,
                                  max: 32,
                                  divisions: 24,
                                  onChanged: (value) {
                                    setState(() {
                                      _passwordLength = value;
                                    });
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text(
                                      '8',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontFamily: 'IBMPlexSansArabic',
                                      ),
                                    ),
                                    Text(
                                      '32',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontFamily: 'IBMPlexSansArabic',
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

                    const SizedBox(height: 18),

                    SwitchListTile(
                      value: _useMemorableMode,
                      onChanged: (value) {
                        setState(() {
                          _useMemorableMode = value;
                          _errorMessage = null;
                        });
                      },
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'إنشاء كلمة سهلة التذكر',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      subtitle: const Text(
                        'استخدم نصًا أساسيًا مع تعزيزات أمنية تلقائية',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 12,
                        ),
                      ),
                    ),

                    if (_useMemorableMode) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _baseTextController,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'مثال: Maha أو Waseed أو رقم يسهل حفظه',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9F7FC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'سيتم تعزيز النص تلقائيًا برمز وأرقام وأحرف لزيادة الأمان مع الحفاظ على سهولة التذكر.',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                    ],

                    const SizedBox(height: 26),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _handleGeneratePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'أنشئ الكلمة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_generatedPassword.isNotEmpty)
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'مؤشر قوة كلمة المرور',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStrengthColor().withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStrengthColor().withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              _getPasswordStrength(),
                              style: TextStyle(
                                color: _getStrengthColor(),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'IBMPlexSansArabic',
                              ),
                            ),
                          ),
                        ],
                      ),

                    if (_generatedPassword.isNotEmpty)
                      const SizedBox(height: 18),

                    const Text(
                      'كلمة المرور المنشأة',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F7FC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          if (_generatedPassword.isNotEmpty)
                            InkWell(
                              onTap: _copyPassword,
                              child: Icon(
                                Icons.copy_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                          if (_generatedPassword.isNotEmpty)
                            const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _generatedPassword,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFCACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleGeneratePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'إعادة المحاولة',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}*/

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  double _passwordLength = 8;
  String _generatedPassword = '';
  String? _errorMessage;
  List<String> _generatedOptions = [];

  bool _useMemorableMode = false;
  final TextEditingController _baseTextController = TextEditingController();

  final String upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final String lowerCase = 'abcdefghijklmnopqrstuvwxyz';
  final String numbers = '0123456789';
  final String symbols = '!@#\$%^&*()-_=+[]{};:,.<>?';

  @override
  void dispose() {
    _baseTextController.dispose();
    super.dispose();
  }

  String _generateStrongPassword(int length) {
    if (length < 8 || length > 32) {
      throw Exception('Password length out of range');
    }

    final random = Random.secure();
    final allChars = upperCase + lowerCase + numbers + symbols;

    List<String> passwordChars = [
      upperCase[random.nextInt(upperCase.length)],
      lowerCase[random.nextInt(lowerCase.length)],
      numbers[random.nextInt(numbers.length)],
      symbols[random.nextInt(symbols.length)],
    ];

    for (int i = passwordChars.length; i < length; i++) {
      passwordChars.add(allChars[random.nextInt(allChars.length)]);
    }

    passwordChars.shuffle(random);
    return passwordChars.join();
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _sanitizeBaseText(String input) {
    return input.replaceAll(RegExp(r'\s+'), '');
  }

  String _generateMemorablePassword(int length, String baseText) {
    if (length < 8 || length > 32) {
      throw Exception('Password length out of range');
    }

    final random = Random.secure();
    String cleanBase = _sanitizeBaseText(baseText);

    if (cleanBase.isEmpty) {
      throw Exception('Base text is empty');
    }

    cleanBase = cleanBase.replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF]'), '');

    if (cleanBase.isEmpty) {
      throw Exception('Base text is invalid');
    }

    cleanBase = _capitalizeFirst(cleanBase);

    final String symbol = symbols[random.nextInt(symbols.length)];
    final String number =
        numbers[random.nextInt(numbers.length)] +
        numbers[random.nextInt(numbers.length)];

    String password = '$cleanBase$symbol$number!';

    while (password.length < length) {
      final choice = random.nextInt(3);
      if (choice == 0) {
        password += lowerCase[random.nextInt(lowerCase.length)];
      } else if (choice == 1) {
        password += numbers[random.nextInt(numbers.length)];
      } else {
        password += symbols[random.nextInt(symbols.length)];
      }
    }

    if (password.length > length) {
      password = password.substring(0, length);
    }

    return password;
  }

  void _handleGeneratePassword() {
    try {
      final int length = _passwordLength.toInt();
      final List<String> options = [];

      for (int i = 0; i < 3; i++) {
        if (_useMemorableMode) {
          options.add(
            _generateMemorablePassword(length, _baseTextController.text.trim()),
          );
        } else {
          options.add(_generateStrongPassword(length));
        }
      }

      setState(() {
        _generatedOptions = options;
        _generatedPassword = options.first;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _generatedOptions = [];
        _generatedPassword = '';
        _errorMessage = _useMemorableMode
            ? 'تعذر إنشاء كلمة المرور. تأكد من إدخال نص مناسب ثم حاول مرة أخرى.'
            : 'تعذر إنشاء كلمة المرور. حاول مرة أخرى.';
      });
    }
  }

  Future<void> _copyPassword() async {
    if (_generatedPassword.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: _generatedPassword));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ كلمة المرور',
          style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
        ),
      ),
    );
  }

  String _getPasswordStrength() {
    if (_generatedPassword.isEmpty) return '';

    int score = 0;

    if (_generatedPassword.length >= 8) score++;
    if (_generatedPassword.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(_generatedPassword)) score++;
    if (RegExp(r'[a-z]').hasMatch(_generatedPassword)) score++;
    if (RegExp(r'[0-9]').hasMatch(_generatedPassword)) score++;
    if (RegExp(
      r'[!@#\$%^&*()\-\_=+\[\]{};:,.<>?]',
    ).hasMatch(_generatedPassword)) {
      score++;
    }

    if (score <= 3) return 'ضعيفة';
    if (score <= 5) return 'متوسطة';
    return 'قوية';
  }

  Color _getStrengthColor() {
    final strength = _getPasswordStrength();

    if (strength == 'ضعيفة') return Colors.red;
    if (strength == 'متوسطة') return Colors.orange;
    if (strength == 'قوية') return Colors.green;

    return Colors.grey;
  }

  Widget _buildGeneratedOptions() {
    if (_generatedOptions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'اختر كلمة المرور المناسبة لك',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ..._generatedOptions.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () {
                setState(() {
                  _generatedPassword = option;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _generatedPassword == option
                      ? AppColors.primary.withOpacity(0.08)
                      : const Color(0xFFF9F7FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _generatedPassword == option
                        ? AppColors.primary
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  option,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _resetGeneratedState() {
    _generatedOptions = [];
    _generatedPassword = '';
    _errorMessage = null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'مولّد كلمات المرور',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أنشئ كلمة مرور قوية وآمنة بسهولة:',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'حدد طول كلمة المرور:',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'IBMPlexSansArabic',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Text(
                            _passwordLength.toInt().toString(),
                            style: const TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: Colors.grey.shade300,
                                  thumbColor: AppColors.primary,
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: _passwordLength,
                                  min: 8,
                                  max: 32,
                                  divisions: 24,
                                  onChanged: (value) {
                                    setState(() {
                                      _passwordLength = value;
                                      _resetGeneratedState();
                                    });
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text(
                                      '8',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontFamily: 'IBMPlexSansArabic',
                                      ),
                                    ),
                                    Text(
                                      '32',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontFamily: 'IBMPlexSansArabic',
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
                    const SizedBox(height: 18),
                    SwitchListTile(
                      value: _useMemorableMode,
                      onChanged: (value) {
                        setState(() {
                          _useMemorableMode = value;
                          _resetGeneratedState();
                        });
                      },
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'إنشاء كلمة سهلة التذكر',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      subtitle: const Text(
                        'استخدم نصًا أساسيًا مع تعزيزات أمنية تلقائية',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_useMemorableMode) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _baseTextController,
                        textDirection: TextDirection.rtl,
                        onChanged: (_) {
                          setState(() {
                            _resetGeneratedState();
                          });
                        },
                        style: const TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'مثال: Maha أو Waseed أو رقم يسهل حفظه',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9F7FC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'سيتم تعزيز النص تلقائيًا برمز وأرقام وأحرف لزيادة الأمان مع الحفاظ على سهولة التذكر.',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _handleGeneratePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'أنشئ الكلمة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_generatedOptions.isNotEmpty) ...[
                      _buildGeneratedOptions(),
                      const SizedBox(height: 10),
                    ],
                    if (_generatedPassword.isNotEmpty)
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'مؤشر قوة كلمة المرور',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStrengthColor().withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStrengthColor().withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              _getPasswordStrength(),
                              style: TextStyle(
                                color: _getStrengthColor(),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'IBMPlexSansArabic',
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_generatedPassword.isNotEmpty)
                      const SizedBox(height: 18),
                    const Text(
                      'كلمة المرور المنشأة',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F7FC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          if (_generatedPassword.isNotEmpty)
                            InkWell(
                              onTap: _copyPassword,
                              child: Icon(
                                Icons.copy_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                          if (_generatedPassword.isNotEmpty)
                            const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _generatedPassword,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFCACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleGeneratePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'إعادة المحاولة',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
