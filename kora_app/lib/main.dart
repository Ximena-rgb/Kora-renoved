import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'provider_plans.dart';
import 'provider_chat.dart';
import 'provider_matching.dart';
import 'services/auth_service.dart';
import 'screen_splash.dart';
import 'screen_login.dart';
import 'screen_home.dart';
import 'screen_onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const KoraApp());
}

class KoraApp extends StatelessWidget {
  const KoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlansProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => MatchingProvider()),
      ],
      child: MaterialApp(
        title: 'KORA',
        debugShowCheckedModeBanner: false,
        theme: KoraTheme.dark,
        home: const _AppEntry(),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();
  @override State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _loading = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final auth = context.read<AuthProvider>();
    // Detectar si había sesión previa antes de restaurar
    final hadToken = await AuthService.getAccessToken() != null;
    await auth.tryRestoreSession();
    if (mounted) setState(() { _loading = false; _hasSession = hadToken; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _KoraLoadingScreen();
    }

    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated)  return _hasSession ? const LoginScreen() : const SplashScreen();
    if (auth.needsOnboarding)   return const OnboardingScreen();
    return const HomeScreen();
  }
}

// ── Pantalla de carga con identidad de marca ──────────────────────
class _KoraLoadingScreen extends StatefulWidget {
  const _KoraLoadingScreen();
  @override State<_KoraLoadingScreen> createState() => _KoraLoadingScreenState();
}

class _KoraLoadingScreenState extends State<_KoraLoadingScreen>
    with TickerProviderStateMixin {
  // Anillo giratorio
  late final AnimationController _spinCtrl;
  late final Animation<double>   _spin;

  // Pulso del logo (escala + glow)
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;
  late final Animation<double>   _glow;

  // Fade de entrada general
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();

    // Rotación continua del anillo
    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _spin = Tween<double>(begin: 0, end: 1).animate(_spinCtrl);

    // Pulso suave del logo
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.93, end: 1.07).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _glow  = Tween<double>(begin: 18.0, end: 40.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Fade de entrada
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // ── Logo con anillo giratorio ───────────────────────
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(alignment: Alignment.center, children: [

                // Anillo exterior giratorio con gradiente
                AnimatedBuilder(
                  animation: _spin,
                  builder: (_, __) => Transform.rotate(
                    angle: _spin.value * 2 * 3.141592653589793,
                    child: CustomPaint(
                      size: const Size(120, 120),
                      painter: _GradientRingPainter(
                        colors: const [
                          KoraColors.gradientStart,
                          KoraColors.gradientMid,
                          KoraColors.gradientEnd,
                          Colors.transparent,
                        ],
                        strokeWidth: 3.5,
                      ),
                    ),
                  ),
                ),

                // Logo central con pulso
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: _pulse.value,
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: KoraGradients.mainGradient,
                        boxShadow: [
                          BoxShadow(
                            color: KoraColors.primary.withOpacity(0.55),
                            blurRadius: _glow.value,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: KoraColors.gradientEnd.withOpacity(0.25),
                            blurRadius: _glow.value * 0.6,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 42,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 28),

            // ── Nombre de la app ────────────────────────────────
            ShaderMask(
              shaderCallback: (b) =>
                  KoraGradients.mainGradient.createShader(b),
              child: const Text(
                'KORA',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 8,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// Dibuja un arco con gradiente que crea el efecto de anillo de carga
class _GradientRingPainter extends CustomPainter {
  final List<Color> colors;
  final double strokeWidth;

  const _GradientRingPainter({
    required this.colors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect   = Offset.zero & size;
    final shader = SweepGradient(colors: colors).createShader(rect);
    final paint  = Paint()
      ..shader     = shader
      ..style      = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap  = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -3.141592653589793 / 2, // Empieza desde arriba
      3.141592653589793 * 1.75, // ~315° — deja un hueco visible
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) =>
      old.strokeWidth != strokeWidth;
}
