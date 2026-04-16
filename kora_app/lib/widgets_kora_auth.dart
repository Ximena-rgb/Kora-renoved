import 'package:flutter/material.dart';
import 'theme.dart';

/// Reusable input field following the Kora dark design system.
class KoraInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final String? error;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const KoraInputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.error,
    this.onChanged,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: KoraColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: error != null
                ? KoraColors.pass.withOpacity(0.5)
                : KoraColors.divider),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: const TextStyle(color: KoraColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: KoraColors.textHint, fontSize: 14),
            prefixIcon: Icon(icon, color: KoraColors.textHint, size: 20),
            suffixIcon: suffix,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(error!,
            style: const TextStyle(color: KoraColors.pass, fontSize: 12)),
        ),
    ]);
  }
}

/// Red error banner used below forms.
class KoraErrorBanner extends StatelessWidget {
  final String message;
  const KoraErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KoraColors.pass.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KoraColors.pass.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: KoraColors.pass, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
          style: const TextStyle(color: KoraColors.pass, fontSize: 13))),
      ]),
    );
  }
}

/// Full-width gradient action button.
class KoraGradientActionBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const KoraGradientActionBtn({
    super.key,
    required this.label,
    required this.loading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: KoraGradients.mainGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: KoraColors.primary.withOpacity(0.35),
                blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
