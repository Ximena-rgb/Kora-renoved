import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'screen_mfa.dart';
import 'widgets_kora_auth.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _loginGoogle(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.loginWithGoogle();
    if (!context.mounted) return;
    if (ok && auth.mfaRequired) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MfaScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: Stack(children: [
        Positioned(
          top: -100, left: -80,
          child: Container(width: 350, height: 350,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KoraColors.primary.withOpacity(0.18), Colors.transparent,
              ]))),
        ),
        Positioned(
          bottom: -60, right: -60,
          child: Container(width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KoraColors.accent.withOpacity(0.14), Colors.transparent,
              ]))),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 60),
              // Logo
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: KoraGradients.mainGradient,
                  boxShadow: [BoxShadow(
                    color: KoraColors.primary.withOpacity(0.5),
                    blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.favorite_rounded,
                    size: 32, color: Colors.white),
              ),
              const SizedBox(height: 28),
              const Text('KORA',
                style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900,
                    color: KoraColors.textPrimary, letterSpacing: -2)),
              const SizedBox(height: 8),
              const Text('Conexiones universitarias\nreales y auténticas.',
                style: TextStyle(fontSize: 16, color: KoraColors.textSecondary,
                    height: 1.5)),
              const SizedBox(height: 44),

              // Error banner
              if (auth.error != null) ...[
                KoraErrorBanner(auth.error!),
                const SizedBox(height: 16),
              ],

              // Google button (always visible)
              _GoogleButton(
                loading: auth.isLoading,
                onTap: () => _loginGoogle(context),
              ),
              const SizedBox(height: 32),
              Center(child: const Text(
                'Al continuar aceptas nuestros Términos y Política de Privacidad',
                style: TextStyle(color: KoraColors.textHint, fontSize: 11),
                textAlign: TextAlign.center,
              )),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          color: KoraColors.bgElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KoraColors.divider, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: KoraColors.primary))
          else ...[
            const Text('G',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                  color: Color(0xFF4285F4))),
            const SizedBox(width: 14),
            const Text('Continuar con correo institucional',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: KoraColors.textPrimary)),
          ],
        ]),
      ),
    );
  }
}
