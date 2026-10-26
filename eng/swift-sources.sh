#!/bin/bash
# 整形と lint の対象になる Swift ファイルを NUL 区切りで出す。git が追跡するか追跡し得るファイル（.gitignore に従う）で、
# 追跡前のファイルも含む。消したが追跡が残っているファイルは除く。
set -euo pipefail
cd "$(dirname "$0")/.."
git ls-files -z --cached --others --exclude-standard -- '*.swift' | sort -zu | while IFS= read -r -d '' f; do
    if [ -f "$f" ]; then
        printf '%s\0' "$f"
    fi
done
