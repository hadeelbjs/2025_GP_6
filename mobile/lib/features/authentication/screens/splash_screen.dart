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
      end: const Alignment(0, -0.60),
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
    final logoSize = screenWidth * 0.62;

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
            alignment: const Alignment(0.85, 0.18),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Opacity(
                  opacity: _contentFade.value,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          _WelcomeText(),
                          SizedBox(height: 5),
                          _BrandTitle(),
                          SizedBox(height: 20),
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
            textAlign: TextAlign.center,
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
    return Text(
      'مرحباً بك في',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: 'IBMPlexSansArabic',
        fontSize: 28,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: AppColors.primary.withOpacity(0.7),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          AppColors.primary,
          AppColors.primaryAlt,
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(bounds),
      child: const Text(
        'وصــيد',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 72,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _SloganText extends StatelessWidget {
  const _SloganText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'حيث أمانك بلغتك',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: 'IBMPlexSansArabic',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.primary,
        letterSpacing: 0.2,
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
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.primary,
            AppColors.primaryAlt,
            AppColors.primaryLight,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryAlt.withOpacity(0.4),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.9),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(34),
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.white.withOpacity(0.1),
          child: const Center(
            child: Text(
              'ابدأ الآن',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.0,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------ Bottom Wave - ELEGANT VERSION ------------------------------
class _BottomGeometricShape extends StatelessWidget {
  const _BottomGeometricShape();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: CustomPaint(painter: _ElegantWavePainter()),
    );
  }
}
class _ElegantWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Deep elegant base
    final paint1 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color(0xFF281B67),
          Color(0xFF3D2E8C),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path1 = Path()
      ..moveTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.25, h * 0.65, w * 0.6, h * 0.8)
      ..quadraticBezierTo(w * 0.85, h * 0.9, w, h * 0.75)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path1, paint1);

    // Secondary smooth layer for depth
    final paint2 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF4A3E92),
          Color(0xFF6B5DA8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path2 = Path()
      ..moveTo(0, h * 0.85)
      ..quadraticBezierTo(w * 0.3, h * 0.7, w, h * 0.9)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
