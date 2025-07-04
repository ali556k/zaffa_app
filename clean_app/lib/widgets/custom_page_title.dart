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
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          color: Color(0xFFB46A6A),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
