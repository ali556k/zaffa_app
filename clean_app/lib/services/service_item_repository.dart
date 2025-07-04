import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_item.dart';

class ServiceItemRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ServiceItem>> getItems(String serviceId) {
    return _firestore
        .collection('services')
        .doc(serviceId)
        .collection('items')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addItem(String serviceId, ServiceItem item) async {
    await _firestore
        .collection('services')
        .doc(serviceId)
        .collection('items')
        .add(item.toMap());
  }

  Future<void> updateItem(String serviceId, ServiceItem item) async {
    await _firestore
        .collection('services')
        .doc(serviceId)
        .collection('items')
        .doc(item.id)
        .update(item.toMap());
  }

  Future<void> deleteItem(String serviceId, String itemId) async {
    await _firestore
        .collection('services')
        .doc(serviceId)
        .collection('items')
        .doc(itemId)
        .delete();
  }
}
