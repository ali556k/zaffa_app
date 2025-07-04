import 'package:flutter/material.dart';

import 'main_screen.dart';


class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});


  @override
  Widget build(BuildContext context) {
    // ابدأ دائمًا من الواجهة الرئيسية بدون أي تحقق
    return const MainScreen();
  }
}
