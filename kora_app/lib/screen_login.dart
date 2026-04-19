import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'screen_mfa.dart';
import 'screen_debug_login.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade    = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _loginGoogle() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.loginWithGoogle();
    if (!mounted) return;

    if (ok && auth.mfaRequired) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MfaScreen()));
      return;
    }

    // Fix: si el login fue exitoso, limpiar el stack de navegación para que
    // _AppEntry (en main.dart) tome el control y redirija a Home/Onboarding.
    // Sin esto, LoginScreen queda encima del stack cuando viene desde Splash.
    if (ok && auth.isAuthenticated) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final size   = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: Stack(children: [

        // ── Orbes de fondo decorativos ──────────────────────────
        Positioned(
          top: -size.height * 0.12, left: -size.width * 0.25,
          child: _Orb(size: size.width * 0.8,
              color: KoraColors.primary.withOpacity(0.22)),
        ),
        Positioned(
          top: size.height * 0.25, right: -size.width * 0.20,
          child: _Orb(size: size.width * 0.55,
              color: KoraColors.accent.withOpacity(0.14)),
        ),
        Positioned(
          bottom: -size.height * 0.08, left: size.width * 0.1,
          child: _Orb(size: size.width * 0.5,
              color: KoraColors.gradientMid.withOpacity(0.12)),
        ),

        // ── Contenido principal ─────────────────────────────────
        SafeArea(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => FadeTransition(
              opacity: _fade,
              child: Transform.translate(
                offset: Offset(0, _slideUp.value),
                child: Column(children: [
                  // Zona superior — logo + textos
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.08),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          _LogoWidget(),
                          const SizedBox(height: 28),

                          // Título con gradiente
                          ShaderMask(
                            shaderCallback: (b) =>
                                KoraGradients.mainGradient.createShader(b),
                            child: const Text(
                              'KORA',
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          Text(
                            'Tu campus, tus conexiones.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: KoraColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Línea divisoria con gradiente
                          Container(
                            height: 1.5,
                            width: 60,
                            decoration: const BoxDecoration(
                              gradient: KoraGradients.mainGradient,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            'Encuentra pareja, amigos y compañeros\nde estudio en tu universidad.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: KoraColors.textSecondary
                                  .withOpacity(0.65),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Zona inferior — botón + error + disclaimer
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        size.width * 0.06, 0, size.width * 0.06, 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Banner de error
                        if (auth.error != null)
                          _ErrorBanner(message: auth.error!),

                        if (auth.error != null) const SizedBox(height: 14),

                        // Botón institucional de Google
                        _InstitucionalButton(
                          loading: auth.isLoading,
                          onTap: _loginGoogle,
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Al continuar aceptas nuestros Términos\ny Política de Privacidad',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: KoraColors.textHint,
                            height: 1.6,
                          ),
                        ),

                        // ── Botón debug (solo en modo desarrollo) ──
                        if (kDebugMode) ...[
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                builder: (_) => const DebugLoginScreen())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFFF9800).withOpacity(0.30)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bug_report_outlined,
                                      size: 14, color: Color(0xFFFF9800)),
                                  SizedBox(width: 6),
                                  Text('Modo debug — email/contraseña',
                                    style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF9800))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Logo animado con glow ─────────────────────────────────────────
class _LogoWidget extends StatefulWidget {
  @override State<_LogoWidget> createState() => _LogoWidgetState();
}

class _LogoWidgetState extends State<_LogoWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double>   _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 24, end: 48).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: KoraGradients.mainGradient,
          boxShadow: [
            BoxShadow(
              color: KoraColors.primary.withOpacity(0.55),
              blurRadius: _glow.value,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.favorite_rounded,
            size: 44, color: Colors.white),
      ),
    );
  }
}

// ── Orbe decorativo ───────────────────────────────────────────────
class _Orb extends StatelessWidget {
  final double size;
  final Color  color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

// ── Botón institucional rediseñado ────────────────────────────────
class _InstitucionalButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _InstitucionalButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: loading ? null : KoraGradients.mainGradient,
          color: loading ? KoraColors.bgElevated : null,
          boxShadow: loading ? [] : [
            BoxShadow(
              color: KoraColors.primary.withOpacity(0.40),
              blurRadius: 24, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: loading
            ? const Center(
                child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                // Logo G de Google estilizado
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text('G',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: Color(0xFF4285F4),
                        height: 1,
                      )),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Continuar con correo institucional',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ]),
      ),
    );
  }
}

// ── Banner de error ───────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: KoraColors.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KoraColors.accent.withOpacity(0.35)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded,
            size: 18, color: KoraColors.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(
          message,
          style: TextStyle(
              color: KoraColors.accent,
              fontSize: 13, fontWeight: FontWeight.w500),
        )),
      ]),
    );
  }
}
