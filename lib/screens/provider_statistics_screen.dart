import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// لوحة الإحصائيات للمزودين
class ProviderStatisticsScreen extends StatefulWidget {
  final String providerId;
  final String providerName;

  const ProviderStatisticsScreen({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<ProviderStatisticsScreen> createState() =>
      _ProviderStatisticsScreenState();
}

class _ProviderStatisticsScreenState extends State<ProviderStatisticsScreen> {
  int _selectedPeriod = 1; // 0: شهر، 1: 6 أشهر، 2: سنة
  bool _isLoading = true;

  // إحصائيات
  int _totalBookings = 0;
  int _cancelledBookings = 0;
  double _cancellationRate = 0.0;
  Map<String, int> _bookingsByMonth = {};
  Map<String, int> _bookingsByDay = {};
  Map<String, int> _bookingsByItem = {};

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 0: // شهر واحد
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 1: // 6 أشهر
          startDate = DateTime(now.year, now.month - 5, 1);
          break;
        case 2: // سنة
          startDate = DateTime(now.year - 1, now.month, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month - 5, 1);
      }

      // جلب جميع الحجوزات في الفترة المحددة
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: widget.providerId)
          .where(
            'bookingDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .get();

      final allBookings = bookingsSnapshot.docs;
      final cancelledCount = allBookings
          .where((doc) => doc.data()['isCancelled'] == true)
          .length;

      // حساب الإحصائيات
      Map<String, int> byMonth = {};
      Map<String, int> byDay = {};
      Map<String, int> byItem = {};

      for (var doc in allBookings) {
        final data = doc.data();
        final bookingDate = (data['bookingDate'] as Timestamp).toDate();
        final isCancelled = data['isCancelled'] ?? false;

        if (!isCancelled) {
          // حسب الشهر
          final monthKey = DateFormat('yyyy-MM').format(bookingDate);
          byMonth[monthKey] = (byMonth[monthKey] ?? 0) + 1;

          // حسب اليوم من الأسبوع
          final dayName = _getDayName(bookingDate.weekday);
          byDay[dayName] = (byDay[dayName] ?? 0) + 1;

          // حسب الخدمة
          final itemName = data['itemName'] ?? 'غير محدد';
          byItem[itemName] = (byItem[itemName] ?? 0) + 1;
        }
      }

      setState(() {
        _totalBookings = allBookings.length;
        _cancelledBookings = cancelledCount;
        _cancellationRate = _totalBookings > 0
            ? (cancelledCount / _totalBookings) * 100
            : 0.0;
        _bookingsByMonth = byMonth;
        _bookingsByDay = byDay;
        _bookingsByItem = byItem;
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل الإحصائيات: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getDayName(int weekday) {
    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإحصائيات'),
        backgroundColor: const Color(0xFF6E1229),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B0000)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اختيار الفترة الزمنية
                  _buildPeriodSelector(),

                  const SizedBox(height: 24),

                  // بطاقات الإحصائيات السريعة
                  _buildQuickStats(),

                  const SizedBox(height: 24),

                  // رسم بياني للحجوزات الشهرية
                  _buildMonthlyChart(),

                  const SizedBox(height: 24),

                  // الأيام الأكثر حجزاً
                  _buildTopDays(),

                  const SizedBox(height: 24),

                  // الخدمات الأكثر طلباً
                  _buildTopItems(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPeriodButton('شهر', 0)),
          Expanded(child: _buildPeriodButton('6 أشهر', 1)),
          Expanded(child: _buildPeriodButton('سنة', 2)),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, int period) {
    final isSelected = _selectedPeriod == period;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedPeriod = period);
        _loadStatistics();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B0000) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'إجمالي الحجوزات',
            _totalBookings.toString(),
            Icons.event,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'الحجوزات الملغاة',
            _cancelledBookings.toString(),
            Icons.cancel,
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'معدل الإلغاء',
            '${_cancellationRate.toStringAsFixed(1)}%',
            Icons.trending_down,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    if (_bookingsByMonth.isEmpty) {
      return _buildEmptyChart('لا توجد بيانات للعرض');
    }

    final sortedEntries = _bookingsByMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Color(0xFF8B0000)),
              const SizedBox(width: 8),
              const Text(
                'الحجوزات الشهرية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    (sortedEntries
                                .map((e) => e.value)
                                .reduce((a, b) => a > b ? a : b) +
                            5)
                        .toDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final monthKey = sortedEntries[groupIndex].key;
                      final date = DateTime.parse('$monthKey-01');
                      final monthName = DateFormat(
                        'MMMM yyyy',
                        'ar',
                      ).format(date);
                      return BarTooltipItem(
                        '$monthName\n${rod.toY.toInt()} حجز',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= sortedEntries.length)
                          return const Text('');
                        final monthKey = sortedEntries[value.toInt()].key;
                        final date = DateTime.parse('$monthKey-01');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MMM', 'ar').format(date),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  sortedEntries.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: sortedEntries[index].value.toDouble(),
                        color: const Color(0xFF8B0000),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopDays() {
    if (_bookingsByDay.isEmpty) {
      return _buildEmptySection('لا توجد بيانات الأيام');
    }

    final sortedDays = _bookingsByDay.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFF8B0000)),
              const SizedBox(width: 8),
              const Text(
                'الأيام الأكثر حجزاً',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedDays.take(5).map((entry) {
            final percentage = (_totalBookings > 0)
                ? (entry.value / (_totalBookings - _cancelledBookings)) * 100
                : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${entry.value} حجز (${percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF8B0000),
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopItems() {
    if (_bookingsByItem.isEmpty) {
      return _buildEmptySection('لا توجد بيانات الخدمات');
    }

    final sortedItems = _bookingsByItem.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFC107)),
              const SizedBox(width: 8),
              const Text(
                'الخدمات الأكثر طلباً',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedItems.take(5).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percentage = (_totalBookings > 0)
                ? (item.value / (_totalBookings - _cancelledBookings)) * 100
                : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getRankColor(index),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.key,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.value} حجز (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 0:
        return const Color(0xFFFFD700); // ذهبي
      case 1:
        return const Color(0xFFC0C0C0); // فضي
      case 2:
        return const Color(0xFFCD7F32); // برونزي
      default:
        return const Color(0xFF8B0000); // عنابي
    }
  }

  Widget _buildEmptyChart(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
