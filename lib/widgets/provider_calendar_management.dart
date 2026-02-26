import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

/// Provider-facing calendar management widget
/// Allows providers to:
/// - View all bookings
/// - Cancel bookings
/// - Block specific days
/// - See booking details
class ProviderCalendarManagement extends StatefulWidget {
  final String providerId;
  final String itemId;

  const ProviderCalendarManagement({
    super.key,
    required this.providerId,
    required this.itemId,
  });

  @override
  State<ProviderCalendarManagement> createState() =>
      _ProviderCalendarManagementState();
}

class _ProviderCalendarManagementState
    extends State<ProviderCalendarManagement> {
  final BookingService _bookingService = BookingService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<BookingModel>> _bookingsMap = {};
  Map<DateTime, DayStatus> _dayStatusMap = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  /// Load bookings and statuses for the current month
  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);

    try {
      final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      // Load all bookings for the item
      final allBookings = await _bookingService
          .getItemBookings(widget.itemId)
          .first;

      // Group bookings by day
      Map<DateTime, List<BookingModel>> bookingsMap = {};
      for (var booking in allBookings) {
        final normalizedDate = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
        );

        if (normalizedDate.isAfter(
              firstDay.subtract(const Duration(days: 1)),
            ) &&
            normalizedDate.isBefore(lastDay.add(const Duration(days: 1)))) {
          bookingsMap.putIfAbsent(normalizedDate, () => []).add(booking);
        }
      }

      // Load day statuses
      Map<DateTime, DayStatus> statuses = {};
      for (int day = 1; day <= lastDay.day; day++) {
        final date = DateTime(_focusedDay.year, _focusedDay.month, day);
        final status = await _bookingService.getDayStatus(widget.itemId, date);
        statuses[DateTime(date.year, date.month, date.day)] = status;
      }

      setState(() {
        _bookingsMap = bookingsMap;
        _dayStatusMap = statuses;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading month data: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Get color for day based on status
  Color _getDayColor(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final status = _dayStatusMap[normalizedDay];

    switch (status) {
      case DayStatus.available:
        return Colors.green.shade100;
      case DayStatus.partiallyBooked:
        return Colors.yellow.shade200;
      case DayStatus.fullyBooked:
        return Colors.red.shade100;
      default:
        return Colors.transparent;
    }
  }

  /// Get number of bookings for a specific day
  int _getBookingCount(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _bookingsMap[normalizedDay]?.length ?? 0;
  }

  /// Handle day selection
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    final normalizedDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final bookings = _bookingsMap[normalizedDay] ?? [];

    if (bookings.isEmpty) {
      _showBlockDayDialog(selectedDay);
    } else {
      _showBookingsDialog(selectedDay, bookings);
    }
  }

  /// Show dialog to block a day
  Future<void> _showBlockDayDialog(DateTime day) async {
    final formattedDate = DateFormat('dd/MM/yyyy', 'ar').format(day);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حظر يوم $formattedDate', textAlign: TextAlign.right),
        content: const Text(
          'هل تريد حظر هذا اليوم ومنع الحجوزات فيه؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _blockDay(day);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حظر اليوم'),
          ),
        ],
      ),
    );
  }

  /// Block a specific day
  Future<void> _blockDay(DateTime day) async {
    setState(() => _isLoading = true);

    try {
      // Create a blocking booking
      final blockingBooking = BookingModel(
        id: '',
        itemId: widget.itemId,
        itemName: 'محظور', // Blocked day marker
        providerId: widget.providerId,
        providerName: 'مزود الخدمة',
        customerId: 'BLOCKED_BY_PROVIDER',
        customerName: 'محظور من قبل المزود',
        customerPhone: '',
        category: 'blocked', // Special category for blocked days
        bookingDate: day,
        dayStatus: DayStatus.fullyBooked,
        timeSlot: null,
        createdAt: DateTime.now(),
        notes: 'تم حظر هذا اليوم من قبل مزود الخدمة',
        isCancelled: false,
      );

      await _bookingService.createBooking(blockingBooking);

      if (mounted) {
        // تحديث فوري لحالة اليوم
        final normalizedDate = DateTime(day.year, day.month, day.day);
        setState(() {
          _dayStatusMap[normalizedDate] = DayStatus.fullyBooked;
          _bookingsMap[normalizedDate] = [blockingBooking];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حظر اليوم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        await _loadMonthData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حظر اليوم: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Show bookings dialog for a specific day
  Future<void> _showBookingsDialog(
    DateTime day,
    List<BookingModel> bookings,
  ) async {
    final formattedDate = DateFormat('dd/MM/yyyy', 'ar').format(day);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حجوزات يوم $formattedDate', textAlign: TextAlign.right),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: booking.category == 'blocked'
                        ? Colors.red
                        : const Color(0xFF8B0000),
                    child: Icon(
                      booking.category == 'blocked'
                          ? Icons.block
                          : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    booking.customerName.isEmpty
                        ? 'زبون'
                        : booking.customerName,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (booking.customerPhone.isNotEmpty)
                        Text(booking.customerPhone, textAlign: TextAlign.right),
                      if (booking.timeSlot != null)
                        Text(
                          '${booking.timeSlot!.startTime} - ${booking.timeSlot!.endTime}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        )
                      else
                        const Text(
                          'حجز يوم كامل',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.green),
                        ),
                      if (booking.notes != null && booking.notes!.isNotEmpty)
                        Text(
                          booking.notes!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  trailing: !booking.isCancelled
                      ? IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmCancelBooking(booking);
                          },
                        )
                      : const Chip(
                          label: Text('ملغى'),
                          backgroundColor: Colors.grey,
                        ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  /// Confirm booking cancellation
  Future<void> _confirmCancelBooking(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الحجز', textAlign: TextAlign.right),
        content: Text(
          'هل أنت متأكد من إلغاء حجز ${booking.customerName}؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('نعم، إلغاء الحجز'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelBooking(booking);
    }
  }

  /// Cancel a booking
  Future<void> _cancelBooking(BookingModel booking) async {
    setState(() => _isLoading = true);

    try {
      await _bookingService.cancelBooking(booking.id!, widget.providerId);

      if (mounted) {
        // تحديث فوري لحالة اليوم
        final normalizedDate = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
        );

        setState(() {
          // إزالة الحجز من القائمة
          if (_bookingsMap.containsKey(normalizedDate)) {
            _bookingsMap[normalizedDate]!.removeWhere(
              (b) => b.id == booking.id,
            );

            // تحديث حالة اليوم بناءً على الحجوزات المتبقية
            if (_bookingsMap[normalizedDate]!.isEmpty) {
              _dayStatusMap[normalizedDate] = DayStatus.available;
              _bookingsMap.remove(normalizedDate);
            } else {
              // إعادة حساب حالة اليوم
              final remainingBookings = _bookingsMap[normalizedDate]!;
              bool hasFullDay = remainingBookings.any(
                (b) => b.dayStatus == DayStatus.fullyBooked,
              );
              _dayStatusMap[normalizedDate] = hasFullDay
                  ? DayStatus.fullyBooked
                  : DayStatus.partiallyBooked;
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الحجز بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        await _loadMonthData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إلغاء الحجز: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الحجوزات'),
        backgroundColor: const Color(0xFF530405),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMonthData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // Legend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('متاح', Colors.green.shade100),
                _buildLegendItem('محجوز جزئياً', Colors.yellow.shade200),
                _buildLegendItem('محجوز بالكامل', Colors.red.shade100),
              ],
            ),
          ),

          // Statistics Card
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<List<BookingModel>>(
                stream: _bookingService.getItemBookings(widget.itemId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allBookings = snapshot.data!;
                  final activeBookings = allBookings
                      .where((b) => !b.isCancelled)
                      .length;
                  final cancelledBookings = allBookings
                      .where((b) => b.isCancelled)
                      .length;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('إجمالي الحجوزات', allBookings.length),
                      _buildStatItem('الحجوزات النشطة', activeBookings),
                      _buildStatItem('الحجوزات الملغاة', cancelledBookings),
                    ],
                  );
                },
              ),
            ),
          ),

          // Calendar
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B0000)),
                  )
                : TableCalendar(
                    firstDay: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: _onDaySelected,
                    onPageChanged: (focusedDay) {
                      setState(() => _focusedDay = focusedDay);
                      _loadMonthData();
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: const Color(0xFF8B0000).withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: Color(0xFF8B0000),
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final bookingCount = _getBookingCount(day);
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _getDayColor(day),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                              if (bookingCount > 0)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF8B0000),
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$bookingCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0000),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
