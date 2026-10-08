import 'package:flutter/material.dart';
import 'screens/hark_home_screen.dart';

void main() {
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
        scaffoldBackgroundColor: const Color(0xFF0D0D11),
        fontFamily: 'SF Pro Display',
      ),
      home: const HarkHomeScreen(),
    );
  }
}
