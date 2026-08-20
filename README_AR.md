# WolFox v1.6.1 — سورس بناء Linux الآمن

هذه النسخة واضحة بلا تشفير، وتستخدم هدف تشغيل أدنى iOS 15.8 وشريحة `arm64`
واحدة للتطبيقات غير التابعة للنظام. اسم حزمة Theos المستخدمة هو
`iPhoneOS16.5.sdk`، مع ملاحظة أن إعداداتها الأساسية الرسمية تسجل Base SDK
‏16.4. لا تحتاج هذه النسخة إلى SDK 26.5 ولا تحتوي طبقة رؤوس UIUtilities مؤقتة.

## المتطلبات

- Theos حديث على Linux.
- `iPhoneOS16.5.sdk` المصححة داخل `$THEOS/sdks`.
- Clang/LLD حديثان، و`ldid`، و`dpkg-deb`.
- `g++` يدعم C++17 لتشغيل اختبارات المحاكاة.

## تحديد التطبيق المصرح به

يحتوي `WolFoxTargetBundles.txt` افتراضياً على معرف اختبار غير حقيقي:

```text
com.example.wolfox.authorizedtest
```

استبدله فقط بمعرف تطبيق تملكه أو لديك تصريح صريح لاختباره. يمنع السكربت البناء
دون Bundle ID صالح ولا يوفر وضع حقن عام.

## الاختبار والبناء

```bash
chmod +x ./*.sh
./run_all_linux_tests.sh
make clean
make package FINALPACKAGE=1
```

ينتج البناء:

- Rootful: معمارية الحزمة `iphoneos-arm` ومسار `/Library/MobileSubstrate/DynamicLibraries`.
- Rootless: معمارية الحزمة `iphoneos-arm64` ومسار `/var/jb/Library/MobileSubstrate/DynamicLibraries`.

يتحقق السكربت بعد التغليف من `Architecture` و`Depends` ومسار dylib وملكية
`root:root`. حقل الاعتماد المطلوب هو:

```text
firmware (>= 15.8), mobilesubstrate
```

## حدود التوافق

يبني Linux ويختبر البنية والمنطق والمحاكاة فقط. التشغيل على iOS 15.8 أو إصدار
أحدث يحتاج اختباراً فعلياً على جهاز مصرح به. `arm64e` غير مضمنة ولا يُدعى دعم
عمليات النظام المبنية بها.

لا تتضمن هذه النسخة تجاوز TLS، أو إخفاء جيلبريك، أو تعديل استجابات JSON لإزالة
قيود الجهاز. راجع `RELEASE_READINESS_AR.md` و`TEST_MATRIX_AR.md` قبل التوزيع.
