# الهوية العامة الموحدة واختبارها

## الأنواع المدمجة

- IDFA عبر `ASIdentifierManager.advertisingIdentifier`.
- IDFV عبر `UIDevice.identifierForVendor`.
- معرّف صفحات WebView عبر `window.device.uuid` و`window.wolfoxIdentifier`
  عند بداية تحميل المستند.

تستخدم الأنواع الثلاثة UUID واحداً بعد التحقق من صيغته، وتعود للقيم الأصلية
إذا لم توجد هوية نشطة أو لم يكن الترخيص صالحاً. تغيير الهوية يؤثر فوراً على
قراءات IDFA وIDFV التالية؛ أما WebView الموجود مسبقاً فيحتاج إعادة تحميل الصفحة
أو إنشاء WebView جديد كي يُحقن سكربت بداية المستند بالقيمة الجديدة.

يُحفظ UUID النشط وقائمة الهويات في `NSUserDefaults`، ويُستعادان بعد إعادة فتح
التطبيق. حذف الهوية النشطة يمسح حالة التفعيل ويعيد المسارات العامة للأصل.

## الأنواع المنفصلة

UUID البلوتوث يبقى داخل ملف Bluetooth لأنه يعرّف `CBPeripheral` ولا يجوز دمجه
مع IDFA/IDFV. لا يشمل النظام IMEI أو UDID أو Push Token أو DeviceCheck أو
App Attest، لأنها معرّفات أو رموز أمنية خاصة وليست واجهات هوية عامة.

## اختبار لينكس

```bash
./run_linux_identifier_tests.sh
```

أو لتشغيل اختبارات الموقع والمعرّفات معاً:

```bash
./run_all_linux_tests.sh
```
