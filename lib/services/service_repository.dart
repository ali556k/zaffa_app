import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  String id;
  String name;
  String icon;

  Service({required this.id, required this.name, required this.icon});

  factory Service.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Service(
      id: doc.id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
    };
  }
}

class ServiceRepository {
  final CollectionReference servicesCollection =
      FirebaseFirestore.instance.collection('services');

  Stream<List<Service>> getServices() {
    return servicesCollection.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList());
  }

  Future<void> addService(Service service) async {
    await servicesCollection.add(service.toMap());
  }

  Future<void> updateService(Service service) async {
    await servicesCollection.doc(service.id).update(service.toMap());
  }

  Future<void> deleteService(String id) async {
    await servicesCollection.doc(id).delete();
  }
}
