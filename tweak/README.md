# WolfTube deb

حزمة Rootless تجريبية لأجهزة iOS 14 أو أحدث مع Jailbreak. تدخل الأداة إلى تطبيق YouTube الرسمي ذي المعرّف `com.google.ios.youtube` وتضيف زر إعدادات عائمًا.

## الموجود في 0.1.0

- إعدادات عربية داخل YouTube.
- محاولة إبقاء تشغيل `AVPlayer` في الخلفية.
- إعادة تشغيل تلقائية عبر إشعار انتهاء `AVPlayerItem`.
- فرض تفعيل خيار Picture in Picture على `AVPlayerViewController`.
- مرشحات تجريبية لإخفاء أزرار الإنشاء والعناصر الإعلانية والمقترحات حسب Accessibility Labels.
- دعم arm64 وarm64e وحزمة Rootless.

## لم يكتمل بعد

مدير التنزيلات وتنزيل الفيديو/الصوت/القصص والصور، نسخ النصوص، كلمات الأغاني، فتح الروابط في Safari، وتجاوز إعلانات مشغل YouTube نفسها. هذه الميزات تحتاج تكاملًا واختبارات خاصة بإصدار YouTube ولا تُعرض في الواجهة على أنها جاهزة.

## البناء

يتطلب [Theos](https://theos.dev/):

```sh
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

تظهر الحزمة في `packages/`. ينفذ GitHub Actions الأمر نفسه ويرفع الناتج باسم `WolfTube-rootless-deb`.

## التثبيت

ثبّت ملف `.deb` بمدير حزم يدعم Rootless، ثم أعد تشغيل YouTube. يجب استخدام الوسائط التي تملك حق تنزيلها أو التي يسمح صاحبها بذلك، مع الالتزام بالقوانين وشروط الخدمة المعمول بها.
