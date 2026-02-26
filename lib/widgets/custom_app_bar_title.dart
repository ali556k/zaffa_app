import 'package:flutter/material.dart';

class CustomAppBarTitle extends StatelessWidget {
  final String title;
  final bool showZaffaLogo;
  const CustomAppBarTitle({
    super.key,
    required this.title,
    this.showZaffaLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // عنوان الصفحة في الوسط
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            foreground: Paint()
              ..shader = LinearGradient(
                colors: [
                  Color(0xFF8D2828),
                  Color(0xFF3A0A0A),
                ],
              ).createShader(Rect.fromLTWH(0, 0, 200, 70)),
            shadows: [
              Shadow(
                blurRadius: 8,
                color: Colors.black26,
                offset: Offset(0, 2),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        // عبارة "زفة" في أعلى اليمين
        if (showZaffaLogo)
          Positioned(
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0xFF8D2828),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'زفة',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black38,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
