import 'package:flutter/services.dart';

class ArabicToEnglishDigitsFormatter extends TextInputFormatter {
  static const arabic = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  static const english = ['0','1','2','3','4','5','6','7','8','9'];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String converted = newValue.text.replaceAllMapped(
      RegExp(r'[٠-٩]'),
      (match) => english[arabic.indexOf(match.group(0)!)],
    );
    return newValue.copyWith(text: converted);
  }
}
