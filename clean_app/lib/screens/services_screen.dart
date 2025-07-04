
import 'dart:async';
import 'package:flutter/material.dart';
import 'service_items_screen.dart';
import '../widgets/custom_page_title.dart';


class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  _ServicesScreenState createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  DateTime? weddingDate;
  Duration remaining = Duration();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadWeddingDate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    if (weddingDate != null) {
      _updateCountdown();
      _timer = Timer.periodic(Duration(seconds: 1), (_) => _updateCountdown());
    }
  }

  void _updateCountdown() {
    setState(() {
      remaining = weddingDate!.difference(DateTime.now());
    });
  }

  Future<void> _loadWeddingDate() async {
    // تم حذف SharedPreferences نهائياً. إذا كنت بحاجة لتخزين بيانات استخدم flutter_secure_storage أو Firestore.
    // تم حذف استرجاع تاريخ الزفاف من التخزين المحلي. إذا كنت بحاجة للوظيفة استخدم Firestore أو flutter_secure_storage.
    setState(() {
      if (weddingDate != null) {
        remaining = weddingDate!.difference(DateTime.now());
      }
    });
    _startCountdown();
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 216, 208, 208),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            CustomPageTitle('الصفحة الرئيسية'),
            SizedBox(height: 18),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                children: [
                  _serviceImageButton('hall'),
                  _serviceImageButton('hotel'),
                  _serviceImageButton('restaurant'),
                  _serviceImageButton('bride_salon'),
                  _serviceImageButton('bride_dress'),
                  _serviceImageButton('salon_care'), 
                  _serviceImageButton('groom_suit'),
                  _serviceImageButton('groom_hamam'),
                  _serviceImageButton('car'),
                  _serviceImageButton('car_decoration'),
                  _serviceImageButton('honeymoon'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _serviceImageButton(String id) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceItemsScreen(
                serviceId: id,
                serviceName: '',
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: double.infinity,
            height: 180,
            child: Image.asset(
              'assets/$id.png',
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
      ),
    );
  }

  // تم حذف الدالة غير المستخدمة _formatDuration.
}
