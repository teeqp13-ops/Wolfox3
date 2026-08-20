# WolFox Store + DLTube

متجر رقمي عربي سريع يعمل كتطبيق Telegram Web App ويمكن فتحه من الويب، مع SQLite ودعم EdfaPay وتسليم أكواد التفعيل عبر Telegram أو NeraChat WhatsApp.

يتضمن المستودع أيضًا أساس أداة **DLTube** لأجهزة iOS Jailbreak. يبني GitHub Actions حزمة Rootless بصيغة `.deb` من مجلد [`tweak`](tweak/README.md).

## المزايا الحالية

- واجهة عربية RTL متجاوبة مع الوضع الداكن والفاتح.
- منتجات وأسعار بالريال السعودي من SQLite.
- إنشاء طلبات آمن دون الوثوق بالسعر القادم من العميل.
- تحقق HMAC لبيانات Telegram Web App.
- دورة دفع `pending / paid / failed` مع webhook idempotent.
- حجز كود تفعيل واحد داخل معاملة ومنع التكرار.
- سجل محاولات تسليم Telegram وWhatsApp.
- لوحة إدارة للطلبات محمية بكلمة مرور مشفرة.
- اختبارات آلية على PHP 8.1 و8.2 و8.3 عبر GitHub Actions.
- بناء آلي لحزمة DLTube Rootless باستخدام Theos، مع رفع ملف `.deb` كـ GitHub Artifact.

## تشغيل محلي

```sh
cp .env.example .env
php scripts/migrate.php
php scripts/seed.php
php -S 127.0.0.1:8080 -t public
```

ثم افتح `http://127.0.0.1:8080`.

للاختبار:

```sh
php tests/run.php
```

## إعداد الإنتاج

- النطاق المستهدف: `https://store.p3nd.fun`
- العملة: `SAR`
- المنطقة الزمنية: `Asia/Riyadh`
- قاعدة البيانات: SQLite
- بوابة الدفع: EdfaPay
- التسليم: Telegram وNeraChat WhatsApp

راجع [خطة البنية](docs/ARCHITECTURE.md) و[خطوات Hostinger](docs/HOSTINGER.md).

## ملاحظة مهمة عن EdfaPay

المحول الحالي يطبّع webhook ويحميه بتوقيع HMAC قابل للضبط. قبل الإنتاج يجب مطابقة أسماء الحقول وطريقة إنشاء جلسة الدفع مع مستندات حساب التاجر الفعلية؛ لا توجد مفاتيح أو بيانات تاجر داخل المستودع.
