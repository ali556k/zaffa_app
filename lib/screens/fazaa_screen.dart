import 'package:flutter/material.dart';
import '../widgets/custom_page_title.dart';

class FazaaScreen extends StatefulWidget {
  const FazaaScreen({super.key});

  @override
  State<FazaaScreen> createState() => _FazaaScreenState();
}

class _FazaaScreenState extends State<FazaaScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromARGB(255, 216, 208, 208),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            CustomPageTitle('فزعة'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        size: 120,
                        color: const Color(0xFFB46A6A).withOpacity(0.5),
                      ),
                      SizedBox(height: 32),
                      Text(
                        'عروض جاهزة للأعراس',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3748),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'احصل على باقات متكاملة تشمل',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 48),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB46A6A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFB46A6A).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: const Color(0xFFB46A6A),
                              size: 28,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'العروض قيد التحضير وستتوفر قريباً',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: const Color(0xFF2D3748),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
