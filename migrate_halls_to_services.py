#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
سكريبت نقل قاعات الأعراس من مجموعة hall إلى services/hall/items
لإصلاح مشكلة عدم ظهور أسماء القاعات عند المستخدمين
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os
import json

def migrate_halls():
    try:
        # تهيئة Firebase
        if not firebase_admin._apps:
            # البحث عن ملف المفاتيح
            if os.path.exists('serviceAccountKey.json'):
                cred = credentials.Certificate('serviceAccountKey.json')
            else:
                print("❌ لم يتم العثور على ملف serviceAccountKey.json")
                print("📝 يرجى تنزيل ملف المفاتيح من Firebase Console ووضعه في المجلد الحالي")
                return
            
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        
        print("🔍 جاري البحث عن قاعات الأعراس في مجموعة hall...")
        
        # قراءة جميع القاعات من مجموعة hall
        halls_ref = db.collection('hall')
        halls = halls_ref.stream()
        
        total_halls = 0
        migrated_halls = 0
        skipped_halls = 0
        
        for hall_doc in halls:
            total_halls += 1
            hall_id = hall_doc.id
            hall_data = hall_doc.to_dict()
            
            hall_name = hall_data.get('hallName') or hall_data.get('name', 'غير محدد')
            
            print(f"\n📋 معالجة قاعة: {hall_name} (ID: {hall_id})")
            
            # التحقق من وجود القاعة في services/hall/items
            service_item_ref = db.collection('services').document('hall').collection('items').document(hall_id)
            service_item = service_item_ref.get()
            
            if service_item.exists:
                print(f"   ⏭️  القاعة موجودة بالفعل في services/hall/items - تخطي")
                skipped_halls += 1
                continue
            
            # نسخ البيانات إلى services/hall/items
            try:
                service_item_ref.set(hall_data)
                print(f"   ✅ تم نسخ القاعة بنجاح إلى services/hall/items")
                migrated_halls += 1
                
                # طباعة تفاصيل القاعة
                print(f"   📄 اسم القاعة: {hall_name}")
                print(f"   👤 مزود الخدمة: {hall_data.get('providerName', 'غير محدد')}")
                print(f"   📞 الهاتف: {hall_data.get('providerPhone', 'غير محدد')}")
                print(f"   💰 السعر: {hall_data.get('basePrice', 0)}")
                
            except Exception as e:
                print(f"   ❌ خطأ في نسخ القاعة: {e}")
        
        # طباعة التقرير النهائي
        print("\n" + "="*60)
        print("📊 تقرير النقل النهائي:")
        print("="*60)
        print(f"✅ إجمالي القاعات الموجودة: {total_halls}")
        print(f"✅ القاعات المنقولة بنجاح: {migrated_halls}")
        print(f"⏭️  القاعات المتخطاة (موجودة مسبقاً): {skipped_halls}")
        print("="*60)
        
        if migrated_halls > 0:
            print("\n🎉 تم نقل البيانات بنجاح! الآن قاعات الأعراس ستظهر للمستخدمين")
        elif total_halls == 0:
            print("\n⚠️  لا توجد قاعات في مجموعة hall")
        else:
            print("\n✅ جميع القاعات موجودة بالفعل في services/hall/items")
            
    except Exception as e:
        print(f"❌ خطأ عام: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("🚀 بدء عملية نقل قاعات الأعراس...")
    print("-" * 60)
    migrate_halls()
    print("\n✅ انتهت العملية!")
