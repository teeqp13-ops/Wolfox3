#!/usr/bin/env bash
set -euo pipefail

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    echo "❌ يجب تشغيل الفحص داخل نسخة Git متتبعة من المستودع." >&2
    exit 1
fi
cd "$repository_root"

blocked_file_pattern='(^|/)([.]env([.].*)?|secrets/.*|private/.*|.*[.](pem|key|p12|pfx|mobileprovision))$'
tracked_blocked="$(git ls-files | grep -E "$blocked_file_pattern" || true)"
if [ -n "$tracked_blocked" ]; then
    echo "❌ ملفات اعتماد محظورة موجودة داخل Git:" >&2
    printf '%s\n' "$tracked_blocked" >&2
    exit 1
fi

secret_pattern='BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|sk_live_[A-Za-z0-9]{16,}|xox[baprs]-[A-Za-z0-9-]{16,}'
matches="$(git grep -nIE "$secret_pattern" -- . \
    ':(exclude)scripts/check_repository_secrets.sh' \
    ':(exclude)SECURITY.md' || true)"
if [ -n "$matches" ]; then
    echo "❌ عُثر على نمط سر محتمل داخل الملفات المتتبعة:" >&2
    printf '%s\n' "$matches" >&2
    exit 1
fi

echo "✅ لا توجد ملفات اعتماد محظورة أو أنماط أسرار معروفة في المستودع."
