#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

PASS=0
FAIL=0

expect_pattern() {
    local label="$1"
    local pattern="$2"
    shift 2
    if rg -q -- "$pattern" "$@"; then
        echo "✅ $label"
        PASS=$((PASS + 1))
    else
        echo "❌ $label"
        FAIL=$((FAIL + 1))
    fi
}

expect_pattern "تثبيت هوك CLLocationManager.location" 'WFInstallInstanceHook\(CLLocationManager.class, @selector\(location\)' WolFoxIntegrated.mm
expect_pattern "تثبيت هوك CLLocation.coordinate" 'WFInstallInstanceHook\(CLLocation.class, @selector\(coordinate\)' WolFoxIntegrated.mm
expect_pattern "اعتراض delegate وتغليف didUpdateLocations" 'WolFoxProDelegateProxy' WolFoxProHookManager.m
expect_pattern "حماية CLLocation المصطنع من التزييف المزدوج" 'WFSpoofedLocationAssociationKey' WolFoxProHookManager.m WolFoxIntegrated.mm
expect_pattern "التحقق من الإحداثيات قبل callback" 'CLLocationCoordinate2DIsValid\(fake\)' WolFoxProHookManager.m
expect_pattern "التحقق من الإحداثيات داخل getter hooks" 'CLLocationCoordinate2DIsValid\(fake\)' WolFoxIntegrated.mm
expect_pattern "تحديث فوري بعد تطبيق الإحداثيات" 'deliverFakeUpdate' WolFoxMaster.mm
expect_pattern "تحديث فوري بعد نجاح الترخيص" 'license_ready_fake_update_delivered' WolFoxMaster.mm
expect_pattern "حفظ حالة التزييف" 'setBool:self.spoofActive forKey:@"WF_PRO_SPOOF_ACT"' WolFoxProStore.m
expect_pattern "استعادة الإحداثيات المحفوظة مع قبول الصفر" 'savedLatitude.doubleValue, savedLongitude.doubleValue' WolFoxProStore.m
expect_pattern "تحديث المسار كل ثانية" 'scheduledTimerWithTimeInterval:1.0' WolFoxProHookManager.m
expect_pattern "إرسال كل خطوة من المسار فوراً" '\[self deliverFakeUpdate\]' WolFoxProHookManager.m

JITTER_MAX_METERS="$(awk 'BEGIN { printf "%.2f", 0.000025 * 111100 }')"
ROUTE_STEP_METERS="$(awk 'BEGIN { speed=5.0; step=(speed/3600.0)/111.1; printf "%.2f", step*111100 }')"
echo "ℹ️  أقصى jitter تقريبي لكل قراءة: ${JITTER_MAX_METERS} متر"
echo "ℹ️  خطوة مسار 5 كم/س كل ثانية: ${ROUTE_STEP_METERS} متر"

echo "النتيجة: $PASS ناجح، $FAIL فاشل"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
