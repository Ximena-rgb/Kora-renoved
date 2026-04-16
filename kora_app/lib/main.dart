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

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await context.read<AuthProvider>().tryRestoreSession();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Container(
          color: KoraColors.bg,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('KORA',
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 6)),
                SizedBox(height: 24),
                CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ],
            ),
          ),
        ),
      );
    }

    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated)  return const LoginScreen();
    if (auth.needsOnboarding)   return const OnboardingScreen();
    return const HomeScreen();
  }
}
