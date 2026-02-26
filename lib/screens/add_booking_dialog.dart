import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddBookingDialog extends StatefulWidget {
  final DateTime selectedDay;
  final Map<String, dynamic> item;
  final VoidCallback onBookingAdded;

  const AddBookingDialog({
    super.key,
    required this.selectedDay,
    required this.item,
    required this.onBookingAdded,
  });

  @override
  State<AddBookingDialog> createState() => _AddBookingDialogState();
}

class _AddBookingDialogState extends State<AddBookingDialog> {
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  bool isFullDay = true;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B73FF), Color(0xFF000DFF)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              'حجز جديد',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            _buildTextField(
              controller: customerNameController,
              label: 'اسم العميل',
              icon: Icons.person,
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: customerPhoneController,
              label: 'رقم الهاتف',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نوع الحجز',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: Text('full_day'),
                          value: true,
                          groupValue: isFullDay,
                          onChanged: (value) {
                            setState(() {
                              isFullDay = value!;
                            });
                          },
                          activeColor: Color(0xFF6B73FF),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: Text('partial'),
                          value: false,
                          groupValue: isFullDay,
                          onChanged: (value) {
                            setState(() {
                              isFullDay = value!;
                            });
                          },
                          activeColor: Color(0xFF6B73FF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isFullDay) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeSelector(
                      label: 'من',
                      time: startTime,
                      onTimeSelected: (time) {
                        setState(() {
                          startTime = time;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeSelector(
                      label: 'إلى',
                      time: endTime,
                      onTimeSelected: (time) {
                        setState(() {
                          endTime = time;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 16),
            _buildTextField(
              controller: notesController,
              label: 'ملاحظات (اختياري)',
              icon: Icons.note,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إلغاء', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _saveBooking,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6B73FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('حفظ', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Color(0xFF6B73FF)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required TimeOfDay? time,
    required Function(TimeOfDay) onTimeSelected,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ListTile(
        title: Text(label),
        subtitle: Text(
          time != null ? time.format(context) : 'اختر الوقت',
          style: TextStyle(
            color: time != null ? Colors.black : Colors.grey[500],
          ),
        ),
        leading: Icon(Icons.access_time, color: Color(0xFF6B73FF)),
        onTap: () async {
          final selectedTime = await showTimePicker(
            context: context,
            initialTime: time ?? TimeOfDay.now(),
          );
          if (selectedTime != null) {
            onTimeSelected(selectedTime);
          }
        },
      ),
    );
  }

  Future<void> _saveBooking() async {
    if (customerNameController.text.isEmpty ||
        customerPhoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى ملء جميع الحقول المطلوبة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!isFullDay && (startTime == null || endTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى تحديد أوقات الحجز'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('item_bookings').add({
        'itemId': widget.item['id'],
        'providerId': widget.item['providerId'],
        'customerName': customerNameController.text,
        'customerPhone': customerPhoneController.text,
        'date': Timestamp.fromDate(widget.selectedDay),
        'isFullDay': isFullDay,
        'startTime': !isFullDay ? startTime!.format(context) : null,
        'endTime': !isFullDay ? endTime!.format(context) : null,
        'notes': notesController.text,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة الحجز بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onBookingAdded();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إضافة الحجز: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}
