import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'provider_auth.dart';
import 'screen_discovery.dart';
import 'screen_chat_list.dart';
import 'screen_plans.dart';
import 'screen_profile.dart';
import 'widget_estado_boton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  final _screens = const [
    DiscoveryScreen(),
    ChatListScreen(),
    PlansScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoraColors.bg,
      body: Column(children: [
        // ── Barra de estado global ─────────────────────────────────
        SafeArea(
          bottom: false,
          child: Container(
            color: KoraColors.bgCard,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              // Logo
              ShaderMask(
                shaderCallback: (b) => KoraGradients.mainGradient.createShader(b),
                child: const Text('KORA',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 1)),
              ),
              const Spacer(),
              // Botón de estado + ubicación
              const EstadoBoton(),
            ]),
          ),
        ),
        const Divider(height: 1, color: KoraColors.divider),
        Expanded(child: IndexedStack(index: _tab, children: _screens)),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: KoraColors.bgCard,
          border: const Border(top: BorderSide(color: KoraColors.divider, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Descubrir',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Planes',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
