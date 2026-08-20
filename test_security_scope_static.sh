#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

PASS=0
FAIL=0

pass() { echo "✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "❌ $1"; FAIL=$((FAIL + 1)); }

if rg -q 'WFCleanDeviceRestrictions|wrongUserDevice|CanOnlyUserFromSameDevice|hook_JSONObjectWithData' WolFoxIntegrated.mm; then
    fail "ما زال هوك تعديل JSON أو تجاوز قيود الجهاز موجوداً"
else
    pass "لا يوجد هوك لتعديل JSON أو تجاوز قيود الجهاز"
fi

if rg -q 'SecTrust|NSURLAuthenticationChallenge|allowsAnyHTTPSCertificate|setAllowsAnyHTTPSCertificate' . --glob '*.{m,mm,h}'; then
    fail "يوجد مسار لتجاوز الثقة أو TLS"
else
    pass "لا يوجد تجاوز TLS أو SecTrust"
fi

if rg -q 'cydia|sileo|substrate.*hide|jailbreak.*hide|ptrace[(]' . --glob '*.{m,mm,h}'; then
    fail "يوجد مسار إخفاء جيلبريك أو تعطيل فحص عملية"
else
    pass "لا يوجد إخفاء جيلبريك أو تعطيل ptrace"
fi

mapfile -t TARGETS < <(awk 'NF && $1 !~ /^#/' WolFoxTargetBundles.txt)
if [ "${#TARGETS[@]}" -eq 1 ] && [ "${TARGETS[0]}" = "com.example.wolfox.authorizedtest" ]; then
    pass "فلتر التوزيع الافتراضي محصور في تطبيق اختبار توضيحي"
else
    fail "فلتر التوزيع الافتراضي يجب أن يحتوي تطبيق الاختبار التوضيحي فقط"
fi

if rg -q '(^|[.])(gov|government)([.]|$)|(^|[.])(attendance|employee|hr)([.]|$)' WolFoxTargetBundles.txt; then
    fail "توجد وجهات حكومية أو حضور/موارد بشرية في الفلتر الافتراضي"
else
    pass "لا توجد وجهات حكومية أو حضور/موارد بشرية في الفلتر الافتراضي"
fi

if [ -e secure_source_package.sh ] || [ -e decrypt_source_package.sh ]; then
    fail "ما زالت سكربتات تشفير السورس موجودة"
else
    pass "السورس واضح ولا يحتوي سكربتات تشفير/فك تشفير"
fi

echo "النتيجة: $PASS ناجح، $FAIL فاشل"
[ "$FAIL" -eq 0 ]
