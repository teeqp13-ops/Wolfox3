# توافق WolFox مع iOS 15.8 والإصدارات الأحدث

- Deployment Target: ‏iOS 15.8.
- حزمة SDK في Theos: ‏`iPhoneOS16.5.sdk` المصححة.
- Base SDK المسجل داخلياً في الحزمة الرسمية: ‏iOS 16.4.
- المعمارية: `arm64` فقط للتطبيقات غير التابعة للنظام.
- لا يوجد ادعاء بتوافق `arm64e` أو عمليات النظام.

| البيئة | Architecture في DEB | مسار التثبيت |
|---|---|---|
| Rootful | `iphoneos-arm` | `/Library/MobileSubstrate/DynamicLibraries` |
| Rootless | `iphoneos-arm64` | `/var/jb/Library/MobileSubstrate/DynamicLibraries` |

اختيار Rootful أو Rootless يعتمد على بيئة الجيلبريك نفسها. يثبت البناء حد التشغيل
الأدنى والتغليف فقط؛ يجب اختبار تحميل المكتبة والواجهة والهوكات على كل إصدار iOS
مراد دعمه داخل تطبيق اختبار مصرح به.
