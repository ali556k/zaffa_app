import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseDebugger {
  static Future<void> checkPublishedProviders() async {
    try {
      print('🔍 فحص مجموعة published_providers...');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('published_providers')
          .get();
      
      print('📊 عدد المستندات في published_providers: ${snapshot.docs.length}');
      
      for (var doc in snapshot.docs) {
        print('-------------------');
        print('🆔 معرف المستند: ${doc.id}');
        print('📄 البيانات الكاملة: ${doc.data()}');
        print('🔑 المفاتيح المتاحة: ${doc.data().keys.toList()}');
        print('-------------------');
      }
      
    } catch (e) {
      print('❌ خطأ في فحص published_providers: $e');
    }
  }

  static Future<void> checkProviderRequests() async {
    try {
      print('🔍 فحص مجموعة provider_requests...');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('provider_requests')
          .get();
      
      print('📊 عدد المستندات في provider_requests: ${snapshot.docs.length}');
      
      for (var doc in snapshot.docs) {
        print('-------------------');
        print('🆔 معرف المستند: ${doc.id}');
        print('📄 البيانات الكاملة: ${doc.data()}');
        print('🔑 المفاتيح المتاحة: ${doc.data().keys.toList()}');
        print('📅 حالة الطلب: ${doc.data()['status']}');
        print('-------------------');
      }
      
    } catch (e) {
      print('❌ خطأ في فحص provider_requests: $e');
    }
  }

  static Future<void> checkPublishedItems() async {
    try {
      print('🔍 فحص مجموعة published_items...');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('published_items')
          .get();
      
      print('📊 عدد المستندات في published_items: ${snapshot.docs.length}');
      
      for (var doc in snapshot.docs) {
        print('-------------------');
        print('🆔 معرف المستند: ${doc.id}');
        print('📄 البيانات الكاملة: ${doc.data()}');
        print('🔑 المفاتيح المتاحة: ${doc.data().keys.toList()}');
        print('-------------------');
      }
      
    } catch (e) {
      print('❌ خطأ في فحص published_items: $e');
    }
  }

  static Future<void> debugAllCollections() async {
    print('🚀 بدء فحص جميع المجموعات...');
    await checkProviderRequests();
    await checkPublishedProviders();
    await checkPublishedItems();
    print('✅ انتهى فحص جميع المجموعات');
  }
}
