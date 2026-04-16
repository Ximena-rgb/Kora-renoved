import 'package:flutter/material.dart';

// ── Paleta Kora Dark ──────────────────────────────────────────────
class KoraColors {
  // Fondos
  static const bg           = Color(0xFF0A0A0F);
  static const bgCard       = Color(0xFF141419);
  static const bgElevated   = Color(0xFF1C1C24);
  static const surface      = Color(0xFF1C1C24);
  static const surfaceGrey  = Color(0xFF0A0A0F);
  static const cardBg       = Color(0xFF141419);

  // Primarios
  static const primary      = Color(0xFFE040FB);   // violeta brillante
  static const primaryLight = Color(0xFFEA80FC);
  static const primaryDark  = Color(0xFFAA00FF);

  // Acentos
  static const accent       = Color(0xFFFF2D55);   // rojo-rosa
  static const accentGold   = Color(0xFFFFD60A);

  // Gradiente principal
  static const gradientStart = Color(0xFFBF5AF2);
  static const gradientMid   = Color(0xFFE040FB);
  static const gradientEnd   = Color(0xFFFF2D55);

  // Texto
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8E8E9A);
  static const textHint      = Color(0xFF4A4A58);
  static const divider       = Color(0xFF242430);

  // Estado
  static const like      = Color(0xFF30D158);
  static const pass      = Color(0xFFFF2D55);
  static const superlike = Color(0xFFFFD60A);
  static const match     = Color(0xFFE040FB);

  // Score
  static const scoreHigh = Color(0xFF30D158);
  static const scoreMid  = Color(0xFFFFD60A);
  static const scoreLow  = Color(0xFFFF2D55);
}

class KoraGradients {
  static const mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [KoraColors.gradientStart, KoraColors.gradientMid, KoraColors.gradientEnd],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xEE000000)],
    stops: [0.3, 1.0],
  );

  static const subtleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C1830), Color(0xFF1A0A20)],
  );

  static const glowPurple = RadialGradient(
    colors: [Color(0x40E040FB), Color(0x00E040FB)],
    radius: 1.0,
  );
}

class KoraTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: KoraColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary:   KoraColors.primary,
      secondary: KoraColors.accent,
      surface:   KoraColors.surface,
      onSurface: KoraColors.textPrimary,
    ),
    scaffoldBackgroundColor: KoraColors.bg,
    fontFamily: 'sans-serif',

    appBarTheme: const AppBarTheme(
      backgroundColor: KoraColors.bg,
      foregroundColor: KoraColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: KoraColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KoraColors.bgCard,
      indicatorColor: KoraColors.primary.withOpacity(0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: KoraColors.primary, fontWeight: FontWeight.w700, fontSize: 10);
        }
        return const TextStyle(color: KoraColors.textHint, fontSize: 10);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: KoraColors.primary, size: 22);
        }
        return const IconThemeData(color: KoraColors.textHint, size: 22);
      }),
    ),

    cardTheme: CardThemeData(
      color: KoraColors.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: KoraColors.divider, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KoraColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KoraColors.primary,
        side: const BorderSide(color: KoraColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KoraColors.bgElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: KoraColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: KoraColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: KoraColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: KoraColors.textSecondary),
      hintStyle: const TextStyle(color: KoraColors.textHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: KoraColors.primary.withOpacity(0.12),
      selectedColor: KoraColors.primary.withOpacity(0.25),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KoraColors.primary),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: KoraColors.primary.withOpacity(0.3)),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: KoraColors.divider, thickness: 1, space: 1,
    ),
  );
}

// ── Widgets reutilizables ─────────────────────────────────────────
class KoraButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final Color? color;
  final IconData? icon;

  const KoraButton({
    super.key, required this.label,
    this.onPressed, this.loading = false,
    this.outlined = false, this.color, this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = loading
        ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : icon != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18), const SizedBox(width: 8), Text(label),
              ])
            : Text(label);

    if (outlined) {
      return OutlinedButton(onPressed: loading ? null : onPressed, child: child);
    }
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: color != null
          ? ElevatedButton.styleFrom(backgroundColor: color)
          : null,
      child: child,
    );
  }
}

class KoraGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;

  const KoraGradientButton({
    super.key, required this.label,
    this.onPressed, this.loading = false, this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: KoraGradients.mainGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: KoraColors.primary.withOpacity(0.4),
              blurRadius: 24, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 10)],
                  Text(label, style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  )),
                ]),
        ),
      ),
    );
  }
}

// Score color helper
Color scoreColor(double score) {
  if (score >= 75) return KoraColors.scoreHigh;
  if (score >= 50) return KoraColors.scoreMid;
  return KoraColors.scoreLow;
}
