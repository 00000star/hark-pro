import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/hark_models.dart';
import 'widgets/living_sky_background.dart';
import 'screens/hark_home_screen.dart';
import 'screens/chat_agent_screen.dart';
import 'screens/vault_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const HarkProApp());
}

class HarkProApp extends StatelessWidget {
  const HarkProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hark Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08090E),
        primaryColor: const Color(0xFF0A84FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0A84FF),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF141724),
        ),
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white, letterSpacing: -0.1),
        ),
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  HarkTask? _taskToExecuteFromChat;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onExecuteTaskFromChat(HarkTask task) {
    setState(() {
      _taskToExecuteFromChat = task;
      _currentIndex = 0; // Switch to Home dashboard
    });
  }

  @override
  Widget build(BuildContext context) {
    return LivingSkyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Screen View
            IndexedStack(
              index: _currentIndex,
              children: [
                HarkHomeScreen(
                  onOpenVault: () => _navigateToTab(2),
                  onOpenChat: () => _navigateToTab(1),
                  externalActiveTask: _taskToExecuteFromChat,
                ),
                ChatAgentScreen(
                  onExecuteTask: _onExecuteTaskFromChat,
                ),
                const VaultScreen(),
              ],
            ),

            // Floating Bottom Glass Pill Bar
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: _buildFloatingGlassPillBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingGlassPillBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF121420).withOpacity(0.82),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.14),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.dashboard_rounded,
                label: "Dashboard",
                activeColor: const Color(0xFF0A84FF),
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.auto_awesome_rounded,
                label: "Hark Agent",
                activeColor: const Color(0xFF00E5FF),
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.shield_rounded,
                label: "Vault",
                activeColor: const Color(0xFF30D158),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _navigateToTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? activeColor.withOpacity(0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : Colors.white54,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
