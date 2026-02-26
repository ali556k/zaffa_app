import 'package:flutter/material.dart';

class CustomPageTitle extends StatelessWidget {
  final String title;
  const CustomPageTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    // توحيد ارتفاع العنوان كما في صفحة يوم الزفاف
    final double topPadding = MediaQuery.of(context).padding.top + 32;
    return Container(
      margin: EdgeInsets.only(top: topPadding, bottom: 20),
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.white.withOpacity(0.95)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 5),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 22,
          color: Color(0xFF8B4513),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          height: 1.2,
          fontFamily: 'Cairo',
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.1),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
