#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP_ROOT=$(mktemp -d)
REMOTE_REPO="$TMP_ROOT/remote.git"
SOURCE_REPO="$TMP_ROOT/source"
INSTALL_REPO="$TMP_ROOT/install"
TEST_BIN="$TMP_ROOT/bin"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

git init --bare --quiet "$REMOTE_REPO"
git clone --quiet "$REMOTE_REPO" "$SOURCE_REPO"
git -C "$SOURCE_REPO" config user.name "Omybuntu Tests"
git -C "$SOURCE_REPO" config user.email "tests@omybuntu.invalid"
git -C "$SOURCE_REPO" switch --quiet -c dev

printf 'current dev\n' > "$SOURCE_REPO/state"
git -C "$SOURCE_REPO" add state
git -C "$SOURCE_REPO" commit --quiet -m "current dev release"
GIT_COMMITTER_DATE="2025-01-01T00:00:00Z" \
  git -C "$SOURCE_REPO" tag -a v1.1.7_dev -m "current dev tag"

git -C "$SOURCE_REPO" switch --quiet --orphan unrelated
git -C "$SOURCE_REPO" rm --quiet -rf . 2>/dev/null || true
printf 'unrelated\n' > "$SOURCE_REPO/state"
git -C "$SOURCE_REPO" add state
git -C "$SOURCE_REPO" commit --quiet -m "unrelated release line"
GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" \
  git -C "$SOURCE_REPO" tag -a v9.0.0_dev -m "unrelated dev tag"

git -C "$SOURCE_REPO" push --quiet origin dev unrelated --tags
git clone --quiet --branch dev "$REMOTE_REPO" "$INSTALL_REPO"

mkdir -p "$TEST_BIN"
printf '#!/bin/bash\necho dev\n' > "$TEST_BIN/omybuntu-version-channel"
chmod +x "$TEST_BIN/omybuntu-version-channel"

set +e
output=$(PATH="$TEST_BIN:$PATH" OMYBUNTU_PATH="$INSTALL_REPO" \
  "$ROOT/bin/omybuntu-update-available")
status=$?
set -e
(( status == 1 )) || fail "up-to-date check returns status 1"
[[ $output == *"up to date (v1.1.7_dev)"* ]] || \
  fail "current dev tag remains ahead of the stable release line"
pass "current channel tag is recognized as installed"

git -C "$SOURCE_REPO" switch --quiet dev
printf 'next dev\n' > "$SOURCE_REPO/state"
git -C "$SOURCE_REPO" commit --quiet -am "publish next dev release"
GIT_COMMITTER_DATE="2026-02-01T00:00:00Z" \
  git -C "$SOURCE_REPO" tag -a v1.1.8_dev -m "next dev tag"
git -C "$SOURCE_REPO" push --quiet origin dev --tags

output=$(PATH="$TEST_BIN:$PATH" OMYBUNTU_PATH="$INSTALL_REPO" \
  "$ROOT/bin/omybuntu-update-available") || \
  fail "new reachable channel tag reports an update"
[[ $output == *"update available (v1.1.8_dev)"* ]] || \
  fail "newest reachable dev tag is selected"
pass "new reachable channel tag reports an update"

if [[ $output == *v9.0.0_dev* ]]; then
  fail "tag from an unrelated branch is ignored"
fi
pass "tag from an unrelated branch is ignored"
