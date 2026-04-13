#!/usr/bin/env bats
# Unit tests for scripts/check_changes.sh
#
# Approach
# --------
# setup() creates an isolated working directory, changes into it, and puts a
# mock `curl` binary at the front of PATH so no real network calls are made.
# Each @test runs in its own subshell, so the cd in setup() is local to that
# test.  teardown() removes the temp directories.
#
# check_changes.sh sources courses_lib.sh from its own (production) scripts/
# directory, so the real courses.conf is used.  Tests use real course names:
#   digitalesysteme – has an upstream mapping in courses.conf
#   index           – listed in COURSES but has NO upstream mapping

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/check_changes.sh"

# ---------------------------------------------------------------------------
# Per-test lifecycle
# ---------------------------------------------------------------------------
setup() {
  TEST_DIR="$(mktemp -d)"
  MOCK_BIN="$(mktemp -d)"
  # Change into the isolated work directory so check_changes.sh reads/writes
  # YAML, HTML, and .cache files from there.
  cd "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR" "$MOCK_BIN"
}

# make_mock_curl <sha>
# Writes a mock curl binary to $MOCK_BIN.
# Pass "ERROR" to simulate a network failure (empty response).
make_mock_curl() {
  local sha="$1"
  if [ "$sha" = "ERROR" ]; then
    cat > "$MOCK_BIN/curl" << 'MOCK'
#!/usr/bin/env bash
echo ""
exit 0
MOCK
  else
    # shellcheck disable=SC2016
    printf '#!/usr/bin/env bash\necho '"'"'{"sha":"%s","commit":{}}'"'"'\n' "$sha" \
      > "$MOCK_BIN/curl"
  fi
  chmod +x "$MOCK_BIN/curl"
}

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------

@test "no argument: prints usage and exits non-zero" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "missing YAML: exits non-zero with error message" {
  make_mock_curl "abc123"
  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "digitalesysteme"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

# ---------------------------------------------------------------------------
# First-run (no cache)
# ---------------------------------------------------------------------------

@test "no cache, no HTML: rebuild needed (exit 0)" {
  make_mock_curl "deadbeef1234"
  echo "title: Test" > digitalesysteme.yml

  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "digitalesysteme"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rebuild needed"* ]]
}

@test "no cache, HTML present: rebuild needed because no cached hash" {
  make_mock_curl "deadbeef1234"
  echo "title: Test" > digitalesysteme.yml
  touch digitalesysteme.html

  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "digitalesysteme"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Cache matches – nothing changed
# ---------------------------------------------------------------------------

@test "cache matches YAML + remote + HTML present: no rebuild (exit 1)" {
  local remote_sha="aabbccddeeff0011"
  make_mock_curl "$remote_sha"

  echo "title: Test" > digitalesysteme.yml
  touch digitalesysteme.html

  mkdir -p .cache
  local yaml_hash
  yaml_hash=$(sha256sum digitalesysteme.yml | cut -d' ' -f1)
  printf "%s\n%s\n" "$yaml_hash" "$remote_sha" > .cache/digitalesysteme

  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "digitalesysteme"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No changes detected"* ]]
}

# ---------------------------------------------------------------------------
# Individual change triggers
# ---------------------------------------------------------------------------

@test "YAML changed: rebuild needed with reason" {
  local remote_sha="aabbccddeeff0011"
  make_mock_curl "$remote_sha"

  echo "title: Test" > digitalesysteme.yml
  touch digitalesysteme.html

  mkdir -p .cache
  printf "%s\n%s\n" "stale_yaml_hash_value_0000" "$remote_sha" \
    > .cache/digitalesysteme

  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "digitalesysteme"
  [ "$status" -eq 0 ]
  [[ "$output" == *"YAML file changed"* ]]
}

@test "remote hash changed: rebuild needed with reason" {
  local new_sha="newsha9999"
  make_mock_curl "$new_sha"

  echo "title: Test" > digitalesysteme.yml
  touch digitalesysteme.html

  mkdir -p .cache
  local yaml_hash
  yaml_hash=$(sha256sum digitalesysteme.yml | cut -d' ' -f1)
  printf "%s\n%s\n" "$yaml_hash" "oldsha1111" > .cache/digitalesysteme

  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "digitalesysteme"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Remote repository changed"* ]]
}

@test "HTML file missing: rebuild needed with reason" {
  local remote_sha="aabbccddeeff0011"
  make_mock_curl "$remote_sha"

  echo "title: Test" > digitalesysteme.yml
  # No HTML file

  mkdir -p .cache
  local yaml_hash
  yaml_hash=$(sha256sum digitalesysteme.yml | cut -d' ' -f1)
  printf "%s\n%s\n" "$yaml_hash" "$remote_sha" > .cache/digitalesysteme

  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "digitalesysteme"
  [ "$status" -eq 0 ]
  [[ "$output" == *"HTML file missing"* ]]
}

# ---------------------------------------------------------------------------
# Remote unreachable
# ---------------------------------------------------------------------------

@test "remote unreachable, nothing else changed: no rebuild (exit 1)" {
  make_mock_curl "ERROR"

  echo "title: Test" > digitalesysteme.yml
  touch digitalesysteme.html

  mkdir -p .cache
  local yaml_hash
  yaml_hash=$(sha256sum digitalesysteme.yml | cut -d' ' -f1)
  printf "%s\n%s\n" "$yaml_hash" "unreachable" > .cache/digitalesysteme

  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "digitalesysteme"
  [ "$status" -eq 1 ]
}

@test "remote unreachable but YAML changed: rebuild still triggered" {
  make_mock_curl "ERROR"

  echo "title: Test" > digitalesysteme.yml
  touch digitalesysteme.html

  mkdir -p .cache
  printf "%s\n%s\n" "stale_yaml_hash" "unreachable" > .cache/digitalesysteme

  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "digitalesysteme"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Course without a remote mapping (index)
# ---------------------------------------------------------------------------

@test "no remote mapping, cache current: no rebuild (exit 1)" {
  make_mock_curl "SHOULD_NOT_BE_CALLED"

  echo "title: Index" > index.yml
  touch index.html

  mkdir -p .cache
  local yaml_hash
  yaml_hash=$(sha256sum index.yml | cut -d' ' -f1)
  printf "%s\n%s\n" "$yaml_hash" "no-remote" > .cache/index

  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "index"
  [ "$status" -eq 1 ]
}

@test "no remote mapping, YAML changed: rebuild needed" {
  make_mock_curl "SHOULD_NOT_BE_CALLED"

  echo "title: Index" > index.yml
  touch index.html

  mkdir -p .cache
  printf "%s\n%s\n" "stale_hash" "no-remote" > .cache/index

  run env PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "index"
  [ "$status" -eq 0 ]
}
