#!/bin/bash
# NeNe Wire installer: downloads the latest release (or NENE_WIRE_VERSION), verifies it against SHA256SUMS, then installs it.
#
#   curl -fsSL https://raw.githubusercontent.com/hideyukiMORI/nene-wire/main/install.sh | bash
#
# Installs into ~/.local/bin (override with NENE_WIRE_PREFIX). If verification fails, nothing is installed.
set -euo pipefail

repo="hideyukiMORI/nene-wire"
prefix="${NENE_WIRE_PREFIX:-$HOME/.local/bin}"

fail() {
    echo "nene-wire install: $1" >&2
    exit 1
}

[ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" = "x86_64" ] || fail "only Linux on x86_64 is supported (this is $(uname -s) $(uname -m))"
for tool in curl sha256sum tar install; do
    command -v "$tool" > /dev/null || fail "$tool is required"
done

version="${NENE_WIRE_VERSION:-}"
if [ -z "$version" ]; then
    latest="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest")"
    version="${latest##*/v}"
fi
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "could not determine the version: $version"

name="nene-wire-$version-linux-x86_64"
base="https://github.com/$repo/releases/download/v$version"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "nene-wire install: downloading v$version"
curl -fsSL -o "$work/$name.tar.gz" "$base/$name.tar.gz"
curl -fsSL -o "$work/SHA256SUMS" "$base/SHA256SUMS"
(cd "$work" && sha256sum --check --quiet SHA256SUMS) || fail "checksum does not match SHA256SUMS; nothing was installed"
tar -xzf "$work/$name.tar.gz" -C "$work"
install -Dm755 "$work/$name/nene-wire" "$prefix/nene-wire"

echo "nene-wire install: installed $prefix/nene-wire ($("$prefix/nene-wire" --version))"
case ":$PATH:" in
    *":$prefix:"*) echo "nene-wire install: run nene-wire (q quits; try nene-wire --demo to see it without the network)" ;;
    *) echo "nene-wire install: $prefix is not on this shell's PATH. Ubuntu adds ~/.local/bin when you log in, so a new terminal usually has it; or run export PATH=\"$prefix:\$PATH\"" ;;
esac
