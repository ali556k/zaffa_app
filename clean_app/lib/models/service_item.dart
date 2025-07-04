class ServiceItem {
  final String id;
  final String name;
  final String location;
  final double price;
  final String imageUrl;
  final int? capacity; // عدد الضيوف (خاص بالقاعات فقط)
  final String? serviceId;

  ServiceItem({
    required this.id,
    required this.name,
    required this.location,
    required this.price,
    required this.imageUrl,
    this.capacity,
    this.serviceId,
  });

  ServiceItem copyWith({
    String? id,
    String? name,
    String? location,
    double? price,
    String? imageUrl,
    int? capacity,
    String? serviceId,
  }) {
    return ServiceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      capacity: capacity ?? this.capacity,
      serviceId: serviceId ?? this.serviceId,
    );
  }

  factory ServiceItem.fromMap(Map<String, dynamic> map, String id) {
    return ServiceItem(
      id: id,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      capacity: map['capacity'],
      serviceId: map['serviceId'],
    );
  }

  Map<String, dynamic> toMap() {
    final data = {
      'name': name,
      'location': location,
      'price': price,
      'imageUrl': imageUrl,
    };
    if (capacity != null) {
      data['capacity'] = capacity as Object;
    }
    if (serviceId != null) {
      data['serviceId'] = serviceId as Object;
    }
    return data;
  }
}
