import 'package:flutter/material.dart';
import 'api_services.dart';

class AuthGuard {
  final ApiService _apiService = ApiService();

  // التحقق من تسجيل الدخول
  Future<bool> isAuthenticated() async {
    final token = await _apiService.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // حماية الصفحة - إعادة توجيه إلى Login إذا لم يكن مسجل
  Future<void> checkAuth(BuildContext context) async {
    final isAuth = await isAuthenticated();
    
    if (!isAuth && context.mounted) {
      await _apiService.logout();
      
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  // إعادة توجيه المستخدم المسجل بعيداً عن صفحات Auth
  Future<void> redirectIfAuthenticated(BuildContext context, String route) async {
    final isAuth = await isAuthenticated();
    
    if (isAuth && context.mounted) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }
}

// ============================================
//  Widget للصفحات المحمية
// ============================================
class ProtectedRoute extends StatefulWidget {
  final Widget child;
  final String? redirectRoute;

  const ProtectedRoute({
    Key? key,
    required this.child,
    this.redirectRoute = '/login',
  }) : super(key: key);

  @override
  State<ProtectedRoute> createState() => _ProtectedRouteState();
}

class _ProtectedRouteState extends State<ProtectedRoute> {
  final AuthGuard _authGuard = AuthGuard();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final isAuth = await _authGuard.isAuthenticated();
    
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isLoading = false;
      });

      if (!isAuth) {
        Future.microtask(() {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              widget.redirectRoute!,
              (route) => false,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated) {
      return const Scaffold(
        body: Center(
          child: Text('جاري إعادة التوجيه...'),
        ),
      );
    }

    return widget.child;
  }
}