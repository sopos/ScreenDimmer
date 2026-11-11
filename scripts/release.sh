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

# Workflow fixes must reach main even when the version tag already exists.
git diff --check
bash -n build.sh Tests/run.sh scripts/release.sh
git add ScreenDimmer build.sh Tests README.md CHANGELOG.md .github/workflows scripts
if ! git diff --cached --quiet; then
    git commit -m "Prepare ScreenDimmer $VERSION release"
fi
if ! git diff --quiet; then
    echo 'Uncommitted tracked changes remain; resolve them before releasing.' >&2
    exit 1
fi

RUN_EVENT=push
PREVIOUS_RUN_ID=''
ASSET_READY=false
if gh api "repos/$REPOSITORY/git/ref/tags/$TAG" >"$RELEASE_DIR/tag.json" 2>"$RELEASE_DIR/tag-error"; then
    git push origin main
    if gh release view "$TAG" --repo "$REPOSITORY" --json assets \
        --jq '.assets[].name' >"$RELEASE_DIR/assets" 2>/dev/null \
        && [[ $(cat "$RELEASE_DIR/assets") == *ScreenDimmer.zip* ]]; then
        echo "$TAG is already published; updating Homebrew."
        ASSET_READY=true
    else
        # Rerunning the old tag's run also reruns its old workflow. Dispatch the
        # fixed workflow on main while checking out the original tagged sources.
        echo "$TAG exists without a release ZIP; dispatching the workflow from main."
        RELEASE_COMMIT=$(git rev-parse HEAD)
        RUN_EVENT=workflow_dispatch
        PREVIOUS_RUN_ID=$(gh run list --repo "$REPOSITORY" --workflow release.yml \
            --event "$RUN_EVENT" --commit "$RELEASE_COMMIT" --json databaseId \
            --jq '.[0].databaseId // empty')
        gh workflow run release.yml --repo "$REPOSITORY" --ref main -f "tag=$TAG"
    fi
else
    if [[ $(cat "$RELEASE_DIR/tag-error") != *404* ]]; then
        cat "$RELEASE_DIR/tag-error" >&2
        exit 1
    fi
    RELEASE_COMMIT=$(git rev-parse HEAD)
    git tag "$TAG"
    git push --atomic origin main "refs/tags/$TAG"
fi

if [ "$ASSET_READY" = false ]; then
    # Wait for the new run rather than picking a previous cancelled attempt.
    RUN_ID=''
    for attempt in {1..30}; do
        RUN_ID=$(gh run list --repo "$REPOSITORY" --workflow release.yml \
            --event "$RUN_EVENT" --commit "$RELEASE_COMMIT" --json databaseId \
            --jq '.[0].databaseId // empty')
        if [ -n "$RUN_ID" ] && [ "$RUN_ID" != "$PREVIOUS_RUN_ID" ]; then break; fi
        RUN_ID=''
        sleep 2
    done
    if [ -z "$RUN_ID" ]; then
        echo 'Release workflow did not appear; inspect GitHub Actions before retrying.' >&2
        exit 1
    fi
    gh run watch "$RUN_ID" --repo "$REPOSITORY" --exit-status
fi
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
