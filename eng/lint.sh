#!/bin/bash
# SwiftLint を全 Swift ファイルに回す（SWF-004 / SWF-012 ほか）。
# 有効にした規則を道具が黙って飛ばしたら（"Skipping enabled rule"）、設定が効いていないので失敗にする（CNF-007）。
set -euo pipefail
cd "$(dirname "$0")/.."
swiftlint="$1"
shift
mapfile -d '' files < <(eng/swift-sources.sh)
output="$("$swiftlint" lint --strict --quiet --no-cache "$@" "${files[@]}" 2>&1)" || status=$?
status="${status:-0}"
if [ -n "$output" ]; then
    printf '%s\n' "$output"
fi
if grep -q 'Skipping enabled rule' <<<"$output"; then
    echo "lint: 有効にした規則が実行されていない（CNF-007）" >&2
    exit 1
fi
exit "$status"
