import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class CustomerBookingCalendar extends StatefulWidget {
  final String itemId;
  final String itemName;
  final String providerId;
  final Map<String, dynamic> item;

  const CustomerBookingCalendar({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.providerId,
    required this.item,
  });

  @override
  State<CustomerBookingCalendar> createState() =>
      _CustomerBookingCalendarState();
}

class _CustomerBookingCalendarState extends State<CustomerBookingCalendar> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  List<String> _unavailableDates = [];
  Map<String, List<String>> _bookedTimeSlots = {};
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _loadUnavailableDates();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('أوقات ${widget.itemName} المتاحة'),
        backgroundColor: Color(0xFF6B73FF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // شرح للعميل
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.green, size: 24),
                      SizedBox(height: 8),
                      Text(
                        'اختر يوماً متاحاً للحجز',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem(Colors.red, 'محجوز'),
                          SizedBox(width: 20),
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
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TableCalendar<String>(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(Duration(days: 365)),
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'شهر',
                      },
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        weekendTextStyle: TextStyle(color: Colors.grey[700]),
                        defaultTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Color(0xFF6B73FF),
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Color(0xFF6B73FF).withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        disabledDecoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        disabledTextStyle: TextStyle(color: Colors.white),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          return _buildDayCell(day, false, false);
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          return _buildDayCell(day, true, false);
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return _buildDayCell(day, false, true);
                        },
                        disabledBuilder: (context, day, focusedDay) {
                          return _buildDisabledDayCell(day);
                        },
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 20,
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
                      enabledDayPredicate: (day) {
                        final dayKey =
                            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                        return !_unavailableDates.contains(dayKey);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        final dayKey =
                            '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';

                        if (!_unavailableDates.contains(dayKey)) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                          _showBookingDialog(selectedDay);
                        }
                      },
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDayCell(DateTime day, bool isSelected, bool isToday) {
    final dayKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final isUnavailable = _unavailableDates.contains(dayKey);

    Color backgroundColor;
    Color textColor;

    if (isUnavailable) {
      backgroundColor = Colors.red.withOpacity(0.7);
      textColor = Colors.white;
    } else if (isSelected) {
      backgroundColor = Color(0xFF6B73FF);
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = Color(0xFF6B73FF).withOpacity(0.3);
      textColor = Color(0xFF6B73FF);
    } else {
      backgroundColor = Colors.green.withOpacity(0.7);
      textColor = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDisabledDayCell(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.7),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _setupRealtimeListener() {
    _subscription = FirebaseFirestore.instance
        .collection('services')
        .doc(widget.itemId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;

            // تحديث الأيام غير المتاحة
            if (data.containsKey('unavailableDates')) {
              final dates = List<String>.from(data['unavailableDates'] ?? []);
              setState(() {
                _unavailableDates = dates;
              });
            }

            // تحديث الأوقات المحجوزة
            if (data.containsKey('bookedTimeSlots')) {
              setState(() {
                _bookedTimeSlots = Map<String, List<String>>.from(
                  data['bookedTimeSlots'].map(
                    (key, value) => MapEntry(key, List<String>.from(value)),
                  ),
                );
              });
            }
          }
        });
  }

  Future<void> _loadUnavailableDates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('services')
          .doc(widget.itemId);

      final doc = await docRef.get();

      if (doc.exists && doc.data()!.containsKey('unavailableDates')) {
        final dates = List<String>.from(doc.data()!['unavailableDates'] ?? []);
        setState(() {
          _unavailableDates = dates;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل البيانات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showBookingDialog(DateTime selectedDay) {
    final dateString =
        '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';
    final bookedSlots = _bookedTimeSlots[dateString] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حجز ${widget.itemName}',
          style: TextStyle(color: Color(0xFF6B73FF)),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التاريخ: ${selectedDay.day}/${selectedDay.month}/${selectedDay.year}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B73FF),
                ),
              ),
              SizedBox(height: 16),

              if (bookedSlots.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'الأوقات المحجوزة:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ...bookedSlots.map(
                        (slot) => Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $slot',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'يمكنك الحجز في الأوقات المتاحة فقط:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 12),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'اليوم متاح بالكامل للحجز',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // خيارات الحجز
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showTimeSelectionDialog(selectedDay);
                  },
                  icon: Icon(Icons.schedule, color: Colors.white),
                  label: Text(
                    'اختيار وقت محدد',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6B73FF),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _processBooking(selectedDay, 'اليوم كاملاً');
                  },
                  icon: Icon(Icons.today, color: Colors.white),
                  label: Text(
                    'حجز اليوم كاملاً',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _showTimeSelectionDialog(DateTime selectedDay) {
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
                'اختيار الوقت',
                style: TextStyle(color: Color(0xFF6B73FF), fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'حدد الوقت المطلوب للحجز:',
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

                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'الوقت المطلوب: من $fromHour $fromPeriod إلى $toHour $toPeriod',
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
                    _processBooking(selectedDay, timeSlot);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6B73FF),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'تأكيد الحجز',
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

  void _processBooking(DateTime selectedDay, String timeSlot) {
    // هنا يمكن إضافة معالجة الحجز الفعلية
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تأكيد الحجز ليوم ${selectedDay.day}/${selectedDay.month}/${selectedDay.year}\n'
          'الوقت: $timeSlot',
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
