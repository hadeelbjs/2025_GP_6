import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class AppColors {
  static const primary = Color(0xFF281B67);
  static const primaryAlt = Color(0xFF4A3E92);
  static const primaryLight = Color(0xFF6B5DA8);
  static const bg = Colors.white;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waseed',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.primary,
        fontFamily: 'IBMPlexSansArabic',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.primary),
          bodyMedium: TextStyle(color: AppColors.primary),
          bodySmall: TextStyle(color: AppColors.primary),
        ),
        splashFactory: InkRipple.splashFactory,
      ),
      home: const OnboardingScreen(),
    );
  }
}

/// ------------------------------ Onboarding Screen ------------------------------
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const _total = Duration(milliseconds: 3800);

  late final Animation<double> _logoElasticScale;
  late final Animation<Alignment> _logoAlignToTop;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _total);

    const split = 0.35;

    _logoElasticScale = Tween<double>(begin: 0.40, end: 1.10).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.00, split, curve: Curves.elasticOut),
      ),
    );

    _logoAlignToTop = AlignmentTween(
      begin: Alignment.center,
      end: const Alignment(0, -0.70),
    ).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(split, 1.00, curve: Curves.easeOutCubic),
      ),
    );

    _contentFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.45, 1.00, curve: Curves.easeIn),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.45, 1.00, curve: Curves.easeOutCubic),
      ),
    );

    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = screenWidth * 0.56;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Align(
            alignment: Alignment.bottomCenter,
            child: _BottomGeometricShape(),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return AlignTransition(
                alignment: _logoAlignToTop,
                child: Transform.scale(
                  scale: _logoElasticScale.value,
                  child: _Logo(size: logoSize),
                ),
              );
            },
          ),
          Align(
            alignment: const Alignment(0.98, 0.15),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Opacity(
                  opacity: _contentFade.value,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          _WelcomeText(),
                          SizedBox(height: 25),
                          _BrandTitle(),
                          SizedBox(height: 25),
                          _SloganText(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: _contentFade.value,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 140.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                       _PrimaryButton(
                        label: 'ابدأ الآن',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                      ),


                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ------------------------------ Widgets ------------------------------
class _Logo extends StatelessWidget {
  final double size;
  const _Logo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) {
          return const Text(
            'وصـيـد',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 72,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeText extends StatelessWidget {
  const _WelcomeText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'مرحباً بك في',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: 'IBMPlexSansArabic',
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.primary,
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'وصيد',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: 'IBMPlexSansArabic',
        fontSize: 72,
        fontWeight: FontWeight.w800,
        height: 1.0,
        color: AppColors.primary,
      ),
    );
  }
}

class _SloganText extends StatelessWidget {
  const _SloganText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'أمانك بلغتك',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: 'IBMPlexSansArabic',
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.primary,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 66,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryAlt],
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(34),
          onTap: onTap,
          child: const Center(
            child: Text(
              'ابدأ الآن',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------ Bottom Wave ------------------------------
class _BottomGeometricShape extends StatelessWidget {
  const _BottomGeometricShape();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: CustomPaint(painter: _ModernWavePainter()),
    );
  }
}

class _ModernWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintDark = Paint()
      ..color = AppColors.primaryAlt
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.35, h * 0.4, w, h * 0.65)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path1, paintDark);

    final paintLight = Paint()
      ..color = AppColors.primaryLight.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(0, h * 0.7)
      ..quadraticBezierTo(w * 0.6, h * 0.25, w, h * 0.45)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path2, paintLight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
 
