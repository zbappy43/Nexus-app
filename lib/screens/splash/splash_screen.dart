import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_config.dart';
import '../../constants/app_strings.dart';
import '../../core/bootstrap.dart';
import '../../core/di/app_services.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/update_provider.dart';
import '../../widgets/app_logo.dart';

/// Animated splash: logo, company name and loading animation for
/// [AppConfig.splashDuration] while services initialise.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();
  late final AnimationController _loader = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  late final Animation<double> _logoScale =
      CurvedAnimation(parent: _intro, curve: const Interval(0, 0.6, curve: Curves.elasticOut));
  late final Animation<double> _logoFade =
      CurvedAnimation(parent: _intro, curve: const Interval(0, 0.35, curve: Curves.easeOut));
  late final Animation<double> _textFade =
      CurvedAnimation(parent: _intro, curve: const Interval(0.4, 0.9, curve: Curves.easeOut));
  late final Animation<Offset> _textSlide = Tween<Offset>(
    begin: const Offset(0, 0.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _intro, curve: const Interval(0.4, 1, curve: Curves.easeOutCubic)));

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final AppServices services = context.read<AppServices>();
    final AuthProvider auth = context.read<AuthProvider>();
    final UpdateProvider updates = context.read<UpdateProvider>();
    final AppStageProvider stage = context.read<AppStageProvider>();

    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      AppBootstrapper.run(services: services, auth: auth, updates: updates),
      Future<void>.delayed(AppConfig.splashDuration),
    ]);
    final BootstrapResult result = results.first! as BootstrapResult;
    if (!mounted) return;
    stage.finishSplash(
      showPermissions: result.showPermissionOnboarding,
      initialUrl: result.initialUrl,
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: <Color>[AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
            stops: <double>[0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const Spacer(flex: 3),
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: AppColors.accent, width: 3),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(0, 14)),
                      ],
                    ),
                    child: const AppLogo(size: 104),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: <Widget>[
                      Text(
                        AppConfig.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.tagline,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              _BouncingDots(animation: _loader),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three gold dots bouncing in sequence.
class _BouncingDots extends AnimatedWidget {
  const _BouncingDots({required Animation<double> animation}) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final double t = (listenable as Animation<double>).value;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(3, (int i) {
        final double phase = (t - i * 0.18) * 2 * math.pi;
        final double lift = math.max(0, math.sin(phase)) * 10;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.translate(
            offset: Offset(0, -lift),
            child: Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            ),
          ),
        );
      }),
    );
  }
}
