# 単一ゲート（QLT-001）。ローカルと CI はどちらも `make check` だけを呼ぶ。
# 個別のターゲットは反復中の狭い検査として使ってよいが、完了の定義は `make check` だけである。

BASE ?= origin/main
SWIFTLINT := .tools/swiftlint

.PHONY: check bootstrap tools build test format lint conformance conformance-test commits release

check: tools build format lint conformance conformance-test test commits
	@echo "make check: 緑"

bootstrap: tools
	git config core.hooksPath .githooks

tools:
	eng/install-tools.sh

build:
	eng/swift-strict.sh swift build

test:
	eng/swift-strict.sh swift test

format:
	eng/swift-sources.sh | xargs -0 swift-format lint --strict --configuration .swift-format

lint:
	eng/lint.sh $(SWIFTLINT) --config .swiftlint.yml

conformance:
	python3 eng/conformance.py

conformance-test:
	python3 -m unittest discover -s eng/tests -q

commits:
	python3 eng/validate-commit-message.py --range "$(BASE)..HEAD"

# 配布物を作る唯一の経路（QLT-014・ADR 0008）。完了の定義ではない（make check の代わりにならない）。
release:
	eng/package-release.sh $(TAG)
