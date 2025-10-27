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
    API_URL="https://api.github.com/repos/TUBAF-IfI-LiaScript/VL_${REPO_NAME}/commits/master"
    
    # Try jq first (more reliable), fallback to grep
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
    # Note: Cache will be updated by the build system after successful build
    exit 0  # Rebuild needed
else
    echo "⏭️  No changes detected - skipping"
    exit 1  # No rebuild needed
fi