#!/bin/bash
# draft の PR ではフルゲートを回さない（QLT-012）が、ジョブを「スキップ」にはしない。
# GitHub はスキップされた必須 check を成功として扱うので、draft の間は必ず失敗させてマージを止める（事故: NeNe Gambit の Issue #1・PR #2）。
set -euo pipefail
if [ "${1:-}" != "false" ]; then
    echo "ci: PR が draft なのでフルゲートを回さない。Ready にすると回る（QLT-012）" >&2
    exit 1
fi
