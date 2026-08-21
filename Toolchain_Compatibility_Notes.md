# ملاحظات توافق Toolchain لـ arm64e

توضح وثائق Theos أن arm64e تعتمد pointer authentication، وأن ABI الخاصة بها تغيّرت مع iOS 14/Xcode 12؛ لذلك يلزم مترجم حديث لإنتاج arm64e متوافقة مع أهداف iOS الحديثة. وتذكر الوثائق أيضاً أن دعم arm64e على لينكس يرتبط مباشرة بقدرة Toolchain المستخدمة، لا بمتغيرات Makefile وحدها.

تؤكد مشكلة Theos رقم 482 أن أخطاء `invalid arch name '-arch arm64e'` و`unsupported architecture name` على لينكس تشير إلى Toolchain قديمة أو إلى غياب wrappers صحيحة للمترجم والرابط. وبناءً على ذلك، سيُستبدل الاعتماد على Clang 10 القديمة بمسار Toolchain حديث قادر على إصدار CPU subtype arm64e فعلياً، مع SDK 16.5 السليمة.

## المصادر

1. [Theos — arm64e Deployment](https://theos.dev/docs/arm64e-deployment)
2. [theos/theos issue #482 — arm64e compilation on Linux](https://github.com/theos/theos/issues/482)

## نتيجة فحص LLVM الحالية

أظهر اختبار محلي أن Clang 18 يولّد object بطلب `arm64e` مع subtype `2`، لكن `ld64.lld` 18 يخرج dylib ذات subtype `0` (arm64 عادية). وهذه النتيجة تتوافق مع مناقشات LLVM: إضافة دعم arm64e في Mach-O LLD ما زالت عملاً منفصلاً، كما أن توافق arm64e الحديث يحتاج علامة `CPU_SUBTYPE_PTRAUTH_ABI` التي لا توفرها Toolchain العامة القديمة تلقائياً.

3. [[MachO] Adding arm64e support to LLD — LLVM Discussion](https://discourse.llvm.org/t/macho-adding-arm64e-support-to-lld/90656)
4. [llvm/llvm-project issue #80200 — arm64e target output and PTRAUTH ABI](https://github.com/llvm/llvm-project/issues/80200)
