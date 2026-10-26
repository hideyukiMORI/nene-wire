# NeNe Wire — Agent Guide

Short English entry point. The authoritative handbook is [CLAUDE.md](CLAUDE.md) (Japanese);
the normative documents live in [docs/](docs/).

## Project identity

- Product: NeNe Wire — a Swift terminal tool that streams world and Japanese news headlines and ledes, one at a time, with cyber effects; foreign-language items are translated (offline where possible)
- Language / UI: Swift 6 / terminal (ANSI escapes, no ncurses)
- Package: `NeNeWire` (SwiftPM, Swift 6.4.1 pinned in `.swift-version`, zero external dependencies)
- Governing principle: **one meaning, one canonical implementation path, enforced by machines**

## Required reading before changing production code

1. `docs/ARCHITECTURE_CONSTITUTION.md`
2. `docs/PROJECT_LAYOUT.md`
3. `docs/CODING_RULES.md`
4. `docs/QUALITY_GATES.md`
5. `docs/DEVELOPMENT_WORKFLOW.md`
6. `docs/COMMIT_CONVENTIONS.md`
7. `docs/GLOSSARY.md`
8. `docs/REQUIREMENTS.md` (the owner's decisions)

Then the active issue, the relevant accepted ADRs, and any active waivers.

## Agent rules

- Do not invent a second implementation path because it is locally convenient.
- Do not weaken a gate to make a change pass. Fix the code instead.
- Do not mark a rule `active` in `docs/QUALITY_GATES.md` before its enforcement exists.
- Do not read the current time, randomness, locale, or environment outside the `nene-wire` executable target (the composition root).
- Do not write a catch-all in a `switch`: `default:`, `@unknown default`, `case _:`, `case let x:`, `case (let x):`, `case .a, _:` or `case (_, _):`. They disable exhaustiveness checking.
- Do not write `init` in an `extension`; it can bypass a `private init` from another file of the same target.
- Do not use `async`, `await`, `Task`, `actor`, threads, Dispatch, or `@preconcurrency`.
- Do not add a SwiftPM target without `.treatAllWarnings(as: .error)` and `ExistentialAny`; the manifest beats command-line flags.
- Do not add external packages. HTTP goes through an external `curl` child process and translation through an external translator, both only from the Host target.
- Do not spawn processes (`posix_spawn`, `fork`, `exec*`, `system`, `popen`) outside the Host target.
- Do not use `String.count` as a column width; full-width (East Asian Wide) characters take two columns.
- Do not override the owner's decisions in `docs/REQUIREMENTS.md` or add features they did not ask for; ask first.
- Do not add suppressions, lint baselines, or tool exclusions without an active waiver (or at all, where the language forbids them).
- Do not claim a command passed unless it was actually executed.
- Prefer the smallest change that fully follows the canonical path.

## The only definition of done

```bash
make bootstrap   # once after clone
make check
```

Local and CI run exactly this. Use narrow checks while iterating; run the full gate before
moving the PR from Draft to Ready.

## Required completion report

Issue and rule IDs, files and behavior changed, verification commands and results,
documentation or schema changes, active waiver IDs (or `none`), remaining risks.

Investigation-only requests do not authorize editing, committing, pushing, or opening PRs.
