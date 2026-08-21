# اختبار هوكات الموقع على لينكس

نفّذ:

```bash
chmod +x run_linux_location_tests.sh test_location_hooks_static.sh
./run_linux_location_tests.sh
```

يبني السكربت محاكاة C++17 لمسارات `CLLocationManager.location` و
`CLLocation.coordinate` وdelegate والتحديث الفوري بعد نجاح الترخيص، ثم يشغلها
مع `AddressSanitizer` و`UndefinedBehaviorSanitizer`.

يُعطّل فحص تسرب الذاكرة فقط لأن LeakSanitizer لا يعمل في بعض حاويات لينكس
الخاضعة لـ`ptrace`، بينما تبقى فحوص تجاوزات الذاكرة والسلوك غير المعرّف مفعلة.

هذا الاختبار يثبت منطق WolFox واستجابة الحالة والإحداثيات على لينكس، لكنه لا
يشغل Objective-C Runtime أو CoreLocation ولا يثبت حقن الـdylib داخل تطبيق iOS؛
فالتحقق من swizzling والحقن يتطلب نظام iOS فعلياً.
