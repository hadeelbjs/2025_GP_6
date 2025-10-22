import 'package:flutter/material.dart';
class MessageDialog extends StatelessWidget {
  final String message;
  final bool isError;

  const MessageDialog({
    Key? key,
    required this.message,
    required this.isError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
      title: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? const Color.fromARGB(255, 31, 3, 103) : const Color.fromARGB(255, 122, 78, 235),
          ),
          const SizedBox(width: 8),
          Text(
            isError ? 'خطأ' : 'نجاح',
            style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'حسنًا',
            style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
        ),
      ],
    )
    )
    ;
  }
}