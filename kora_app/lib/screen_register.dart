import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'screen_mfa.dart';
import 'widgets_kora_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _confCtrl   = TextEditingController();
  bool _passVisible = false;
  bool _confVisible = false;
  String? _nameError;
  String? _emailError;
  String? _passError;
  String? _confError;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final nombre = _nombreCtrl.text.trim();
    final email  = _emailCtrl.text.trim();
    final pass   = _passCtrl.text;
    final conf   = _confCtrl.text;
    setState(() {
      _nameError  = nombre.split(' ').length < 2 || nombre.length < 4
          ? 'Ingresa nombre y apellido' : null;
      _emailError = !email.endsWith('@pascualbravo.edu.co')
          ? 'Solo correos @pascualbravo.edu.co' : null;
      _passError  = pass.length < 8 ? 'Mínimo 8 caracteres' : null;
      _confError  = conf != pass ? 'Las contraseñas no coinciden' : null;
    });
    return _nameError == null && _emailError == null &&
           _passError == null && _confError == null;
  }

  Future<void> _register() async {
    if (!_validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.registerWithEmail(
      _emailCtrl.text.trim(),
      _passCtrl.text,
      _nombreCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok && auth.mfaRequired) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const MfaScreen()));
    }
  }

  double _strength(String p) {
    if (p.isEmpty) return 0;
    double s = 0;
    if (p.length >= 8)  s += 0.25;
    if (p.length >= 12) s += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(p))              s += 0.2;
    if (RegExp(r'[0-9]').hasMatch(p))              s += 0.2;
    if (RegExp(r'[!@#\$%^&*(),.?]').hasMatch(p)) s += 0.2;
    return s.clamp(0.0, 1.0);
  }

  Color  _strengthColor(double s) => s < 0.4
      ? KoraColors.pass : s < 0.7 ? KoraColors.scoreMid : KoraColors.like;
  String _strengthLabel(double s) =>
      s < 0.4 ? 'Débil' : s < 0.7 ? 'Media' : 'Fuerte';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: Stack(children: [
        Positioned(
          top: -100, right: -80,
          child: Container(width: 300, height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KoraColors.primary.withOpacity(0.15), Colors.transparent,
              ]))),
        ),
        Positioned(
          bottom: -60, left: -40,
          child: Container(width: 240, height: 240,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KoraColors.accent.withOpacity(0.12), Colors.transparent,
              ]))),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: KoraColors.textSecondary, size: 20),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              const Text('Crear cuenta',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                    color: KoraColors.textPrimary, letterSpacing: -1.5)),
              const SizedBox(height: 6),
              const Text('Únete a la comunidad universitaria',
                style: TextStyle(color: KoraColors.textSecondary, fontSize: 15)),
              const SizedBox(height: 32),

              _label('Nombre completo'),
              KoraInputField(
                controller: _nombreCtrl,
                hint: 'Nombre y apellido',
                icon: Icons.person_outline,
                error: _nameError,
                onChanged: (_) => setState(() => _nameError = null),
              ),
              const SizedBox(height: 18),

              _label('Correo institucional'),
              KoraInputField(
                controller: _emailCtrl,
                hint: 'correo@pascualbravo.edu.co',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                error: _emailError,
                onChanged: (_) => setState(() => _emailError = null),
              ),
              const SizedBox(height: 18),

              _label('Contraseña'),
              KoraInputField(
                controller: _passCtrl,
                hint: 'Mínimo 8 caracteres',
                icon: Icons.lock_outline,
                obscure: !_passVisible,
                error: _passError,
                onChanged: (_) => setState(() { _passError = null; }),
                suffix: IconButton(
                  icon: Icon(
                    _passVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: KoraColors.textHint, size: 20),
                  onPressed: () => setState(() => _passVisible = !_passVisible),
                ),
              ),
              if (_passCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final s = _strength(_passCtrl.text);
                  final c = _strengthColor(s);
                  return Row(children: [
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: s, minHeight: 4,
                        backgroundColor: KoraColors.divider,
                        valueColor: AlwaysStoppedAnimation(c),
                      ),
                    )),
                    const SizedBox(width: 10),
                    Text(_strengthLabel(s),
                      style: TextStyle(color: c, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  ]);
                }),
              ],
              const SizedBox(height: 18),

              _label('Confirmar contraseña'),
              KoraInputField(
                controller: _confCtrl,
                hint: 'Repite tu contraseña',
                icon: Icons.lock_outline,
                obscure: !_confVisible,
                error: _confError,
                onChanged: (_) => setState(() => _confError = null),
                suffix: IconButton(
                  icon: Icon(
                    _confVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: KoraColors.textHint, size: 20),
                  onPressed: () => setState(() => _confVisible = !_confVisible),
                ),
              ),

              if (auth.error != null) ...[
                const SizedBox(height: 12),
                KoraErrorBanner(auth.error!),
              ],
              const SizedBox(height: 28),

              KoraGradientActionBtn(
                label: 'Crear cuenta',
                loading: auth.isLoading,
                onPressed: _register,
              ),
              const SizedBox(height: 20),

              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('¿Ya tienes cuenta? ',
                  style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: ShaderMask(
                    shaderCallback: (b) =>
                        KoraGradients.mainGradient.createShader(b),
                    child: const Text('Iniciar sesión',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ]),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
      style: const TextStyle(color: KoraColors.textSecondary,
          fontWeight: FontWeight.w600, fontSize: 13)),
  );
}
