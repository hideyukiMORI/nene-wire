#!/bin/bash
# 道具の版を確かめ、足りなければ入れる（QLT-001 / QLT-011）。
# - swift と swift-format は .swift-version と一致しなければ失敗する（入れるのは swiftly か eng/install-swift.sh）
# - SwiftLint は eng/swiftlint.lock の版と SHA-256 で .tools/ に入れる
set -euo pipefail
cd "$(dirname "$0")/.."

want="$(tr -d '[:space:]' < .swift-version)"
# swiftly は .swift-version の版を探し、入っていなければ swift 自体の起動を拒む。その出力も理由として出す
if ! version_output="$(swift --version 2>&1)"; then
    echo "tools: swift は ${want} が要るが、起動できない: $(head -n 2 <<<"$version_output" | tr '\n' ' ')" >&2
    exit 1
fi
have="$(sed -n 's/^Swift version \([0-9.]*\) .*/\1/p' <<<"$version_output" | head -n 1)"
if [ "$have" != "$want" ]; then
    echo "tools: swift は ${want} が要る（いまは ${have:-無い}）" >&2
    exit 1
fi
have_format="$(swift-format --version 2>/dev/null)" || have_format=""
if [ "$have_format" != "$want" ]; then
    echo "tools: swift-format は ${want} が要る（いまは ${have_format:-無い}）" >&2
    exit 1
fi

lock_value() { sed -n "s/^$1=//p" eng/swiftlint.lock; }
lint_version="$(lock_value version)"
lint_asset="$(lock_value asset)"
lint_sha="$(lock_value sha256)"
if [ -x .tools/swiftlint ] && [ "$(.tools/swiftlint version 2>/dev/null)" = "$lint_version" ]; then
    exit 0
fi
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
curl -sSfL -o "$workdir/$lint_asset" "https://github.com/realm/SwiftLint/releases/download/${lint_version}/${lint_asset}"
echo "${lint_sha}  $workdir/$lint_asset" | sha256sum --check --quiet
unzip -q -o "$workdir/$lint_asset" swiftlint-static -d "$workdir"
mkdir -p .tools
install -m 0755 "$workdir/swiftlint-static" .tools/swiftlint
if [ "$(.tools/swiftlint version)" != "$lint_version" ]; then
    echo "tools: 入れた SwiftLint の版が ${lint_version} でない" >&2
    exit 1
fi
echo "tools: SwiftLint ${lint_version} を .tools/swiftlint に入れた"
