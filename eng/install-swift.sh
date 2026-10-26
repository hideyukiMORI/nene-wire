#!/bin/bash
# CI のランナー（ubuntu-22.04）に .swift-version の Swift を固定の tarball から入れる（QLT-011）。
# swiftly の導入経路は廃止で CI が落ちた前例があるので使わない。照合値は eng/swift.lock。
# ローカルの WSL は swiftly で入れてあり、このスクリプトは使わない。
set -euo pipefail
cd "$(dirname "$0")/.."

version="$(tr -d '[:space:]' < .swift-version)"
read -r _ platform sha < <(grep -E "^${version//./\\.} " eng/swift.lock)
if [ -z "${sha:-}" ]; then
    echo "install-swift: eng/swift.lock に ${version} の行が無い" >&2
    exit 1
fi
dir_platform="${platform//./}"
name="swift-${version}-RELEASE-${platform}"
url="https://download.swift.org/swift-${version}-release/${dir_platform}/swift-${version}-RELEASE/${name}.tar.gz"
cache="${HOME}/.cache/swift-toolchain"
mkdir -p "$cache"
if [ ! -f "$cache/${name}.tar.gz" ]; then
    curl -sSfL -o "$cache/${name}.tar.gz.part" "$url"
    mv "$cache/${name}.tar.gz.part" "$cache/${name}.tar.gz"
fi
echo "${sha}  $cache/${name}.tar.gz" | sha256sum --check --quiet

sudo apt-get update -qq
sudo apt-get install -y -qq libcurl4-openssl-dev pkg-config python3-lldb-13 > /dev/null

prefix="${HOME}/swift-toolchain"
rm -rf "$prefix"
mkdir -p "$prefix"
tar -xzf "$cache/${name}.tar.gz" -C "$prefix" --strip-components=1
echo "${prefix}/usr/bin" >> "$GITHUB_PATH"
"${prefix}/usr/bin/swift" --version
