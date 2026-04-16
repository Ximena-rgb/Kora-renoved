import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'widgets_kora_auth.dart';

class SmsRecoveryScreen extends StatefulWidget {
  const SmsRecoveryScreen({super.key});
  @override State<SmsRecoveryScreen> createState() => _SmsRecoveryScreenState();
}

class _SmsRecoveryScreenState extends State<SmsRecoveryScreen> {
  int  _step = 0; // 0=email, 1=código, 2=nueva contraseña
  bool _ok   = false;

  // Step 0
  final _emailCtrl = TextEditingController();
  String? _emailError;

  // Step 1 — 6 OTP boxes
  final List<TextEditingController> _codeCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocus =
      List.generate(6, (_) => FocusNode());

  // Step 2
  final _passCtrl   = TextEditingController();
  final _confCtrl   = TextEditingController();
  bool _passVisible = false;
  bool _confVisible = false;
  String? _passError;
  String? _confError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _codeCtrl) c.dispose();
    for (final f in _codeFocus) f.dispose();
    _passCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  String get _codeValue => _codeCtrl.map((c) => c.text).join();

  Future<void> _sendEmail() async {
    final email = _emailCtrl.text.trim();
    if (!email.endsWith('@pascualbravo.edu.co')) {
      setState(() => _emailError = 'Solo correos @pascualbravo.edu.co');
      return;
    }
    setState(() => _emailError = null);
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.requestPasswordReset(email);
    if (!mounted) return;
    if (ok) setState(() => _step = 1);
  }

  void _verifyCode() {
    if (_codeValue.length == 6) setState(() => _step = 2);
  }

  Future<void> _changePassword() async {
    final pass = _passCtrl.text;
    final conf = _confCtrl.text;
    setState(() {
      _passError = pass.length < 8 ? 'Mínimo 8 caracteres' : null;
      _confError = conf != pass ? 'Las contraseñas no coinciden' : null;
    });
    if (_passError != null || _confError != null) return;

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.confirmPasswordReset(
        _emailCtrl.text.trim(), _codeValue, pass);
    if (!mounted) return;
    if (ok) setState(() => _ok = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: Stack(children: [
        Positioned(
          top: -80, left: -60,
          child: Container(width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KoraColors.primary.withOpacity(0.15), Colors.transparent,
              ]))),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: KoraColors.textSecondary, size: 20),
                onPressed: () {
                  if (_step > 0 && !_ok) setState(() => _step--);
                  else Navigator.pop(context);
                },
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              _buildStepBar(),
              const SizedBox(height: 32),
              if (_ok)
                _buildSuccess()
              else if (_step == 0)
                _buildEmailStep(auth)
              else if (_step == 1)
                _buildCodeStep(auth)
              else
                _buildPasswordStep(auth),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildStepBar() {
    const labels = ['Correo', 'Código', 'Contraseña'];
    return Row(children: List.generate(3, (i) {
      final done    = i < _step || _ok;
      final current = i == _step && !_ok;
      return Expanded(child: Row(children: [
        Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: done || current ? KoraGradients.mainGradient : null,
              color: done || current ? null : KoraColors.bgCard,
              border: Border.all(
                color: done || current ? Colors.transparent : KoraColors.divider),
            ),
            child: Center(child: done
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Text('${i + 1}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: current ? Colors.white : KoraColors.textHint))),
          ),
          const SizedBox(height: 4),
          Text(labels[i],
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: done || current ? KoraColors.primary : KoraColors.textHint)),
        ]),
        if (i < 2)
          Expanded(child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              gradient: done ? KoraGradients.mainGradient : null,
              color: done ? null : KoraColors.divider,
              borderRadius: BorderRadius.circular(1),
            ),
          )),
      ]));
    }));
  }

  Widget _buildEmailStep(AuthProvider auth) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Recuperar acceso',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary, letterSpacing: -1.2)),
      const SizedBox(height: 8),
      const Text(
        'Ingresa tu correo institucional y te enviaremos un código de verificación.',
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14, height: 1.5)),
      const SizedBox(height: 28),
      const Text('Correo institucional',
        style: TextStyle(color: KoraColors.textSecondary,
            fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 8),
      KoraInputField(
        controller: _emailCtrl,
        hint: 'correo@pascualbravo.edu.co',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        error: _emailError,
        onChanged: (_) => setState(() => _emailError = null),
      ),
      if (auth.error != null) ...[
        const SizedBox(height: 12),
        KoraErrorBanner(auth.error!),
      ],
      const SizedBox(height: 28),
      KoraGradientActionBtn(
        label: 'Enviar código',
        loading: auth.isLoading,
        onPressed: _sendEmail,
      ),
    ]);
  }

  Widget _buildCodeStep(AuthProvider auth) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Código de verificación',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary, letterSpacing: -1.2)),
      const SizedBox(height: 8),
      RichText(text: TextSpan(children: [
        const TextSpan(text: 'Enviamos un código a ',
          style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
        TextSpan(text: _emailCtrl.text.trim(),
          style: const TextStyle(color: KoraColors.primary,
              fontWeight: FontWeight.w700, fontSize: 14)),
      ])),
      const SizedBox(height: 32),
      // 6 cajas OTP
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) => SizedBox(
          width: 44, height: 54,
          child: TextField(
            controller: _codeCtrl[i],
            focusNode: _codeFocus[i],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                color: KoraColors.textPrimary),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: KoraColors.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KoraColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KoraColors.primary, width: 2),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) _codeFocus[i + 1].requestFocus();
              else if (v.isEmpty && i > 0) _codeFocus[i - 1].requestFocus();
              setState(() {});
            },
          ),
        )),
      ),
      const SizedBox(height: 28),
      KoraGradientActionBtn(
        label: 'Verificar código',
        loading: auth.isLoading,
        onPressed: _codeValue.length == 6 ? _verifyCode : null,
      ),
      const SizedBox(height: 16),
      Center(child: GestureDetector(
        onTap: () async {
          for (final c in _codeCtrl) c.clear();
          await context.read<AuthProvider>()
              .requestPasswordReset(_emailCtrl.text.trim());
        },
        child: const Text('¿No recibiste el código? Reenviar',
          style: TextStyle(color: KoraColors.primary,
              fontWeight: FontWeight.w600, fontSize: 14)),
      )),
    ]);
  }

  Widget _buildPasswordStep(AuthProvider auth) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Nueva contraseña',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary, letterSpacing: -1.2)),
      const SizedBox(height: 8),
      const Text('Crea una contraseña segura para tu cuenta.',
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 28),
      const Text('Nueva contraseña',
        style: TextStyle(color: KoraColors.textSecondary,
            fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 8),
      KoraInputField(
        controller: _passCtrl,
        hint: 'Mínimo 8 caracteres',
        icon: Icons.lock_outline,
        obscure: !_passVisible,
        error: _passError,
        onChanged: (_) => setState(() => _passError = null),
        suffix: IconButton(
          icon: Icon(_passVisible
              ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: KoraColors.textHint, size: 20),
          onPressed: () => setState(() => _passVisible = !_passVisible),
        ),
      ),
      const SizedBox(height: 16),
      const Text('Confirmar contraseña',
        style: TextStyle(color: KoraColors.textSecondary,
            fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 8),
      KoraInputField(
        controller: _confCtrl,
        hint: 'Repite tu contraseña',
        icon: Icons.lock_outline,
        obscure: !_confVisible,
        error: _confError,
        onChanged: (_) => setState(() => _confError = null),
        suffix: IconButton(
          icon: Icon(_confVisible
              ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
        label: 'Cambiar contraseña',
        loading: auth.isLoading,
        onPressed: _changePassword,
      ),
    ]);
  }

  Widget _buildSuccess() {
    return Column(children: [
      const SizedBox(height: 40),
      Center(child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: KoraGradients.mainGradient,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: KoraColors.primary.withOpacity(0.4),
            blurRadius: 30, spreadRadius: 2)],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
      )),
      const SizedBox(height: 28),
      const Text('¡Contraseña actualizada!',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary, letterSpacing: -0.8)),
      const SizedBox(height: 8),
      const Text('Ya puedes iniciar sesión con tu nueva contraseña.',
        textAlign: TextAlign.center,
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14, height: 1.5)),
      const SizedBox(height: 40),
      KoraGradientActionBtn(
        label: 'Ir a iniciar sesión',
        loading: false,
        onPressed: () => Navigator.pop(context),
      ),
    ]);
  }
}
