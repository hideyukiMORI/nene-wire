"""eng/validate-commit-message.py の正例・反例（GIT-003・QLT-007）。"""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "validate_commit_message", Path(__file__).resolve().parent.parent / "validate-commit-message.py")
v = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(v)


class CommitMessage(unittest.TestCase):
    def test_accepts_canonical(self) -> None:
        self.assertEqual([], v.problems("docs(adr): 警告のエラー化は manifest に置く (#1)\n\n本文。\n"))

    def test_accepts_without_scope(self) -> None:
        self.assertEqual([], v.problems("chore: 雛形を複製する (#1)\n"))

    def test_rejects_missing_issue(self) -> None:
        self.assertTrue(v.problems("docs(adr): 警告のエラー化は manifest に置く\n"))

    def test_rejects_unknown_type(self) -> None:
        self.assertTrue(v.problems("feature: 何かを足す (#1)\n"))

    def test_rejects_english_description(self) -> None:
        self.assertTrue(v.problems("fix(core): handle castling (#3)\n"))

    def test_rejects_long_subject(self) -> None:
        self.assertTrue(v.problems("fix(core): " + "あ" * 100 + " (#3)\n"))

    def test_rejects_missing_blank_line(self) -> None:
        self.assertTrue(v.problems("fix(core): 直す (#3)\n本文\n"))

    def test_rejects_breaking_without_footer(self) -> None:
        self.assertTrue(v.problems("feat(core)!: 表記を変える (#3)\n"))
        self.assertEqual([], v.problems("feat(core)!: 表記を変える (#3)\n\nBREAKING CHANGE: 表記が変わる\n"))


if __name__ == "__main__":
    unittest.main()
