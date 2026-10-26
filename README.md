# NeNe Wire

A terminal news screensaver: world and Japanese headlines and ledes, one at a time, with geeky cyber effects.
Foreign-language items are translated into the language you choose (Japanese by default), with a translator that needs no account and runs offline where possible.
Written in Swift for Ubuntu on WSL2 and Windows Terminal. A sibling of [NeNe Gambit](https://github.com/hideyukiMORI/nene-gambit) and [NeNe Reversi](https://github.com/hideyukiMORI/nene-reversi).

🚧 **Nothing runs yet.** The rules and the gate are being put in place before any product code is written (Issue #1).
The first product step fetches feeds and lists headlines and ledes as plain text.

## Development

```bash
make bootstrap   # once after cloning (commit hook and a static SwiftLint binary)
make check       # the one definition of done, identical locally and on CI
```

- Swift 6.4.1 (`.swift-version`), SwiftPM only, zero external Swift dependencies in the product
- Entry points: [CLAUDE.md](CLAUDE.md) (Japanese) and [AGENTS.md](AGENTS.md) (English). What the machines enforce right now is in [docs/QUALITY_GATES.md](docs/QUALITY_GATES.md); the owner's requirements are in [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)

## License

MIT ([LICENSE](LICENSE))
