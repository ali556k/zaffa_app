import 'package:cloud_firestore/cloud_firestore.dart';

/// حالة اليوم في التقويم
enum DayStatus {
  available,    // متاح للحجز (أخضر)
  partiallyBooked, // محجوز جزئياً (أصفر)
  fullyBooked,  // محجوز بالكامل (أحمر)
}

/// فترة زمنية محددة في اليوم
class TimeSlot {
  final String startTime; // صيغة HH:mm مثل "14:00"
  final String endTime;   // صيغة HH:mm مثل "18:00"

  TimeSlot({
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
    );
  }

  @override
  String toString() => '$startTime - $endTime';
}

/// نموذج الحجز
class BookingModel {
  final String? id;              // معرف الحجز في Firestore
  final String itemId;           // معرف العنصر المحجوز (قاعة، سيارة، إلخ)
  final String itemName;         // اسم العنصر
  final String providerId;       // معرف مزود الخدمة
  final String providerName;     // اسم مزود الخدمة
  final String customerId;       // معرف الزبون
  final String customerName;     // اسم الزبون
  final String customerPhone;    // رقم هاتف الزبون
  final String category;         // نوع الخدمة (hall, hotel, salon_care, car)
  final DateTime bookingDate;    // تاريخ الحجز
  final DayStatus dayStatus;     // حالة اليوم (كامل/جزئي)
  final TimeSlot? timeSlot;      // الفترة الزمنية (إذا كان الحجز جزئي)
  final DateTime createdAt;      // تاريخ إنشاء الحجز
  final String? notes;           // ملاحظات إضافية
  final bool isCancelled;        // هل تم إلغاء الحجز
  final DateTime? cancelledAt;   // تاريخ الإلغاء
  final String? cancelledBy;     // من قام بالإلغاء (customer/provider)

  BookingModel({
    this.id,
    required this.itemId,
    required this.itemName,
    required this.providerId,
    required this.providerName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.category,
    required this.bookingDate,
    required this.dayStatus,
    this.timeSlot,
    DateTime? createdAt,
    this.notes,
    this.isCancelled = false,
    this.cancelledAt,
    this.cancelledBy,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'providerId': providerId,
      'providerName': providerName,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'category': category,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'dayStatus': dayStatus.toString().split('.').last,
      'timeSlot': timeSlot?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
      'isCancelled': isCancelled,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancelledBy': cancelledBy,
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BookingModel(
      id: documentId,
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      providerId: map['providerId'] ?? '',
      providerName: map['providerName'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      category: map['category'] ?? '',
      bookingDate: (map['bookingDate'] as Timestamp).toDate(),
      dayStatus: _parseDayStatus(map['dayStatus']),
      timeSlot: map['timeSlot'] != null ? TimeSlot.fromMap(map['timeSlot']) : null,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
      notes: map['notes'],
      isCancelled: map['isCancelled'] ?? false,
      cancelledAt: map['cancelledAt'] != null ? (map['cancelledAt'] as Timestamp).toDate() : null,
      cancelledBy: map['cancelledBy'],
    );
  }

  static DayStatus _parseDayStatus(dynamic status) {
    if (status == null) return DayStatus.available;
    
    final statusStr = status.toString();
    if (statusStr == 'fullyBooked') return DayStatus.fullyBooked;
    if (statusStr == 'partiallyBooked') return DayStatus.partiallyBooked;
    return DayStatus.available;
  }

  BookingModel copyWith({
    String? id,
    String? itemId,
    String? itemName,
    String? providerId,
    String? providerName,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? category,
    DateTime? bookingDate,
    DayStatus? dayStatus,
    TimeSlot? timeSlot,
    DateTime? createdAt,
    String? notes,
    bool? isCancelled,
    DateTime? cancelledAt,
    String? cancelledBy,
  }) {
    return BookingModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      category: category ?? this.category,
      bookingDate: bookingDate ?? this.bookingDate,
      dayStatus: dayStatus ?? this.dayStatus,
      timeSlot: timeSlot ?? this.timeSlot,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      isCancelled: isCancelled ?? this.isCancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }
}

/// الخدمات القابلة للحجز (لها تقويم)
const List<String> bookableCategories = [
  'hall',        // قاعات الأعراس
  'hotel',       // الفنادق
  'salon_care',  // الصالونات
  'car',         // تأجير السيارات
  'photography', // التصوير
];

/// التحقق من أن الخدمة قابلة للحجز
bool isBookableCategory(String category) {
  return bookableCategories.contains(category);
}

/// الخدمات غير القابلة للحجز (فقط متوفر/غير متوفر)
const List<String> availabilityOnlyCategories = [
  'restaurant',    // الطعام
  'bride_dress',   // فستان العروس
  'groom_suit',    // البدلات الرجالية
  'car_decoration', // تزيين السيارة
  'cake',          // الكيك
  'flowers',       // الورود
  'honeymoon',     // شهر العسل
];
