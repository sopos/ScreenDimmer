#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

REPOSITORY=sopos/ScreenDimmer
TAP_REPOSITORY=sopos/homebrew-screendimmer
VERSION=1.7.0
TAG="v$VERSION"

command -v gh >/dev/null || { echo 'Install GitHub CLI (gh) first.' >&2; exit 1; }
gh auth status
git var GIT_AUTHOR_IDENT >/dev/null
for repository in "$REPOSITORY" "$TAP_REPOSITORY"; do
    if [ "$(gh api "repos/$repository" --jq '.permissions.push')" != true ]; then
        echo "GitHub write access is required for $repository." >&2
        exit 1
    fi
done

if [ "$(git branch --show-current)" != main ]; then
    echo 'Run this release from the main branch.' >&2
    exit 1
fi

RELEASE_DIR=$(mktemp -d)
trap 'rm -rf "$RELEASE_DIR"' EXIT
gh repo clone "$TAP_REPOSITORY" "$RELEASE_DIR/tap"

if gh api "repos/$REPOSITORY/git/ref/tags/$TAG" >"$RELEASE_DIR/tag.json" 2>"$RELEASE_DIR/tag-error"; then
    # Allow rerunning to finish the tap update after a successful release.
    echo "$TAG already exists; waiting for its release before updating Homebrew."
    RELEASE_COMMIT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["object"]["sha"])' "$RELEASE_DIR/tag.json")
else
    if [[ $(cat "$RELEASE_DIR/tag-error") != *404* ]]; then
        cat "$RELEASE_DIR/tag-error" >&2
        exit 1
    fi
    git diff --check
    bash -n build.sh Tests/run.sh scripts/release.sh
    git add ScreenDimmer build.sh Tests README.md CHANGELOG.md .github/workflows scripts
    if ! git diff --cached --quiet; then
        git commit -m "Release 1.7.0 with optional built-in backlight blackout"
    fi
    if ! git diff --quiet; then
        echo 'Uncommitted tracked changes remain; resolve them before releasing.' >&2
        exit 1
    fi
    RELEASE_COMMIT=$(git rev-parse HEAD)
    git tag "$TAG"
    git push --atomic origin main "refs/tags/$TAG"
fi

# GitHub may take a few seconds to register the tag-triggered workflow.
RUN_ID=''
for attempt in {1..30}; do
    RUN_ID=$(gh run list --repo "$REPOSITORY" --workflow release.yml \
        --commit "$RELEASE_COMMIT" --json databaseId --jq '.[0].databaseId // empty')
    if [ -n "$RUN_ID" ]; then break; fi
    sleep 2
done
if [ -z "$RUN_ID" ]; then
    echo 'Release workflow did not appear; inspect GitHub Actions before retrying.' >&2
    exit 1
fi
gh run watch "$RUN_ID" --repo "$REPOSITORY" --exit-status
gh release download "$TAG" --repo "$REPOSITORY" \
    --pattern ScreenDimmer.zip --dir "$RELEASE_DIR"

python3 - "$VERSION" "$RELEASE_DIR" <<'PY'
import hashlib
from pathlib import Path
import re
import sys
import zipfile
import plistlib

version, directory = sys.argv[1], Path(sys.argv[2])
archive = directory / 'ScreenDimmer.zip'
with zipfile.ZipFile(archive) as bundle:
    info = plistlib.loads(bundle.read('ScreenDimmer.app/Contents/Info.plist'))
    assert info['CFBundleShortVersionString'] == info['CFBundleVersion'] == version
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
for cask in (Path('Casks/screen-dimmer.rb'), directory / 'tap/Casks/screen-dimmer.rb'):
    text = cask.read_text()
    text, versions = re.subn(r'(?m)^  version "[^"]+"$', f'  version "{version}"', text)
    text, checksums = re.subn(r'(?m)^  sha256 "[^"]+"$', f'  sha256 "{checksum}"', text)
    assert versions == checksums == 1, f'Unexpected cask format: {cask}'
    cask.write_text(text)
print(f'ScreenDimmer {version}: SHA-256 {checksum}')
PY

for checkout in . "$RELEASE_DIR/tap"; do
    git -C "$checkout" diff --check
    git -C "$checkout" add Casks/screen-dimmer.rb
    if ! git -C "$checkout" diff --cached --quiet; then
        git -C "$checkout" commit -m "Update ScreenDimmer cask to v$VERSION"
        git -C "$checkout" push origin main
    fi
done
gh release view "$TAG" --repo "$REPOSITORY" --json url --jq .url
echo "Homebrew tap updated to $VERSION."
