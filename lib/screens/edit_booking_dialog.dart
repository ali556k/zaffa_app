import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditBookingDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onBookingUpdated;

  const EditBookingDialog({
    super.key,
    required this.booking,
    required this.onBookingUpdated,
  });

  @override
  State<EditBookingDialog> createState() => _EditBookingDialogState();
}

class _EditBookingDialogState extends State<EditBookingDialog> {
  late TextEditingController customerNameController;
  late TextEditingController customerPhoneController;
  late TextEditingController notesController;

  late bool isFullDay;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool isLoading = false;
  String status = 'confirmed';

  @override
  void initState() {
    super.initState();
    customerNameController = TextEditingController(
      text: widget.booking['customerName'] ?? '',
    );
    customerPhoneController = TextEditingController(
      text: widget.booking['customerPhone'] ?? '',
    );
    notesController = TextEditingController(
      text: widget.booking['notes'] ?? '',
    );

    isFullDay = widget.booking['isFullDay'] ?? true;
    status = widget.booking['status'] ?? 'confirmed';

    if (!isFullDay) {
      if (widget.booking['startTime'] != null) {
        final startTimeParts = widget.booking['startTime'].split(':');
        startTime = TimeOfDay(
          hour: int.parse(startTimeParts[0]),
          minute: int.parse(startTimeParts[1]),
        );
      }
      if (widget.booking['endTime'] != null) {
        final endTimeParts = widget.booking['endTime'].split(':');
        endTime = TimeOfDay(
          hour: int.parse(endTimeParts[0]),
          minute: int.parse(endTimeParts[1]),
        );
      }
    }
  }

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
            Icon(Icons.edit, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              'تعديل الحجز',
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
                    'حالة الحجز',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'confirmed',
                        child: Text('status_confirmed'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('status_pending'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('status_cancelled'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        status = value!;
                      });
                    },
                  ),
                ],
              ),
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
          onPressed: isLoading ? null : _updateBooking,
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
              : Text('تحديث', style: TextStyle(color: Colors.white)),
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

  Future<void> _updateBooking() async {
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
      await FirebaseFirestore.instance
          .collection('item_bookings')
          .doc(widget.booking['id'])
          .update({
            'customerName': customerNameController.text,
            'customerPhone': customerPhoneController.text,
            'isFullDay': isFullDay,
            'startTime': !isFullDay ? startTime!.format(context) : null,
            'endTime': !isFullDay ? endTime!.format(context) : null,
            'notes': notesController.text,
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('booking_updated'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onBookingUpdated();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحديث الحجز: $e'),
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
