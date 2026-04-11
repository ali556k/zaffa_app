import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// شاشة إيصال العربون للمزود (قابل للحفظ كصورة)
class DepositReceiptScreen extends StatefulWidget {
  final String bookingId;
  final String customerName;
  final String basePrice;
  final double depositAmount;
  final String? serialNumber;
  final String? itemName;

  const DepositReceiptScreen({
    super.key,
    required this.bookingId,
    required this.customerName,
    required this.basePrice,
    required this.depositAmount,
    this.serialNumber,
    this.itemName,
  });

  @override
  State<DepositReceiptScreen> createState() => _DepositReceiptScreenState();
}

class _DepositReceiptScreenState extends State<DepositReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSaving = false;

  double get _basePriceNum {
    final clean = widget.basePrice
        .replaceAll('د.ع', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
    return double.tryParse(clean) ?? 0.0;
  }

  double get _remaining => _basePriceNum - widget.depositAmount;

  String _fmt(double v) {
    final f = NumberFormat('#,###', 'ar');
    return '${f.format(v.abs())} د.ع';
  }

  Future<void> _saveAsImage() async {
    setState(() => _isSaving = true);
    try {
      final boundary =
          _receiptKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/receipt_${widget.bookingId}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'إيصال عربون - ${widget.customerName}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الإيصال: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'إيصال العربون',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6E1229),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveAsImage,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download, color: Colors.white),
            tooltip: 'حفظ كصورة',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // الإيصال القابل للتقاط
            RepaintBoundary(
              key: _receiptKey,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // رأس الإيصال
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6E1229), Color(0xFF2B0606)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'إيصال استلام العربون',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat(
                              'dd/MM/yyyy - HH:mm',
                              'ar',
                            ).format(DateTime.now()),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          if (widget.serialNumber != null &&
                              widget.serialNumber!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'رقم الإيصال: ${widget.serialNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildReceiptRow(
                            icon: Icons.person,
                            label: 'اسم الزبون',
                            value: widget.customerName,
                            iconColor: const Color(0xFF1E88E5),
                          ),
                          if (widget.itemName != null &&
                              widget.itemName!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildReceiptRow(
                              icon: Icons.store,
                              label: 'الخدمة',
                              value: widget.itemName!,
                              iconColor: const Color(0xFF6E1229),
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(),
                          ),
                          _buildReceiptRow(
                            icon: Icons.monetization_on,
                            label: 'المبلغ الأساسي للخدمة',
                            value: widget.basePrice.contains('د.ع')
                                ? widget.basePrice
                                : '${widget.basePrice} د.ع',
                            iconColor: const Color(0xFF6B7280),
                          ),
                          const SizedBox(height: 12),
                          _buildReceiptRow(
                            icon: Icons.payments,
                            label: 'العربون المستلم',
                            value: _fmt(widget.depositAmount),
                            iconColor: Colors.green,
                            valueColor: Colors.green,
                            bold: true,
                          ),
                          const SizedBox(height: 12),
                          _buildReceiptRow(
                            icon: Icons.account_balance_wallet,
                            label: 'المبلغ المتبقي',
                            value: _remaining >= 0
                                ? _fmt(_remaining)
                                : 'تجاوز المبلغ',
                            iconColor: _remaining >= 0
                                ? Colors.orange
                                : Colors.green,
                            valueColor: _remaining >= 0
                                ? Colors.orange
                                : Colors.green,
                            bold: true,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'تم تأكيد استلام العربون',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // زر الحفظ
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAsImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6E1229),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_alt, size: 22),
                label: Text(
                  _isSaving ? 'جاري الحفظ...' : 'حفظ الإيصال كصورة',
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
    );
  }

  Widget _buildReceiptRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }
}
