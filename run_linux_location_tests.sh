#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CXX="${CXX:-$(command -v g++ || true)}"

if [ -z "$CXX" ]; then
    echo "❌ g++ غير متوفر. ثبّت GCC 11 أو أحدث."
    exit 1
fi

"$PROJECT_DIR/test_location_hooks_static.sh"

BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wolfox-linux-location.XXXXXX")"
OUTPUT="$BUILD_DIR/location_hook_sim_test"

FLAGS=(
    -std=c++17
    -O1
    -g
    -Wall
    -Wextra
    -Werror
    -pedantic
)

if [ "${WOLFOX_SANITIZERS:-1}" != "0" ]; then
    FLAGS+=(
        -fsanitize=address,undefined
        -fno-omit-frame-pointer
    )
fi

echo "⚙️  Linux compiler: $($CXX --version | head -n 1)"
"$CXX" "${FLAGS[@]}" "$PROJECT_DIR/linux_tests/location_hook_sim_test.cpp" -o "$OUTPUT"

# LeakSanitizer لا يعمل داخل بعض حاويات ptrace؛ يبقى فحص أخطاء الذاكرة
# وUndefinedBehavior مفعلاً، ويُعطّل فحص التسرب فقط.
ASAN_OPTIONS="detect_leaks=0:halt_on_error=1" \
UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1" \
"$OUTPUT"

echo "✅ اكتمل اختبار لينكس مع AddressSanitizer وUndefinedBehaviorSanitizer."
