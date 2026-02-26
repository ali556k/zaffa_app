from PIL import Image

# فتح الصورة الأصلية
img = Image.open('assets/app_icon_new.png')

# الحجم الأصلي
original_size = img.size[0]

# حساب الحجم الجديد (نضيف 60% padding)
new_size = int(original_size * 1.6)

# إنشاء صورة جديدة بخلفية بيضاء
new_img = Image.new('RGB', (new_size, new_size), (255, 255, 255))

# حساب موضع الصورة في المنتصف
offset = (new_size - original_size) // 2

# لصق الصورة في المنتصف
if img.mode == 'RGBA':
    new_img.paste(img, (offset, offset), img)
else:
    new_img.paste(img, (offset, offset))

# حفظ الصورة المعدلة
new_img.save('assets/app_icon_new.png')
print('✅ تم إضافة padding للصورة بنجاح!')
