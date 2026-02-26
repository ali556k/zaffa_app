import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingManagementScreen extends StatefulWidget {
  final String providerId;
  final String itemId;
  final String itemName;

  const BookingManagementScreen({
    super.key,
    required this.providerId,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<BookingManagementScreen> createState() =>
      _BookingManagementScreenState();
}

class _BookingManagementScreenState extends State<BookingManagementScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  List<String> _unavailableDates = [];
  Map<String, List<String>> _bookedTimeSlots =
      {}; // يوم -> قائمة الساعات المحجوزة
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _loadUnavailableDates();
    _loadBookedTimeSlots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة أوقات ${widget.itemName}'),
        backgroundColor: Color(0xFF6B73FF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // شرح للمزود
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF6B73FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF6B73FF).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFF6B73FF),
                        size: 24,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'انقر على الأيام لإدارة الحجوزات (يوم كامل أو أوقات محددة)',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B73FF),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem(Colors.red, 'محجوز'),
                          SizedBox(width: 15),
                          _buildLegendItem(Colors.orange, 'جزئي'),
                          SizedBox(width: 15),
                          _buildLegendItem(Colors.green, 'متاح'),
                        ],
                      ),
                    ],
                  ),
                ),

                // التقويم
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TableCalendar<String>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.saturday,
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        weekendTextStyle: TextStyle(color: Colors.grey[700]),
                        holidayTextStyle: TextStyle(color: Colors.grey[700]),
                        selectedDecoration: BoxDecoration(
                          color: Color(0xFF6B73FF),
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Color(0xFF6B73FF).withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B73FF),
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: Color(0xFF6B73FF),
                          size: 28,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: Color(0xFF6B73FF),
                          size: 28,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          return _buildDayCell(day);
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          return _buildDayCell(day, isSelected: true);
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return _buildDayCell(day, isToday: true);
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _showBookingOptionsDialog(selectedDay);
                      },
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                    ),
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B73FF),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(
    DateTime day, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    final dateString = _formatDateForFirebase(day);
    final isUnavailable = _unavailableDates.contains(dateString);
    final bookedSlots = _bookedTimeSlots[dateString] ?? [];
    final hasPartialBooking = bookedSlots.isNotEmpty;

    Color borderColor = Colors.green; // متاح
    Color dotColor = Colors.green;

    if (isUnavailable) {
      borderColor = Colors.red; // محجوز كاملاً
      dotColor = Colors.red;
    } else if (hasPartialBooking) {
      borderColor = Colors.orange; // محجوز جزئياً
      dotColor = Colors.orange;
    }

    return Container(
      margin: EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? Color(0xFF6B73FF)
            : isToday
            ? Color(0xFF6B73FF).withOpacity(0.5)
            : Colors.transparent,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: isSelected || isToday ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          if (hasPartialBooking && !isUnavailable)
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${bookedSlots.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateForFirebase(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _loadUnavailableDates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.itemId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['unavailableDates'] != null) {
          setState(() {
            _unavailableDates = List<String>.from(data['unavailableDates']);
          });
        }
      }
    } catch (e) {
      print('خطأ في تحميل البيانات: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل البيانات'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleDayAvailability(DateTime day) async {
    final dateString = _formatDateForFirebase(day);
    final isCurrentlyUnavailable = _unavailableDates.contains(dateString);

    List<String> updatedDates = List<String>.from(_unavailableDates);

    if (isCurrentlyUnavailable) {
      updatedDates.remove(dateString);
    } else {
      updatedDates.add(dateString);
    }

    try {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.itemId)
          .set({'unavailableDates': updatedDates}, SetOptions(merge: true));

      setState(() {
        _unavailableDates = updatedDates;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCurrentlyUnavailable
                ? 'تم تحديد اليوم كمتاح'
                : 'تم تحديد اليوم كمحجوز',
          ),
          backgroundColor: isCurrentlyUnavailable ? Colors.green : Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('خطأ في تحديث البيانات: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حفظ التغييرات'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadBookedTimeSlots() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.itemId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['bookedTimeSlots'] != null) {
          setState(() {
            _bookedTimeSlots = Map<String, List<String>>.from(
              data['bookedTimeSlots'].map(
                (key, value) => MapEntry(key, List<String>.from(value)),
              ),
            );
          });
        }
      }
    } catch (e) {
      print('خطأ في تحميل الأوقات المحجوزة: $e');
    }
  }

  Future<void> _showBookingOptionsDialog(DateTime day) async {
    final dateString = _formatDateForFirebase(day);
    final isUnavailable = _unavailableDates.contains(dateString);
    final bookedSlots = _bookedTimeSlots[dateString] ?? [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'إدارة حجوزات ${day.day}/${day.month}/${day.year}',
            style: TextStyle(color: Color(0xFF6B73FF)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // حالة اليوم الحالية
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getDayStatusColor(
                    isUnavailable,
                    bookedSlots,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getDayStatusColor(isUnavailable, bookedSlots),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getDayStatusIcon(isUnavailable, bookedSlots),
                      color: _getDayStatusColor(isUnavailable, bookedSlots),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _getDayStatusText(isUnavailable, bookedSlots),
                      style: TextStyle(
                        color: _getDayStatusColor(isUnavailable, bookedSlots),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // الخيارات
              if (!isUnavailable) ...[
                ListTile(
                  leading: Icon(Icons.schedule, color: Colors.orange),
                  title: Text('حجز أوقات محددة'),
                  subtitle: Text('اختيار ساعات معينة من اليوم'),
                  onTap: () {
                    Navigator.pop(context);
                    _showTimeSlotDialog(day);
                  },
                ),
                Divider(),
              ],

              ListTile(
                leading: Icon(
                  isUnavailable ? Icons.check_circle : Icons.block,
                  color: isUnavailable ? Colors.green : Colors.red,
                ),
                title: Text(
                  isUnavailable ? 'إلغاء حجز اليوم كاملاً' : 'حجز اليوم كاملاً',
                ),
                subtitle: Text(
                  isUnavailable
                      ? 'جعل اليوم متاحاً بالكامل'
                      : 'منع أي حجوزات في هذا اليوم',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleDayAvailability(day);
                },
              ),

              if (bookedSlots.isNotEmpty && !isUnavailable) ...[
                Divider(),
                ListTile(
                  leading: Icon(Icons.clear_all, color: Colors.orange),
                  title: Text('إلغاء جميع الحجوزات الجزئية'),
                  subtitle: Text('حذف جميع الأوقات المحجوزة'),
                  onTap: () {
                    Navigator.pop(context);
                    _clearTimeSlots(day);
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTimeSlotDialog(DateTime day) async {
    // final dateString = _formatDateForFirebase(day);
    // final currentBookedSlots = List<String>.from(_bookedTimeSlots[dateString] ?? []);

    // متغيرات للتحكم في الأوقات المختارة
    int fromHour = 8;
    int toHour = 10;
    String fromPeriod = 'صباحاً';
    String toPeriod = 'صباحاً';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'تحديد الأوقات المحجوزة',
                style: TextStyle(color: Color(0xFF6B73FF), fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'حدد الفترة الزمنية المحجوزة:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 20),

                    // من الساعة
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF6B73FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(0xFF6B73FF).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'من الساعة:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B73FF),
                            ),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // اختيار الساعة (من)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFF6B73FF)),
                                ),
                                child: DropdownButton<int>(
                                  value: fromHour,
                                  underline: SizedBox(),
                                  items: List.generate(12, (index) {
                                    int hour = index + 1;
                                    return DropdownMenuItem(
                                      value: hour,
                                      child: Text(
                                        '$hour',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    );
                                  }),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      fromHour = value!;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 15),
                              // اختيار صباحاً أم مساءً (من)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFF6B73FF)),
                                ),
                                child: DropdownButton<String>(
                                  value: fromPeriod,
                                  underline: SizedBox(),
                                  items: ['صباحاً', 'مساءً'].map((period) {
                                    return DropdownMenuItem(
                                      value: period,
                                      child: Text(
                                        period,
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      fromPeriod = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // إلى الساعة
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'إلى الساعة:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // اختيار الساعة (إلى)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: DropdownButton<int>(
                                  value: toHour,
                                  underline: SizedBox(),
                                  items: List.generate(12, (index) {
                                    int hour = index + 1;
                                    return DropdownMenuItem(
                                      value: hour,
                                      child: Text(
                                        '$hour',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    );
                                  }),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      toHour = value!;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 15),
                              // اختيار صباحاً أم مساءً (إلى)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: DropdownButton<String>(
                                  value: toPeriod,
                                  underline: SizedBox(),
                                  items: ['صباحاً', 'مساءً'].map((period) {
                                    return DropdownMenuItem(
                                      value: period,
                                      child: Text(
                                        period,
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      toPeriod = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // عرض الفترة المختارة
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'الفترة المحجوزة: من $fromHour $fromPeriod إلى $toHour $toPeriod',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    String timeSlot =
                        'من $fromHour $fromPeriod إلى $toHour $toPeriod';
                    _updateSimpleTimeSlot(day, timeSlot);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6B73FF),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'حفظ',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateSimpleTimeSlot(DateTime day, String timeSlot) async {
    final dateString = _formatDateForFirebase(day);

    try {
      Map<String, List<String>> updatedTimeSlots =
          Map<String, List<String>>.from(_bookedTimeSlots);

      // حفظ الفترة الزمنية كعنصر واحد
      updatedTimeSlots[dateString] = [timeSlot];

      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.itemId)
          .set({'bookedTimeSlots': updatedTimeSlots}, SetOptions(merge: true));

      setState(() {
        _bookedTimeSlots = updatedTimeSlots;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث الأوقات المحجوزة بنجاح\n$timeSlot'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('خطأ في تحديث الأوقات: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حفظ التغييرات'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearTimeSlots(DateTime day) async {
    final dateString = _formatDateForFirebase(day);

    try {
      Map<String, List<String>> updatedTimeSlots =
          Map<String, List<String>>.from(_bookedTimeSlots);
      updatedTimeSlots.remove(dateString);

      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.itemId)
          .set({'bookedTimeSlots': updatedTimeSlots}, SetOptions(merge: true));

      setState(() {
        _bookedTimeSlots = updatedTimeSlots;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف جميع الأوقات المحجوزة'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('خطأ في حذف الأوقات: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حفظ التغييرات'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getDayStatusColor(bool isUnavailable, List<String> bookedSlots) {
    if (isUnavailable) return Colors.red;
    if (bookedSlots.isNotEmpty) return Colors.orange;
    return Colors.green;
  }

  IconData _getDayStatusIcon(bool isUnavailable, List<String> bookedSlots) {
    if (isUnavailable) return Icons.block;
    if (bookedSlots.isNotEmpty) return Icons.schedule;
    return Icons.check_circle;
  }

  String _getDayStatusText(bool isUnavailable, List<String> bookedSlots) {
    if (isUnavailable) return 'محجوز كاملاً';
    if (bookedSlots.isNotEmpty) {
      return 'محجوز جزئياً (${bookedSlots.length} أوقات)';
    }
    return 'متاح';
  }
}
