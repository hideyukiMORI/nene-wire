# NeNe Wire

> *A cyber news ticker that lives at the top of your terminal. Headlines keep coming. Press `q` to cut the line.*

A resident news ticker for the terminal. It clears the screen and takes the top 15 rows, full width.
Headlines and ledes from your feeds come through one at a time, every 12 seconds. Each feed is refetched every 15 minutes in the background, and newly arrived stories cut in marked **速報** (breaking).
It is the sibling of [NeNe Gambit](https://github.com/hideyukiMORI/nene-gambit) (chess) and [NeNe Reversi](https://github.com/hideyukiMORI/nene-reversi).

[![release](https://img.shields.io/github/v/release/hideyukiMORI/nene-wire)](https://github.com/hideyukiMORI/nene-wire/releases/latest)
![platform](https://img.shields.io/badge/platform-Linux%20x86__64%20%2F%20WSL2-555)
![license](https://img.shields.io/badge/license-MIT-555)

**English** · [日本語](README.ja.md)

![A breaking story sounds the intercept alarm](docs/images/intercept.png)

<sub>A real screenshot: the v0.2.0 binary running in Windows Terminal on WSL2 (`--demo`, 120×16).
A new story has just arrived on NEON TIMES, and before it cuts the line the strip sounds the intercept alarm: hazard stripes and a crawling `INTERCEPT ■ 緊急傍受 ■ PRIORITY: ALPHA` banner.
Every feed and story in these screenshots is made up by `--demo`; real articles are never stored in this repository.</sub>

> **Beta.** v0.3.0 adds the settings screen, a translation switch and installing from PowerShell. Saved articles are still to come.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hideyukiMORI/nene-wire/main/install.sh | bash
```

This downloads the latest [release](https://github.com/hideyukiMORI/nene-wire/releases/latest), verifies it against `SHA256SUMS`,
and only then installs it as `~/.local/bin/nene-wire`. If the checksum doesn't match, nothing is installed.
The whole script is [install.sh](install.sh), about 45 lines. Reading it before you pipe it takes under a minute.

- Requirements: Linux on x86_64 with glibc 2.35 or newer (Ubuntu 22.04+), and `curl` (used to fetch the feeds). Tested on Ubuntu under WSL2 with Windows Terminal
- No Swift needed. It is a single file with the Swift standard library linked statically; the only dynamic dependencies are libc, libm, libstdc++ and libgcc_s
- To uninstall: `rm ~/.local/bin/nene-wire`

**From PowerShell** (Windows, with WSL):

```powershell
irm https://raw.githubusercontent.com/hideyukiMORI/nene-wire/main/install.ps1 | iex
```

It runs the same installer inside your default WSL distribution, then puts a small `nene-wire.cmd` in `%LOCALAPPDATA%\nene-wire\bin` and adds that folder to your user PATH,
so `nene-wire` works from PowerShell and cmd too (it starts the WSL one through `wsl.exe`). Set `NENE_WIRE_DISTRO` to use another distribution.
The whole script is [install.ps1](install.ps1). To uninstall: delete `%LOCALAPPDATA%\nene-wire`, remove it from your PATH, and run `wsl rm ~/.local/bin/nene-wire`

<details>
<summary>Install by hand</summary>

```bash
v=0.3.0
curl -fsSL -O https://github.com/hideyukiMORI/nene-wire/releases/download/v$v/nene-wire-$v-linux-x86_64.tar.gz \
           -O https://github.com/hideyukiMORI/nene-wire/releases/download/v$v/SHA256SUMS
sha256sum --check SHA256SUMS
tar -xzf nene-wire-$v-linux-x86_64.tar.gz
./nene-wire-$v-linux-x86_64/nene-wire
```
</details>

## How to watch

```bash
nene-wire          # live feeds
nene-wire --demo   # offline, with made-up feeds and stories (a breaking one arrives after 20 seconds)
```

| Key | |
| --- | --- |
| `q` | Quit (Ctrl+C works too; however it ends, your terminal comes back exactly as it was) |
| Space | Pause / resume |
| `→` / `←` | Next / previous story |
| `t` | Translation on/off (saved; the current story switches at once) |
| `s` | Settings (see below) |

| Option | |
| --- | --- |
| `--demo` | Run without the network, on made-up feeds and stories |
| `--list` | Fetch the feeds, print headlines and ledes as plain text, and exit |
| `--version` | Print the version and exit |

It starts with **NHK, BBC World, NPR News and The Guardian World**. Add your own in the settings screen.
The terminal needs at least 72×15. The strip stretches to the full width of the window; its height is always 15 rows.

### Settings

Press `s`. The strip turns into the settings screen, in the same 15 rows:

![The settings screen in the AMBER theme](docs/images/settings.png)

- **FEEDS**: `↑↓` select · `Space` on/off · `a` add (type a name and a URL; Japanese works) · `e` edit · `d` delete (asks first) · `t` test it right now (how many stories, what language, how long)
- **DISPLAY** (`Tab` to switch): `←→` change the display language, translation on/off, seconds per story, theme (`PHOSPHOR` `AMBER` `CYAN` `MAGENTA`), data rain on/off, and whether to show the original headline
- `w` saves, `Esc` closes. Close with unsaved changes and it asks: `w` save and close, `x` discard, `Esc` go back. Inside settings, `q` is just a letter
- Saved as plain text with a version line in `~/.config/nene-wire/settings.txt` (or under `$XDG_CONFIG_HOME`). If the file can't be read, it starts with the defaults, says why, and leaves your file alone

### Translation (English → Japanese)

English stories are shown in Japanese, with the original headline underneath, once the translator is installed.
It is [Argos Translate](https://github.com/argosopentech/argos-translate): offline, no account, no API key.

```bash
curl -fsSL https://raw.githubusercontent.com/hideyukiMORI/nene-wire/main/install-translator.sh | bash
```

- Needs Python 3 and pip (on Ubuntu: `sudo apt install python3-pip`). Takes about 470 MB: the Python packages in `~/.local/share/nene-wire/argos` and the model in `~/.local/share/argos-translate`
- Argos normally pulls in PyTorch (several hundred MB to a few GB). This installer leaves it out and splits sentences with MiniSBD instead, which is one of Argos's own settings
- Without it, nothing breaks: stories run in their original language, English ones are marked `未翻訳` (untranslated), and the status line says `TRANS 未導入` (not installed)
- Translations are kept and not redone while it runs (they are not saved across restarts yet). About 100 stories take roughly 20 seconds, in the background

### The effects

Every story gets the full treatment, all drawn with nothing but characters and colors:

| Boot sequence | Decrypt |
| --- | --- |
| ![The boot log](docs/images/boot.png) | ![Characters spinning before they lock](docs/images/decrypt.png) |
| **Ghost in the signal** | **Switch** |
| ![A glitch burst](docs/images/glitch.png) | ![The old story falling away](docs/images/drop.png) |

- **Decrypt**: `復号中 NN%` with a progress bar while each character spins through katakana and hex before locking in. Three ways to lock: one at a time, left to right, or scattered like a cipher coming apart
- **Switch**: the old story's characters fall away under gravity, or a scan line wipes it
- **Ghost in the signal**: twice per story, a burst of noise: the headline splits into cyan and magenta, a line slips sideways, `S1GN4L ▒▒▒▒ L0ST`
- **Intercept**: breaking news sounds an alarm first: hazard stripes and a crawling `INTERCEPT ■ 緊急傍受 ■ PRIORITY: ALPHA` banner
- **Boot sequence**: until the first story, the frame types out a boot log built from the real fetch results, with a hex dump running in DATA
- **HUD**: a light sweeps the header, the frame breathes, data rain falls in DATA with the time to the next sync and the uptime, and the bottom edge of the frame burns down like a fuse until the next story

### Reading the screen

![An English story shown in Japanese, with the original headline](docs/images/translation.png)

- **Header**: the name, the state of the line (`LINK ESTABLISHED` / `LINK PENDING` / `LINK LOST`) and the local date and time
- **Story frame**: the feed's name and the time on top. Inside: `受信` (received) with the story's number and publication time (UTC), the headline (up to two lines), the lede, `原文` (the original headline, when translated), and the link. A story that cut in as breaking news is marked `速報`
- **DATA**: one row per feed. `●` fetched (dim when nothing changed), `~` fetching right now, `!` failed (`ERR`), `·` not fetched yet, and how many stories it has
- **MSG**: what the fetcher just did: fetching, how many stories and how many new, unchanged, or why it failed and how many minutes until it tries again
- **Status**: position in the cycle, `NET ● ONLINE` / `OFFLINE`, how many feeds are live, `TRANS en>ja ● 待ち N` (translating, N waiting), breaking stories waiting, and the keys

Wide characters take two columns. Japanese and English wrap by cell width without breaking the frame.

### How it fetches

- One feed at a time, through `curl`. Each feed waits **15 minutes** after a successful fetch, and after a failure it backs off 2, 4, 8… minutes, up to 60
- Conditional requests: it sends back the `ETag` / `Last-Modified` it got last time, so an unchanged feed costs a `304` and nothing more
- It keeps only the latest fetch of each feed, so memory doesn't grow overnight (a 95-minute run stayed at about 12.5 MB)
- When a cycle ends, it is rebuilt from the latest stories, taking turns between feeds and going newest first. New stories don't wait for the cycle: they cut in next, up to 20 queued

---

## Under the hood (a story in six parts)

NeNe Wire wears the face of a news ticker, but like its siblings it is also **an experiment in having machines enforce the rules**.
Everything from the first commit to the v0.2.0 release happened in a single day, 2026-10-26. Every number below is in the repository's records (ADRs, tests, gate proofs).

### 1. The design was argued over in a mock-up, three times

The first design was a box in the middle of the screen with data rain all around it. The project owner said the direction was right but the box should be about a quarter of the screen with a fluid frame.
The next version made the box half the width and half the height. The owner: *"Not half the window's height. Full width, and around 15 rows."* Then: *"Just hard-code 15 rows."*
The first build drew the strip under your prompt and kept the fetch log above it. The owner: *"I picture it running all the time, like the ticker at the bottom of a news broadcast. Don't leave a fetch log; put it on a HUD message line. Fixed layout."* And finally: *"Clear the whole screen on launch and draw at the very top."*
Each of these is a decision in [REQUIREMENTS](docs/REQUIREMENTS.md) (Q9, Q11) and an ADR ([0006](docs/adr/0006-full-width-strip-display.md), [0007](docs/adr/0007-always-on-ticker.md)).

### 2. Waiting for the network without a single thread

Concurrency is banned in every target: no `async`, no `Task`, no threads, no Dispatch. A home-grown conformance check fails the build on the words alone.
So the fetcher starts `curl` as a child process and returns immediately. The one loop in the program calls `poll(2)` on the keyboard **and** the child's pipes at the same time, reads whatever has arrived, and draws.
Keys keep working while a feed is being fetched, and quitting mid-fetch stops `curl` too.

### 3. The width of a character comes from Unicode itself

Swift's standard library can tell a combining mark from a letter, but not whether a character takes one column or two. Foundation is banned too.
So the table comes from the primary source: a script reads Unicode 16.0's `EastAsianWidth.txt`, **refuses to run if its SHA-256 doesn't match**, and generates 122 ranges of wide characters.
Ambiguous-width characters count as one column, as in Windows Terminal; otherwise box-drawing lines would be counted as two and the frame would break.
Line breaking never starts a line with `、` `。` or a closing bracket: the previous character is carried over with it ([ADR 0006](docs/adr/0006-full-width-strip-display.md)).

### 4. Running it for 95 minutes found a bug the tests didn't

To check that nothing grows overnight, the release binary was left running for 95 minutes inside a pseudo-terminal, sampling its memory every five minutes.
Memory started at 9.8 MB and flattened out at 12.5 MB. The 15-minute refetches arrived on time, and NHK answered `304 Not Modified`.
But the log of the MSG line only ever showed two of the four feeds. When one feed finished, the next one started in the same instant and its "fetching…" message overwrote the result before it was ever drawn.
That became Issue #9 and was fixed. A screenshot of a breaking story in `--demo` then confirmed what the run couldn't count.

### 5. Rules aren't written down, they're enforced

The repository has 72 rules, each with an ID and a status saying whether a machine enforces it. Right now **51 are active** (break one and `make check` fails).
The rest are honestly labeled "not yet checked by a machine (planned)" or "cannot be blocked by a machine" ([quality gates](docs/QUALITY_GATES.md)).
The rules came from the siblings, but the measurements were not trusted to carry over: Swift 6.4.1's behavior was measured again here in 75 cases before any product code existed,
and no check is trusted until it has been seen to fail. Violations were planted one at a time, and **63 cases** are recorded in which the intended rule caught them (plus two controls that must pass) ([gate proofs](docs/quality/gate-proofs.md)).
The release itself is one of them: drop static linking from the packaging script and it refuses to package a binary that depends on the Swift runtime.

### 6. Screenshots without the news

This is a personal viewing tool, and real headlines and ledes are never stored in or redistributed from this repository.
That rules out screenshots of the real thing. So `--demo` runs the same fetch → schedule → rotation path on four made-up feeds, and a made-up breaking story arrives after 20 seconds.
Every screenshot on this page was taken from the released v0.2.0 binary that way ([ADR 0008](docs/adr/0008-release-pipeline-and-demo.md)).

---

## Development

```bash
make bootstrap           # once after cloning (commit hook and a static SwiftLint binary)
make check               # the one definition of done, identical locally and on CI (build, tests, format, lint, conformance, commit format)
make release TAG=v<ver>  # build the release artifacts (only if they pass the checks)
```

- Swift 6.4.1 (`.swift-version`), SwiftPM only, zero external Swift dependencies in the product
- Entry points: [CLAUDE.md](CLAUDE.md) (Japanese) and [AGENTS.md](AGENTS.md) (English). What the machines enforce right now is in [docs/QUALITY_GATES.md](docs/QUALITY_GATES.md); the owner's requirements are in [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)

## License

MIT ([LICENSE](LICENSE))
