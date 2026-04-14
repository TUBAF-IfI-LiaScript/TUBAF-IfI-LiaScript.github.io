Cram CLI tests for scripts/check_changes.sh
============================================
These tests verify the command-line interface behaviour seen by a user.
$REPO_ROOT must be set to the repository root before running cram.

Helper: strip non-ASCII bytes and leading/trailing whitespace so that
emoji-prefixed output lines compare cleanly against plain-text expectations.

  $ ascii() { LC_ALL=C sed 's/[^[:print:]]//g; s/^[[:space:]]*//; s/[[:space:]]*$//'; }

No argument → usage message, non-zero exit
------------------------------------------

  $ output=$(bash "$REPO_ROOT/scripts/check_changes.sh" 2>&1); status=$?; printf '%s\n' "$output" | ascii | grep "Usage:"; echo "exit:$status"
  Usage: */check_changes.sh <course_name> (glob)
  exit:1

Missing YAML file → error message, non-zero exit
-------------------------------------------------

  $ output=$(bash "$REPO_ROOT/scripts/check_changes.sh" "doesnotexist" 2>&1); status=$?; printf '%s\n' "$output" | ascii | grep "not found"; echo "exit:$status"
  YAML file doesnotexist.yml not found
  exit:1

First run – no cache, no HTML → rebuild needed
-----------------------------------------------

  $ WORK=$(mktemp -d)
  $ mkdir -p "$WORK/mock_bin"
  $ printf '#!/usr/bin/env bash\necho '"'"'{"sha":"deadbeef","commit":{}}'"'"'\n' > "$WORK/mock_bin/curl"
  $ chmod +x "$WORK/mock_bin/curl"
  $ echo "title: Test" > "$WORK/digitalesysteme.yml"
  $ (cd "$WORK" && env PATH="$WORK/mock_bin:$PATH" bash "$REPO_ROOT/scripts/check_changes.sh" "digitalesysteme" 2>&1 | ascii | grep "rebuild needed")
  * rebuild needed (glob)
  $ rm -rf "$WORK"

Cache current – nothing changed → no rebuild
---------------------------------------------

  $ WORK=$(mktemp -d)
  $ mkdir -p "$WORK/mock_bin" "$WORK/.cache"
  $ printf '#!/usr/bin/env bash\necho '"'"'{"sha":"aabbccdd","commit":{}}'"'"'\n' > "$WORK/mock_bin/curl"
  $ chmod +x "$WORK/mock_bin/curl"
  $ echo "title: Test" > "$WORK/digitalesysteme.yml"
  $ touch "$WORK/digitalesysteme.html"
  $ YHASH=$(sha256sum "$WORK/digitalesysteme.yml" | cut -d' ' -f1)
  $ printf "%s\naabbccdd\n" "$YHASH" > "$WORK/.cache/digitalesysteme"
  $ (cd "$WORK" && env PATH="$WORK/mock_bin:$PATH" bash "$REPO_ROOT/scripts/check_changes.sh" "digitalesysteme" 2>&1 | ascii | grep "changes")
  No changes detected - skipping
  $ rm -rf "$WORK"

YAML file changed → rebuild needed, reason shown
-------------------------------------------------

  $ WORK=$(mktemp -d)
  $ mkdir -p "$WORK/mock_bin" "$WORK/.cache"
  $ printf '#!/usr/bin/env bash\necho '"'"'{"sha":"aabbccdd","commit":{}}'"'"'\n' > "$WORK/mock_bin/curl"
  $ chmod +x "$WORK/mock_bin/curl"
  $ echo "title: Test" > "$WORK/digitalesysteme.yml"
  $ touch "$WORK/digitalesysteme.html"
  $ printf "stale_yaml_hash\naabbccdd\n" > "$WORK/.cache/digitalesysteme"
  $ (cd "$WORK" && env PATH="$WORK/mock_bin:$PATH" bash "$REPO_ROOT/scripts/check_changes.sh" "digitalesysteme" 2>&1 | ascii | grep "rebuild needed")
  YAML file changed - rebuild needed
  $ rm -rf "$WORK"

Remote hash changed → rebuild needed, reason shown
---------------------------------------------------

  $ WORK=$(mktemp -d)
  $ mkdir -p "$WORK/mock_bin" "$WORK/.cache"
  $ printf '#!/usr/bin/env bash\necho '"'"'{"sha":"newsha9999","commit":{}}'"'"'\n' > "$WORK/mock_bin/curl"
  $ chmod +x "$WORK/mock_bin/curl"
  $ echo "title: Test" > "$WORK/digitalesysteme.yml"
  $ touch "$WORK/digitalesysteme.html"
  $ YHASH=$(sha256sum "$WORK/digitalesysteme.yml" | cut -d' ' -f1)
  $ printf "%s\noldsha1111\n" "$YHASH" > "$WORK/.cache/digitalesysteme"
  $ (cd "$WORK" && env PATH="$WORK/mock_bin:$PATH" bash "$REPO_ROOT/scripts/check_changes.sh" "digitalesysteme" 2>&1 | ascii | grep "rebuild needed")
  Remote repository changed - rebuild needed
  $ rm -rf "$WORK"

Course without upstream mapping (index) → no rebuild
-----------------------------------------------------

  $ WORK=$(mktemp -d)
  $ mkdir -p "$WORK/mock_bin" "$WORK/.cache"
  $ printf '#!/usr/bin/env bash\necho "SHOULD NOT BE CALLED"\nexit 1\n' > "$WORK/mock_bin/curl"
  $ chmod +x "$WORK/mock_bin/curl"
  $ echo "title: Index" > "$WORK/index.yml"
  $ touch "$WORK/index.html"
  $ YHASH=$(sha256sum "$WORK/index.yml" | cut -d' ' -f1)
  $ printf "%s\nno-remote\n" "$YHASH" > "$WORK/.cache/index"
  $ (cd "$WORK" && env PATH="$WORK/mock_bin:$PATH" bash "$REPO_ROOT/scripts/check_changes.sh" "index" 2>&1 | ascii | grep "changes")
  No changes detected - skipping
  $ rm -rf "$WORK"
