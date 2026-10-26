#!/bin/bash
# NeNe Wire translator setup: installs Argos Translate (without torch) and the English -> Japanese model.
#
#   curl -fsSL https://raw.githubusercontent.com/hideyukiMORI/nene-wire/main/install-translator.sh | bash
#
# Installs the Python packages into ~/.local/share/nene-wire/argos/lib (nowhere else) and the model into
# ~/.local/share/argos-translate (Argos Translate's own place). About 350 MB + 130 MB. To remove both:
#   rm -rf ~/.local/share/nene-wire/argos ~/.local/share/argos-translate/packages/en_ja
set -euo pipefail

dir="$HOME/.local/share/nene-wire/argos"

fail() {
    echo "nene-wire translator: $1" >&2
    exit 1
}

command -v python3 > /dev/null || fail "python3 is required"
python3 -m pip --version > /dev/null 2>&1 || fail "pip is required (on Ubuntu: sudo apt install python3-pip)"

echo "nene-wire translator: installing Argos Translate into $dir/lib"
# Argos itself wants stanza (and through it, torch). NeNe Wire splits sentences with MiniSBD instead, so Argos is installed
# without its dependencies and only what it really uses is added, with fixed versions.
python3 -m pip install --quiet --disable-pip-version-check --upgrade --target "$dir/lib" --no-deps "argostranslate==1.11.0"
python3 -m pip install --quiet --disable-pip-version-check --upgrade --target "$dir/lib" \
    "ctranslate2==4.8.4" "sentencepiece==0.2.2" "minisbd==0.9.5" "sacremoses==0.1.1" "packaging==26.3"

echo "nene-wire translator: downloading the English -> Japanese model"
PYTHONPATH="$dir/lib" ARGOS_CHUNK_TYPE=MINISBD python3 - << 'PY'
import sys, types
sys.modules.setdefault('stanza', types.ModuleType('stanza'))
import argostranslate.package as package
import argostranslate.translate as translate
installed = {(p.from_code, p.to_code) for p in package.get_installed_packages()}
if ('en', 'ja') not in installed:
    package.update_package_index()
    wanted = next(p for p in package.get_available_packages() if p.from_code == 'en' and p.to_code == 'ja')
    package.install_from_path(wanted.download())
print('nene-wire translator: test -> ' + translate.translate('Night trains return to the coastal line', 'en', 'ja'))
PY
echo "nene-wire translator: done. Start nene-wire and English headlines are shown in Japanese."
