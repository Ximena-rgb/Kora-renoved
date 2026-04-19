/// screen_debug_login.dart
/// Pantalla de login/registro con email+contraseña para testing.
/// Solo visible en modo DEBUG — no aparece en la build de producción.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'screen_mfa.dart';

class DebugLoginScreen extends StatefulWidget {
  const DebugLoginScreen({super.key});
  @override State<DebugLoginScreen> createState() => _DebugLoginScreenState();
}

class _DebugLoginScreenState extends State<DebugLoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.bg,
      appBar: AppBar(
        backgroundColor: KoraColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: KoraColors.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.5)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bug_report_outlined, size: 14, color: Color(0xFFFF9800)),
              SizedBox(width: 4),
              Text('DEBUG', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: Color(0xFFFF9800), letterSpacing: 1)),
            ]),
          ),
          const SizedBox(width: 10),
          Text('Testing', style: TextStyle(
            color: KoraColors.textSecondary, fontSize: 16,
            fontWeight: FontWeight.w600)),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: KoraColors.primary,
          indicatorWeight: 2,
          labelColor: KoraColors.textPrimary,
          unselectedLabelColor: KoraColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'Iniciar sesión'),
            Tab(text: 'Crear cuenta'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _LoginTab(),
          _RegisterTab(),
        ],
      ),
    );
  }
}

// ── Tab de Login ──────────────────────────────────────────────────
class _LoginTab extends StatefulWidget {
  const _LoginTab();
  @override State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool  _showPass     = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.loginWithEmail(email, password);
    if (!mounted) return;

    if (ok && auth.mfaRequired) {
      // ignore: use_build_context_synchronously
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MfaScreen()));
      return;
    }

    if (ok && auth.isAuthenticated) {
      // Volver al root — _AppEntry en main.dart redirige a Home/Onboarding
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        _DebugInfoBox(
          '💡 Ingresa las credenciales de una cuenta creada en Firebase Console '
          'o usa el tab "Crear cuenta" para generar una nueva.',
        ),
        const SizedBox(height: 24),

        _Field(
          controller: _emailCtrl,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _passwordCtrl,
          label: 'Contraseña',
          icon: Icons.lock_outline,
          obscureText: !_showPass,
          suffix: IconButton(
            icon: Icon(
              _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: KoraColors.textSecondary),
            onPressed: () => setState(() => _showPass = !_showPass),
          ),
          onSubmit: (_) => _login(),
        ),

        const SizedBox(height: 20),

        if (auth.error != null) ...[
          _ErrorCard(auth.error!),
          const SizedBox(height: 14),
        ],

        _GradientButton(
          label: 'Entrar',
          icon: Icons.login_rounded,
          loading: auth.isLoading,
          onTap: _login,
        ),
      ]),
    );
  }
}

// ── Tab de Registro ───────────────────────────────────────────────
class _RegisterTab extends StatefulWidget {
  const _RegisterTab();
  @override State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final _nombreCtrl   = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool  _showPass     = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final nombre   = _nombreCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (nombre.isEmpty || email.isEmpty || password.isEmpty) return;

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.registerWithEmail(email, password, nombre);
    if (!mounted) return;

    if (ok && auth.mfaRequired) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MfaScreen()));
      return;
    }

    if (ok && auth.isAuthenticated) {
      // Registro exitoso → ir al root, _AppEntry lleva al onboarding
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        _DebugInfoBox(
          '🔧 Crea una cuenta de prueba. Se registra en Firebase y en Kora.\n'
          'El backend debe tener FIREBASE_WEB_API_KEY configurada en el .env.',
        ),
        const SizedBox(height: 24),

        _Field(
          controller: _nombreCtrl,
          label: 'Nombre completo',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _emailCtrl,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _passwordCtrl,
          label: 'Contraseña (mín. 6 caracteres)',
          icon: Icons.lock_outline,
          obscureText: !_showPass,
          suffix: IconButton(
            icon: Icon(
              _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: KoraColors.textSecondary),
            onPressed: () => setState(() => _showPass = !_showPass),
          ),
          onSubmit: (_) => _register(),
        ),

        const SizedBox(height: 20),

        if (auth.error != null) ...[
          _ErrorCard(auth.error!),
          const SizedBox(height: 14),
        ],

        _GradientButton(
          label: 'Crear cuenta y entrar',
          icon: Icons.person_add_outlined,
          loading: auth.isLoading,
          onTap: _register,
        ),
      ]),
    );
  }
}

// ── Widgets de apoyo ──────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? suffix;
  final ValueChanged<String>? onSubmit;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onSubmitted: onSubmit,
      style: const TextStyle(color: KoraColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: KoraColors.textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: KoraColors.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: KoraColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: KoraColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: loading ? null : KoraGradients.mainGradient,
          color: loading ? KoraColors.bgElevated : null,
          boxShadow: loading ? [] : [
            BoxShadow(
              color: KoraColors.primary.withOpacity(0.35),
              blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: loading
            ? const Center(child: SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Text(label, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KoraColors.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KoraColors.accent.withOpacity(0.35)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, size: 16, color: KoraColors.accent),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
          style: TextStyle(color: KoraColors.accent,
              fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _DebugInfoBox extends StatelessWidget {
  final String text;
  const _DebugInfoBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.25)),
      ),
      child: Text(text, style: TextStyle(
        color: const Color(0xFFFF9800).withOpacity(0.85),
        fontSize: 12, height: 1.6)),
    );
  }
}
