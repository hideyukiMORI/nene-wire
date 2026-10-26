#!/bin/bash
# swift build / swift test を回し、SwiftPM 自身の警告も失敗にする（QLT-002）。
# treatAllWarnings(as: .error) はコンパイラの警告だけをエラーにし、manifest の解釈で SwiftPM が出す警告
# （例: "Source files for target X should be located under ..."）は exit 0 のまま通る（NeNe Gambit の Issue #3 で実測）。
set -euo pipefail
cd "$(dirname "$0")/.."
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
"$@" 2>&1 | tee "$log" || status=$?
if [ "$status" -ne 0 ]; then
    exit "$status"
fi
if grep -E '(^|: )warning: ' "$log" > /dev/null; then
    echo "swift-strict: SwiftPM かコンパイラが警告を出した（QLT-002）" >&2
    exit 1
fi
