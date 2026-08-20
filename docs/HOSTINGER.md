# نشر المتجر على Hostinger

1. اضبط Document Root على مجلد `public/`، وليس جذر المستودع.
2. انسخ `.env.example` إلى `.env` خارج الوصول العام واملأ القيم الحقيقية.
3. أنشئ كلمة مرور الإدارة:

```sh
php -r "echo password_hash('CHANGE_ME', PASSWORD_DEFAULT), PHP_EOL;"
```

4. شغّل:

```sh
php scripts/migrate.php
php scripts/seed.php
```

5. استورد الأكواد من ملف نصي، كود واحد في كل سطر:

```sh
php scripts/import_codes.php gps-plus-month codes.txt
```

6. اجعل callback بوابة الدفع يشير إلى:

```text
https://store.p3nd.fun/payment/callback.php
```

7. افحص `https://store.p3nd.fun/health.php` ثم اختبر طلباً كاملاً ببيانات Sandbox قبل تفعيل الإنتاج.

لا ترفع `.env` أو قاعدة `data/store.sqlite` أو ملفات الأكواد إلى GitHub.
