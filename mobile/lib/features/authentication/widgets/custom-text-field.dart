import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String label;              // عنوان الحقل فوقه
  final String hint;               // النص داخل الحقل
  final IconData? icon;            // الأيقونة (اختياري)
  final bool isPassword;           // هل هو كلمة مرور؟
  final TextEditingController? controller;  // للتحكم بالنص
  final String? Function(String?)? validator; // للتحقق
  final bool enabled;              // ✅ هل الحقل مفعّل؟
  final bool? obscureText; 
  final Widget? suffixIcon;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    this.icon,
    this.isPassword = false,
    this.obscureText,    
    this.suffixIcon,
    this.controller,
    this.validator,
    this.enabled = true,  // ✅ افتراضياً مفعّل
  });

  @override
  Widget build(BuildContext context) {
    final hintTextStyle = TextStyle(
      fontSize: 14,
      fontFamily: 'IBMPlexSansArabic',
      fontWeight: FontWeight.w400,
      color: enabled 
          ? const Color.fromARGB(255, 126, 126, 126)  //  لون عادي
          : const Color.fromARGB(255, 180, 180, 180), //  لون باهت للمعطّل
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // النص فوق الحقل
        Text(
          label,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'IBMPlexSansArabic',
            color: enabled 
                ? Colors.black87           // لون عادي
                : Colors.black38,          // لون باهت للمعطّل
          ),
        ),
        const SizedBox(height: 8),
        
        // حقل الإدخال
        TextFormField(
          controller: controller,
           obscureText: obscureText ?? isPassword,
          validator: validator,
          enabled: enabled,  // هنا نفعّل أو نعطّل
          textDirection: TextDirection.rtl,  
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: hintTextStyle,
            prefixIcon: icon != null 
                ? Icon(
                    icon,
                    color: enabled 
                        ? hintTextStyle.color  // لون عادي
                        : Colors.grey[400],    // لون باهت للمعطّل
                  )
                : null,
                suffixIcon: suffixIcon,
            
            // الإطار العادي
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            
            // الإطار العادي (مو مفعّل)
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            
            // الإطار لما تضغط عليه
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            
            // الإطار لما في خطأ
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            
            // الإطار لما في خطأ + تضغط عليه
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            
            // الإطار لما معطّل
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            
            filled: true,
            fillColor: enabled 
                ? const Color.fromARGB(255, 255, 255, 255)  // خلفية بيضاء
                : const Color.fromARGB(255, 245, 245, 245), // خلفية رمادية فاتحة للمعطّل
          ),
        ),
      ],
    );
  }
}