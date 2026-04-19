import 'package:flutter/material.dart';
import 'theme.dart';
import 'screen_login.dart';

/// Pantalla de presentación animada de Kora.
/// Flujo: Splash → Slides de ventajas → Registro
///        (con acceso directo a Login para usuarios existentes)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _fade;
  late final Animation<double>    _scale;
  late final Animation<double>    _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fade    = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeIn));
    _scale   = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _comenzar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _FeatureSlidesScreen()),
    );
  }

  void _irLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: Stack(children: [
        // Fondo decorativo
        Positioned(
          top: -120, left: -100,
          child: Container(
            width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KoraColors.primary.withOpacity(0.20), Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: -80, right: -80,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KoraColors.accent.withOpacity(0.15), Colors.transparent,
              ]),
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo animado
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: KoraGradients.mainGradient,
                          boxShadow: [
                            BoxShadow(
                              color: KoraColors.primary.withOpacity(0.55),
                              blurRadius: 40, offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 52, color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Título + slogan
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: FadeTransition(
                      opacity: _fade,
                      child: Column(children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              KoraGradients.mainGradient.createShader(b),
                          child: const Text(
                            'KORA',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tu campus, tus conexiones.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: KoraColors.textSecondary,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Encuentra pareja, amigos y compañeros\nde estudio en tu universidad.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: KoraColors.textSecondary.withOpacity(0.7),
                            height: 1.5,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // Botón Comenzar + link de login
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => FadeTransition(
                    opacity: _fade,
                    child: Column(children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: KoraGradients.mainGradient,
                            boxShadow: [
                              BoxShadow(
                                color: KoraColors.primary.withOpacity(0.4),
                                blurRadius: 20, offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _comenzar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Comenzar',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Link para usuarios existentes — visible desde el primer momento
                      GestureDetector(
                        onTap: _irLogin,
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: KoraColors.textSecondary,
                            ),
                            children: [
                              const TextSpan(text: '¿Ya tienes cuenta? '),
                              TextSpan(
                                text: 'Iniciar sesión',
                                style: TextStyle(
                                  color: KoraColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}


// ── Modelo de slide ────────────────────────────────────────────────
class _SlideData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _SlideData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });
}

const _slides = <_SlideData>[
  _SlideData(
    icon: Icons.school_rounded,
    iconColor: Color(0xFFE040FB),
    title: 'Solo estudiantes verificados',
    description:
        'Kora es exclusivo para tu universidad.\nTodos los perfiles están validados\ncon correo institucional.',
  ),
  _SlideData(
    icon: Icons.favorite_rounded,
    iconColor: Color(0xFFFF2D55),
    title: 'Conexiones que valen',
    description:
        'Encuentra pareja, amigos o compañeros\nde estudio. Sin bots, sin perfiles falsos,\nsolo personas reales de tu campus.',
  ),
  _SlideData(
    icon: Icons.calendar_today_rounded,
    iconColor: Color(0xFFFFD60A),
    title: 'Planes y actividades',
    description:
        'Organiza salidas, sesiones de estudio\no actividades en tu campus y conecta\nen persona de forma segura.',
  ),
  _SlideData(
    icon: Icons.star_rounded,
    iconColor: Color(0xFF30D158),
    title: 'Sistema de reputación',
    description:
        'Un perfil con buena reputación abre\npuertas. Sé puntual, sé amable\ny destaca dentro de tu comunidad.',
  ),
  _SlideData(
    icon: Icons.lock_rounded,
    iconColor: Color(0xFFBF5AF2),
    title: 'Tu privacidad, primero',
    description:
        'Tus datos nunca se venden.\nTú controlas qué compartes y\ncuándo desaparece tu cuenta.',
  ),
];


// ── Pantalla de slides de ventajas ────────────────────────────────
class _FeatureSlidesScreen extends StatefulWidget {
  const _FeatureSlidesScreen();
  @override State<_FeatureSlidesScreen> createState() => _FeatureSlidesScreenState();
}

class _FeatureSlidesScreenState extends State<_FeatureSlidesScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_currentPage < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _irRegistro();
    }
  }

  void _irRegistro() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _irLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: Stack(children: [
        // Fondo decorativo
        Positioned(
          top: -80, right: -60,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KoraColors.primary.withOpacity(0.15), Colors.transparent,
              ]),
            ),
          ),
        ),

        SafeArea(
          child: Column(children: [
            // Header: indicadores de progreso + botón saltar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_slides.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isActive
                              ? KoraColors.primary
                              : KoraColors.divider,
                        ),
                      );
                    }),
                  ),
                  if (_currentPage < _slides.length - 1)
                    TextButton(
                      onPressed: _irRegistro,
                      child: Text(
                        'Saltar',
                        style: TextStyle(
                          color: KoraColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),
                ],
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),

            // Botones inferiores
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: KoraGradients.mainGradient,
                      boxShadow: [
                        BoxShadow(
                          color: KoraColors.primary.withOpacity(0.4),
                          blurRadius: 20, offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _siguiente,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage < _slides.length - 1
                            ? 'Siguiente'
                            : 'Entrar con correo institucional',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _irLogin,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: KoraColors.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: '¿Ya tienes cuenta? '),
                        TextSpan(
                          text: 'Iniciar sesión',
                          style: TextStyle(
                            color: KoraColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}


// ── Vista individual de cada slide ────────────────────────────────
class _SlideView extends StatelessWidget {
  final _SlideData slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono con resplandor de color
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: slide.iconColor.withOpacity(0.10),
              border: Border.all(
                color: slide.iconColor.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.iconColor.withOpacity(0.25),
                  blurRadius: 48,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              slide.icon,
              size: 68,
              color: slide.iconColor,
            ),
          ),

          const SizedBox(height: 48),

          // Título
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 20),

          // Descripción
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: KoraColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
