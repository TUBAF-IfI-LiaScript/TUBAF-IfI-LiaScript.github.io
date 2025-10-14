#!/bin/bash

# Smart change detection for LiaScript courses
# Usage: ./check_changes.sh <course_name>

COURSE=$1
if [ -z "$COURSE" ]; then
    echo "Usage: $0 <course_name>"
    exit 1
fi

# Create cache directory
mkdir -p .cache

# File paths
YAML_FILE="${COURSE}.yml"
HTML_FILE="${COURSE}.html"
CACHE_FILE=".cache/${COURSE}"

# Check if YAML file exists
if [ ! -f "$YAML_FILE" ]; then
    echo "❌ YAML file $YAML_FILE not found"
    exit 1
fi

# Calculate YAML hash
YAML_HASH=$(sha256sum "$YAML_FILE" 2>/dev/null | cut -d' ' -f1 || echo "missing")

# Get remote repository hash
case "$COURSE" in
    "digitalesysteme")
        REPO_NAME="EingebetteteSysteme"
        ;;
    "prozprog")
        REPO_NAME="ProzeduraleProgrammierung"
        ;;
    "softwareentwicklung")
        REPO_NAME="Softwareentwicklung"
        ;;
    "robotikprojekt")
        REPO_NAME="Robotikprojekt"
        ;;
    "index")
        REPO_NAME=""  # No remote monitoring for index
        ;;
    *)
        REPO_NAME=""
        ;;
esac

if [ -n "$REPO_NAME" ]; then
    echo "🌐 Checking VL_${REPO_NAME} repository..."
    REMOTE_HASH=$(curl -s --connect-timeout 10 \
        "https://api.github.com/repos/TUBAF-IfI-LiaScript/VL_${REPO_NAME}/commits/master" \
        2>/dev/null | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unreachable")
else
    REMOTE_HASH="no-remote"
fi

# Read cached values
if [ -f "$CACHE_FILE" ]; then
    CACHED_YAML=$(sed -n '1p' "$CACHE_FILE" 2>/dev/null || echo "missing")
    CACHED_REMOTE=$(sed -n '2p' "$CACHE_FILE" 2>/dev/null || echo "missing")
else
    CACHED_YAML="missing"
    CACHED_REMOTE="missing"
fi

# Display status
echo "📄 YAML hash: ${YAML_HASH:0:8}..."
echo "🌐 Remote hash: ${REMOTE_HASH:0:8}..."
echo "💾 Cached YAML: ${CACHED_YAML:0:8}..."
echo "💾 Cached remote: ${CACHED_REMOTE:0:8}..."

# Check for changes
REBUILD_NEEDED=false
REASON=""

if [ "$YAML_HASH" != "$CACHED_YAML" ]; then
    REBUILD_NEEDED=true
    REASON="YAML file changed"
elif [ "$REMOTE_HASH" != "$CACHED_REMOTE" ] && [ "$REMOTE_HASH" != "unreachable" ]; then
    REBUILD_NEEDED=true
    REASON="Remote repository changed"
elif [ ! -f "$HTML_FILE" ]; then
    REBUILD_NEEDED=true
    REASON="HTML file missing"
fi

# Output result
if [ "$REBUILD_NEEDED" = true ]; then
    echo "✅ $REASON - rebuild needed"
    # Update cache
    echo "$YAML_HASH" > "$CACHE_FILE"
    echo "$REMOTE_HASH" >> "$CACHE_FILE"
    exit 0  # Rebuild needed
else
    echo "⏭️  No changes detected - skipping"
    exit 1  # No rebuild needed
fi