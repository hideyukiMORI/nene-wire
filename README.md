# NeNe Wire

A terminal news screensaver: world and Japanese headlines and ledes, one at a time, with geeky cyber effects.
Foreign-language items are translated into the language you choose (Japanese by default), with a translator that needs no account and runs offline where possible.
Written in Swift for Ubuntu on WSL2 and Windows Terminal. A sibling of [NeNe Gambit](https://github.com/hideyukiMORI/nene-gambit) and [NeNe Reversi](https://github.com/hideyukiMORI/nene-reversi).

🚧 **Early.** `nene-wire` fetches the default feeds (NHK, BBC World, NPR News, The Guardian World) once at startup and shows one article at a time in a full-width, 15-row strip below your prompt (no effects yet). `q` quits, space pauses, ←/→ move between articles. `nene-wire --list` prints headlines and ledes as plain text.
The screen comes next.

## Development

```bash
make bootstrap   # once after cloning (commit hook and a static SwiftLint binary)
make check       # the one definition of done, identical locally and on CI
```

- Swift 6.4.1 (`.swift-version`), SwiftPM only, zero external Swift dependencies in the product
- Entry points: [CLAUDE.md](CLAUDE.md) (Japanese) and [AGENTS.md](AGENTS.md) (English). What the machines enforce right now is in [docs/QUALITY_GATES.md](docs/QUALITY_GATES.md); the owner's requirements are in [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)

## License

MIT ([LICENSE](LICENSE))
