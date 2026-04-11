import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// شاشة إرسال تفاصيل العربون من الزبون
class DepositDetailsScreen extends StatefulWidget {
  final String bookingId;
  final String providerCreditCard; // قد يكون فارغاً
  final String itemName;
  final String price;

  const DepositDetailsScreen({
    super.key,
    required this.bookingId,
    required this.providerCreditCard,
    required this.itemName,
    required this.price,
  });

  @override
  State<DepositDetailsScreen> createState() => _DepositDetailsScreenState();
}

class _DepositDetailsScreenState extends State<DepositDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _last5Controller = TextEditingController();
  final _senderNameController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isLoading = false;
  String _resolvedCreditCard = '';
  bool _loadingCard = true;

  @override
  void initState() {
    super.initState();
    _resolveCreditCard();
    // ملء تاريخ اليوم تلقائياً عند فتح الصفحة
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  /// جلب رقم بطاقة المزود: أولاً من مستند الحجز، ثم مباشرة من users collection
  Future<void> _resolveCreditCard() async {
    // 1) إذا مررت مسبقاً، استخدمه
    if (widget.providerCreditCard.isNotEmpty) {
      setState(() {
        _resolvedCreditCard = widget.providerCreditCard;
        _loadingCard = false;
      });
      return;
    }

    try {
      // 2) اقرأ مستند الحجز للحصول على providerPhone / providerId
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();
      final data = bookingDoc.data() ?? {};

      // جرب الحقل المحفوظ أولاً
      final saved = data['providerCreditCard']?.toString() ?? '';
      if (saved.isNotEmpty) {
        setState(() {
          _resolvedCreditCard = saved;
          _loadingCard = false;
        });
        return;
      }

      // 3) جلب من users collection باستخدام providerPhone أو providerId
      final providerPhone =
          data['providerPhone']?.toString() ??
          data['providerId']?.toString() ??
          '';

      if (providerPhone.isNotEmpty) {
        // محاولة 1: doc ID مباشرة
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerPhone)
            .get();
        String card = userDoc.data()?['creditCard']?.toString() ?? '';

        // محاولة 2: where phone ==
        if (card.isEmpty) {
          final q = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: providerPhone)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            card = q.docs.first.data()['creditCard']?.toString() ?? '';
          }
        }

        // محاولة 3: published_providers
        if (card.isEmpty) {
          final pq = await FirebaseFirestore.instance
              .collection('published_providers')
              .where('providerPhone', isEqualTo: providerPhone)
              .limit(1)
              .get();
          if (pq.docs.isNotEmpty) {
            card = pq.docs.first.data()['creditCard']?.toString() ?? '';
          }
        }

        // حفظ في مستند الحجز حتى لا نحتاج للجلب مرة ثانية
        if (card.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(widget.bookingId)
              .update({'providerCreditCard': card});
        }

        setState(() {
          _resolvedCreditCard = card;
          _loadingCard = false;
        });
        return;
      }
    } catch (_) {}

    setState(() => _loadingCard = false);
  }

  @override
  void dispose() {
    _last5Controller.dispose();
    _senderNameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
            'status': 'deposit_submitted',
            'depositDetails': {
              'last5Digits': _last5Controller.text.trim(),
              'senderName': _senderNameController.text.trim(),
              'date': _dateController.text.trim(),
              'submittedAt': FieldValue.serverTimestamp(),
            },
          });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال تفاصيل العربون بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'تفاصيل العربون',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6E1229),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقة معلومات الخدمة والعربون
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6E1229), Color(0xFF2B0606)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'تفاصيل الخدمة',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.itemName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'السعر: ${widget.price}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // بطاقة رقم البطاقة
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6E1229).withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.credit_card,
                          color: Color(0xFF6E1229),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'رقم بطاقة المزود',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6E1229).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF6E1229).withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _loadingCard
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF6E1229),
                                    ),
                                  )
                                : Text(
                                    _resolvedCreditCard.isNotEmpty
                                        ? _resolvedCreditCard
                                        : 'غير محدد',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _resolvedCreditCard.isNotEmpty
                                          ? const Color(0xFF6E1229)
                                          : Colors.grey,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                          if (_resolvedCreditCard.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _resolvedCreditCard),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم نسخ رقم البطاقة'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.copy,
                                color: Color(0xFF6E1229),
                                size: 20,
                              ),
                              tooltip: 'نسخ الرقم',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // تنبيه: الإرسال عبر سوبر كي
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF1565C0).withOpacity(0.4),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.smartphone,
                            color: Color(0xFF1565C0),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'يجب إرسال مبلغ العربون عبر تطبيق سوبر كي فقط إلى الرقم أعلاه',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.amber,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'يجب إرسال عربون بنسبة 25% أو أكثر من السعر الأساسي',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // نموذج تفاصيل العربون
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: Color(0xFF6E1229),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'معلومات التحويل',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // آخر 5 أرقام من رقم الحركة
                    TextFormField(
                      controller: _last5Controller,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'آخر 5 أرقام من رقم الحركة',
                        hintText: 'مثال: 12345',
                        prefixIcon: const Icon(
                          Icons.tag,
                          color: Color(0xFF6E1229),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6E1229),
                            width: 2,
                          ),
                        ),
                        counterText: '',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'يرجى إدخال آخر 5 أرقام من رقم الحركة';
                        }
                        if (v.trim().length != 5) {
                          return 'يجب أن تكون 5 أرقام بالضبط';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // اسم المرسل
                    TextFormField(
                      controller: _senderNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'اسم المرسل',
                        hintText: 'اسمك الكامل',
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Color(0xFF6E1229),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6E1229),
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'يرجى إدخال اسم المرسل';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // التاريخ
                    TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'تاريخ التحويل',
                        hintText: 'مثال: 09/04/2026',
                        prefixIcon: const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF6E1229),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6E1229),
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'يرجى إدخال تاريخ التحويل';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // زر الإرسال
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6E1229),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, size: 22),
                  label: Text(
                    _isLoading ? 'جاري الإرسال...' : 'إرسال تفاصيل العربون',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
