import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/contact/screens/contacts_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ContactsListScreen(),
    );
  }
}
