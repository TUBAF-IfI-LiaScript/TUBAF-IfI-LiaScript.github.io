#!/bin/bash

# Smart change detection for LiaScript courses
# Usage: ./check_changes.sh <course_name>

COURSE=$1
if [ -z "$COURSE" ]; then
    echo "Usage: $0 <course_name>"
    exit 1
fi

# File paths
YAML_FILE="${COURSE}.yml"
HTML_FILE="${COURSE}.html"
CACHE_FILE=".cache/${COURSE}"

# Get remote repository name from central config via shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=courses_lib.sh
. "${SCRIPT_DIR}/courses_lib.sh"

# ---------------------------------------------------------------------------
# init – create required directories
# ---------------------------------------------------------------------------
init() {
    mkdir -p .cache
    if [ ! -f "$YAML_FILE" ]; then
        echo "❌ YAML file $YAML_FILE not found"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# get_yaml_hash – compute SHA-256 hash of the course YAML file.
# Sets YAML_HASH.
# ---------------------------------------------------------------------------
get_yaml_hash() {
    YAML_HASH=$(sha256sum "$YAML_FILE" 2>/dev/null | cut -d' ' -f1 || echo "missing")
}

# ---------------------------------------------------------------------------
# get_remote_hash – fetch the latest commit SHA from the upstream repository.
# Sets REMOTE_HASH.
# ---------------------------------------------------------------------------
get_remote_hash() {
    REPO_NAME=$(lookup_repo "$COURSE")

    if [ -n "$REPO_NAME" ]; then
        echo "🌐 Checking VL_${REPO_NAME} repository..."
        API_URL="https://api.github.com/repos/TUBAF-IfI-LiaScript/VL_${REPO_NAME}/commits/master"

        # Use -L to follow redirects (in case repository was renamed/moved)
        API_RESPONSE=$(curl -sL --connect-timeout 10 "$API_URL" 2>/dev/null)

        if command -v jq >/dev/null 2>&1; then
            REMOTE_HASH=$(echo "$API_RESPONSE" | jq -r '.sha' 2>/dev/null || echo "unreachable")
        else
            REMOTE_HASH=$(echo "$API_RESPONSE" | sed -n 's/.*"sha":"\([^"]*\)".*/\1/p' | head -1)
            if [ -z "$REMOTE_HASH" ]; then
                REMOTE_HASH="unreachable"
            fi
        fi

        if [ "$REMOTE_HASH" = "unreachable" ] || [ -z "$REMOTE_HASH" ]; then
            echo "⚠️  Failed to get remote hash"
            REMOTE_HASH="unreachable"
        fi
    else
        REMOTE_HASH="no-remote"
    fi
}

# ---------------------------------------------------------------------------
# read_cache – load previously stored hashes from cache file.
# Sets CACHED_YAML and CACHED_REMOTE.
# ---------------------------------------------------------------------------
read_cache() {
    if [ -f "$CACHE_FILE" ]; then
        CACHED_YAML=$(sed -n '1p' "$CACHE_FILE" 2>/dev/null || echo "missing")
        CACHED_REMOTE=$(sed -n '2p' "$CACHE_FILE" 2>/dev/null || echo "missing")
    else
        CACHED_YAML="missing"
        CACHED_REMOTE="missing"
    fi
}

# ---------------------------------------------------------------------------
# print_status – display current vs. cached hash values.
# ---------------------------------------------------------------------------
print_status() {
    echo "📄 YAML hash: ${YAML_HASH:0:8}..."
    echo "🌐 Remote hash: ${REMOTE_HASH:0:8}..."
    echo "💾 Cached YAML: ${CACHED_YAML:0:8}..."
    echo "💾 Cached remote: ${CACHED_REMOTE:0:8}..."
}

# ---------------------------------------------------------------------------
# check_rebuild_needed – determine if a rebuild is required.
# Exits 0 if rebuild needed, exits 1 if no rebuild needed.
# ---------------------------------------------------------------------------
check_rebuild_needed() {
    local rebuild_needed=false
    local reason=""

    if [ "$YAML_HASH" != "$CACHED_YAML" ]; then
        rebuild_needed=true
        reason="YAML file changed"
    elif [ "$REMOTE_HASH" != "$CACHED_REMOTE" ] && [ "$REMOTE_HASH" != "unreachable" ]; then
        rebuild_needed=true
        reason="Remote repository changed"
    elif [ ! -f "$HTML_FILE" ]; then
        rebuild_needed=true
        reason="HTML file missing"
    fi

    if [ "$rebuild_needed" = true ]; then
        echo "✅ $reason - rebuild needed"
        # Note: Cache will be updated by the build system after successful build
        exit 0  # Rebuild needed
    else
        echo "⏭️  No changes detected - skipping"
        exit 1  # No rebuild needed
    fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
    init
    get_yaml_hash
    get_remote_hash
    read_cache
    print_status
    check_rebuild_needed
}

main