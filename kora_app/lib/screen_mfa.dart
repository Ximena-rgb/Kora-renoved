import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'provider_auth.dart';
import 'theme.dart';
import 'widgets_kora_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MfaScreen — verify TOTP code (shown after login when MFA is required)
// ─────────────────────────────────────────────────────────────────────────────

class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key});
  @override State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final List<TextEditingController> _ctrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focus =
      List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _ctrl) c.dispose();
    for (final f in _focus) f.dispose();
    super.dispose();
  }

  String get _code => _ctrl.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: Stack(children: [
        Positioned(
          top: -80, right: -60,
          child: Container(width: 260, height: 260,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                KoraColors.primary.withOpacity(0.15), Colors.transparent,
              ]))),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: KoraColors.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
              const Spacer(flex: 2),

              // Icon
              Center(child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: KoraGradients.mainGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: KoraColors.primary.withOpacity(0.4),
                    blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.shield_outlined,
                    color: Colors.white, size: 36),
              )),
              const SizedBox(height: 28),

              const Center(child: Text('Verificación de identidad',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                    color: KoraColors.textPrimary, letterSpacing: -0.8))),
              const SizedBox(height: 8),
              const Center(child: Text(
                'Ingresa el código de 6 dígitos de\nGoogle Authenticator',
                textAlign: TextAlign.center,
                style: TextStyle(color: KoraColors.textSecondary,
                    fontSize: 14, height: 1.5))),

              const SizedBox(height: 36),

              // OTP boxes
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                  width: 46, height: 58,
                  child: TextField(
                    controller: _ctrl[i],
                    focusNode: _focus[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: KoraColors.textPrimary),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: KoraColors.bgElevated,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: KoraColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: KoraColors.primary, width: 2),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) _focus[i + 1].requestFocus();
                      else if (v.isEmpty && i > 0) _focus[i - 1].requestFocus();
                      setState(() {});
                    },
                  ),
                )),
              ),

              if (auth.error != null) ...[
                const SizedBox(height: 16),
                KoraErrorBanner(auth.error!),
              ],

              const SizedBox(height: 28),
              KoraGradientActionBtn(
                label: 'Verificar',
                loading: auth.isLoading,
                onPressed: _code.length == 6
                  ? () async {
                      auth.clearError();
                      final ok = await auth.verificarMfa(_code);
                      if (ok && mounted) Navigator.pop(context);
                    }
                  : null,
              ),
              const Spacer(flex: 3),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MfaSetupScreen — guide user to enable MFA via Google Authenticator
// ─────────────────────────────────────────────────────────────────────────────

class MfaSetupScreen extends StatefulWidget {
  const MfaSetupScreen({super.key});
  @override State<MfaSetupScreen> createState() => _MfaSetupScreenState();
}

class _MfaSetupScreenState extends State<MfaSetupScreen> {
  int _step = 0; // 0=instrucciones, 1=escanear QR, 2=confirmar código

  final List<TextEditingController> _codeCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocus =
      List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _codeCtrl) c.dispose();
    for (final f in _codeFocus) f.dispose();
    super.dispose();
  }

  String get _code => _codeCtrl.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: KoraColors.textSecondary, size: 20),
              onPressed: () {
                if (_step > 0) setState(() => _step--);
                else Navigator.pop(context);
              },
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Step indicator
            Row(children: List.generate(3, (i) {
              final done = i < _step;
              final active = i == _step;
              return Expanded(child: Container(
                height: 4, margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  gradient: done || active ? KoraGradients.mainGradient : null,
                  color: done || active ? null : KoraColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ));
            })),
            const SizedBox(height: 28),

            Expanded(child: _step == 0
              ? _buildIntro()
              : _step == 1
                ? _buildQr()
                : _buildConfirm()),

            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Configurar MFA',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary, letterSpacing: -1.2)),
      const SizedBox(height: 8),
      const Text(
        'Activa la autenticación en dos pasos para proteger tu cuenta.',
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14, height: 1.5)),
      const SizedBox(height: 36),
      _stepCard('1', 'Descarga la app',
          'Instala Google Authenticator desde App Store o Play Store.',
          Icons.download_rounded),
      const SizedBox(height: 16),
      _stepCard('2', 'Escanea el código QR',
          'Abre la app y escanea el código que te mostraremos.',
          Icons.qr_code_scanner_rounded),
      const SizedBox(height: 16),
      _stepCard('3', 'Confirma el código',
          'Ingresa el código de 6 dígitos para verificar la configuración.',
          Icons.verified_user_outlined),
      const Spacer(),
      KoraGradientActionBtn(
        label: 'Continuar',
        loading: false,
        onPressed: () => setState(() => _step = 1),
      ),
    ]);
  }

  Widget _buildQr() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Escanea el código',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary, letterSpacing: -1.2)),
      const SizedBox(height: 8),
      const Text('Abre Google Authenticator y escanea este código QR.',
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 36),
      Center(child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: KoraColors.primary.withOpacity(0.25),
            blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Container(
          width: 180, height: 180,
          color: Colors.white,
          child: const Icon(Icons.qr_code_2_rounded,
              size: 180, color: Color(0xFF212121)),
        ),
      )),
      const SizedBox(height: 24),
      Center(child: Column(children: [
        const Text('¿No puedes escanear?',
          style: TextStyle(color: KoraColors.textHint, fontSize: 12)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {},
          child: const Text('Ingresar clave manualmente',
            style: TextStyle(color: KoraColors.primary,
                fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ])),
      const Spacer(),
      KoraGradientActionBtn(
        label: 'Ya escaneé el código',
        loading: false,
        onPressed: () => setState(() => _step = 2),
      ),
    ]);
  }

  Widget _buildConfirm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Verifica la configuración',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
            color: KoraColors.textPrimary, letterSpacing: -1.2)),
      const SizedBox(height: 8),
      const Text('Ingresa el código que aparece en Google Authenticator.',
        style: TextStyle(color: KoraColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 36),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) => SizedBox(
          width: 46, height: 58,
          child: TextField(
            controller: _codeCtrl[i],
            focusNode: _codeFocus[i],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                color: KoraColors.textPrimary),
            decoration: InputDecoration(
              counterText: '',
              filled: true, fillColor: KoraColors.bgElevated,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: KoraColors.divider)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: KoraColors.primary, width: 2)),
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
      const Spacer(),
      KoraGradientActionBtn(
        label: 'Activar MFA',
        loading: false,
        onPressed: _code.length == 6
          ? () {
              // TODO: call enable MFA endpoint
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('MFA activado exitosamente')));
            }
          : null,
      ),
    ]);
  }

  Widget _stepCard(String num, String title, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KoraColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KoraColors.divider),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: KoraGradients.mainGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(num,
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w900, fontSize: 16))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: const TextStyle(color: KoraColors.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(desc,
              style: const TextStyle(color: KoraColors.textSecondary,
                  fontSize: 12, height: 1.4)),
          ],
        )),
        Icon(icon, color: KoraColors.textHint, size: 20),
      ]),
    );
  }
}
