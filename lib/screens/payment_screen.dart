import 'package:flutter/material.dart';

class PaymentScreen extends StatelessWidget {
  final double amount;
  final VoidCallback onPaymentSuccess;
  const PaymentScreen({super.key, required this.amount, required this.onPaymentSuccess});

  @override
  Widget build(BuildContext context) {
    // هذه الشاشة نموذجية، للدمج الفعلي مع بوابة دفع استخدم flutter_stripe أو بوابة محلية
    return Scaffold(
      appBar: AppBar(title: Text('الدفع الإلكتروني')),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('المبلغ المستحق:', style: TextStyle(fontSize: 20)),
            SizedBox(height: 12),
            Text('${amount.toStringAsFixed(2)} د.ع', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green[800])),
            SizedBox(height: 32),
            ElevatedButton.icon(
              icon: Icon(Icons.credit_card),
              label: Text('الدفع ببطاقة إلكترونية'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: TextStyle(fontSize: 18),
              ),
              onPressed: () {
                // هنا يتم استدعاء بوابة الدفع الفعلية
                // في هذا النموذج سنعتبر الدفع ناجح مباشرة
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('تم الدفع بنجاح!'),
                    content: Icon(Icons.check_circle, color: Colors.green, size: 60),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onPaymentSuccess();
                        },
                        child: Text('ok'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
