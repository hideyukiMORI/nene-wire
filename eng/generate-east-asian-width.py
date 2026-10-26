#!/usr/bin/env python3
"""Unicode の EastAsianWidth.txt（一次資料）から、全角（W・F）の範囲の表を Swift で生成する（ADR 0006）。

使い方: python3 eng/generate-east-asian-width.py <EastAsianWidth-16.0.0.txt のパス>
入手先: https://www.unicode.org/Public/16.0.0/ucd/EastAsianWidth.txt
ファイルの SHA-256 が下の値と違えば何も書かずに失敗する（取り違えと改ざんを防ぐ）。
"""

import hashlib
import pathlib
import sys

VERSION = "16.0.0"
SOURCE = f"https://www.unicode.org/Public/{VERSION}/ucd/EastAsianWidth.txt"
SHA256 = "43adc76c0686a42cb370764eb8cfe2b2a45b10b855e5572a2db4a0eecce15d5b"
OUTPUT = pathlib.Path(__file__).resolve().parent.parent / "Sources/NeNeWireRender/EastAsianWidth.swift"


def wide_ranges(text: str) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        span, width = (part.strip() for part in line.split(";"))
        if width not in ("W", "F"):
            continue
        first, _, last = span.partition("..")
        low, high = int(first, 16), int(last or first, 16)
        if ranges and ranges[-1][1] + 1 >= low:
            ranges[-1] = (ranges[-1][0], max(ranges[-1][1], high))
        else:
            ranges.append((low, high))
    return ranges


def render(ranges: list[tuple[int, int]]) -> str:
    rows = []
    for index in range(0, len(ranges), 4):
        chunk = ranges[index : index + 4]
        rows.append("        " + " ".join(f"0x{low:05X}...0x{high:05X}," for low, high in chunk))
    body = "\n".join(rows)
    return f"""// 生成物。手で直さない。`python3 eng/generate-east-asian-width.py <EastAsianWidth.txt>` で作り直す（ADR 0006）。
// 一次資料: {SOURCE}
// SHA-256: {SHA256}

/// Unicode {VERSION} の East Asian Width で全角（W・F）の符号位置の範囲（昇順・重なりなし）。
/// 曖昧（A）は半角として扱う（Windows Terminal の既定と同じ・ADR 0006）。
enum EastAsianWidth {{
    static let wide: [ClosedRange<UInt32>] = [
{body}
    ]
}}
"""


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    data = pathlib.Path(sys.argv[1]).read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SHA256:
        print(f"SHA-256 が違う: {digest}（期待 {SHA256}）", file=sys.stderr)
        return 1
    ranges = wide_ranges(data.decode("utf-8"))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(render(ranges), encoding="utf-8")
    print(f"{OUTPUT}: {len(ranges)} 範囲")
    return 0


if __name__ == "__main__":
    sys.exit(main())
