# WolFox v1.6.1 SafeBuildFix

سورس بناء WolFox الآمن على Linux وGitHub Actions لشريحة `arm64`، مع حد تشغيل
أدنى iOS 15.8 وحزمتي Rootful وRootless.

## البناء التلقائي

يشغّل Workflow الاختبارات الساكنة ومحاكاة Linux أولاً، ثم يثبت Theos وSDK
`iPhoneOS16.5.sdk` من مستودعات Theos الرسمية ويبني الملفات التالية:

- `WolFox_v1.6.1_iOS15.8-26.5_Rootful.deb`
- `WolFox_v1.6.1_iOS15.8-26.5_Rootless.deb`
- `WolFox.dylib`
- `SHA256SUMS.txt`

تظهر الملفات في قسم **Artifacts** داخل نتيجة GitHub Actions.

## نطاق الحقن

الإعداد الافتراضي محصور في Bundle ID اختباري غير حقيقي:

```text
com.example.wolfox.authorizedtest
```

يجب استبداله فقط بمعرف تطبيق تملكه أو لديك تصريح صريح لاختباره. لا يوفر هذا
المشروع وضع حقن عام، ولا يتضمن تجاوز TLS أو إخفاء جيلبريك أو إزالة قيود جهاز
من استجابات الخادم.

راجع [README_AR.md](README_AR.md) لتفاصيل البناء والتوافق والاختبار.
