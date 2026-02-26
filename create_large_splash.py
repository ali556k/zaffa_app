from PIL import Image

# فتح الصورة
img = Image.open('assets/app_icon_new.png')

# تكبير الصورة إلى 3 أضعاف
new_size = (img.size[0] * 3, img.size[1] * 3)
img_large = img.resize(new_size, Image.Resampling.LANCZOS)

# حفظ النسخة الكبيرة
img_large.save('assets/app_icon_splash.png')
print(f'✅ تم إنشاء صورة splash كبيرة: {new_size[0]}x{new_size[1]}')
