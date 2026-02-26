class ServiceItem {
  final String id;
  final String name;
  final String location;
  final String details; // إضافة حقل التفاصيل
  final double price;
  final String imageUrl;
  final int? capacity; // عدد الضيوف (خاص بالقاعات فقط)
  final String? serviceId;
  final String? providerId; // معرف مزود الخدمة
  final String? providerName; // اسم مزود الخدمة

  ServiceItem({
    required this.id,
    required this.name,
    required this.location,
    required this.details,
    required this.price,
    required this.imageUrl,
    this.capacity,
    this.serviceId,
    this.providerId,
    this.providerName,
  });

  ServiceItem copyWith({
    String? id,
    String? name,
    String? location,
    String? details,
    double? price,
    String? imageUrl,
    int? capacity,
    String? serviceId,
    String? providerId,
    String? providerName,
  }) {
    return ServiceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      details: details ?? this.details,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      capacity: capacity ?? this.capacity,
      serviceId: serviceId ?? this.serviceId,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
    );
  }

  factory ServiceItem.fromMap(Map<String, dynamic> map, String id) {
    return ServiceItem(
      id: id,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      details: map['details'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: _getFirstImage(map),
      capacity: map['capacity'],
      serviceId: map['serviceId'],
      providerId: map['providerId'],
      providerName: map['providerName'],
    );
  }

  Map<String, dynamic> toMap() {
    final data = {
      'name': name,
      'location': location,
      'details': details,
      'price': price,
      'imageUrl': imageUrl,
    };
    if (capacity != null) {
      data['capacity'] = capacity as Object;
    }
    if (serviceId != null) {
      data['serviceId'] = serviceId as Object;
    }
    if (providerId != null) {
      data['providerId'] = providerId as Object;
    }
    if (providerName != null) {
      data['providerName'] = providerName as Object;
    }
    return data;
  }

  static String _getFirstImage(Map<String, dynamic> map) {
    // Try imageUrls array first
    if (map['imageUrls'] is List && (map['imageUrls'] as List).isNotEmpty) {
      return map['imageUrls'][0].toString();
    }
    // Try single imageUrl
    if (map['imageUrl'] != null && map['imageUrl'].toString().isNotEmpty) {
      return map['imageUrl'].toString();
    }
    // Try image field
    if (map['image'] != null && map['image'].toString().isNotEmpty) {
      return map['image'].toString();
    }
    return '';
  }
}
