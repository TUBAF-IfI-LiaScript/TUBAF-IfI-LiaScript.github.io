#!/usr/bin/env bash
# Download PDF release assets for a course from its upstream GitHub repository.
#
# Usage:  ./scripts/download_upstream_pdfs.sh <course_name>
# Env:    GITHUB_TOKEN  – optional, used to authenticate API calls and avoid rate-limiting
#
# Outputs:
#   assets/<course>/pdf/<name>.pdf  – downloaded files (only when not already present)
#   .cache/<course>_upstream_pdfs   – manifest: one PDF filename per line
#
# Exit codes:
#   0  – at least one upstream PDF was found / downloaded
#   1  – no upstream PDF release assets exist for this course

set -euo pipefail

COURSE="${1:-}"
if [ -z "$COURSE" ]; then
  echo "Usage: $0 <course_name>" >&2
  exit 1
fi

# Map course name → upstream repository name
case "$COURSE" in
  digitalesysteme)   REPO_NAME="EingebetteteSysteme" ;;
  prozprog)          REPO_NAME="ProzeduraleProgrammierung" ;;
  softwareentwicklung) REPO_NAME="Softwareentwicklung" ;;
  robotikprojekt)    REPO_NAME="SoftwareprojektRobotik" ;;
  *)
    echo "ℹ️  No upstream repo mapped for course '$COURSE'" >&2
    exit 1
    ;;
esac

REPO_ORG="TUBAF-IfI-LiaScript"
API_URL="https://api.github.com/repos/${REPO_ORG}/VL_${REPO_NAME}/releases?per_page=100"
PDF_DIR="assets/${COURSE}/pdf"
MANIFEST=".cache/${COURSE}_upstream_pdfs"

mkdir -p "$PDF_DIR" .cache

# Build auth header if token is available
CURL_AUTH=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  CURL_AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

echo "🔍 Checking upstream releases for VL_${REPO_NAME}..."
API_RESPONSE=$(curl -sL --connect-timeout 15 "${CURL_AUTH[@]}" "$API_URL" 2>/dev/null)

# Check for API error / rate-limit response
if echo "$API_RESPONSE" | grep -q '"message"' && ! echo "$API_RESPONSE" | grep -q '"assets"'; then
  MSG=$(echo "$API_RESPONSE" | grep -o '"message":"[^"]*"' | head -1 | sed 's/"message":"//;s/"$//')
  echo "⚠️  GitHub API error: ${MSG:-unknown error}" >&2
  exit 1
fi

# Extract PDF asset names and their download URLs.
# Deduplicate by name (keep first occurrence = most-recent release wins).
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️  jq is not installed – cannot parse GitHub release assets" >&2
  exit 1
fi

mapfile -t ALL_NAMES < <(
  echo "$API_RESPONSE" \
    | jq -r '.[].assets[] | select(.name | endswith(".pdf")) | .name' 2>/dev/null \
    || true
)
mapfile -t ALL_URLS < <(
  echo "$API_RESPONSE" \
    | jq -r '.[].assets[] | select(.name | endswith(".pdf")) | .browser_download_url' 2>/dev/null \
    || true
)

if [ "${#ALL_NAMES[@]}" -eq 0 ]; then
  echo "ℹ️  No PDF release assets found for VL_${REPO_NAME}"
  rm -f "$MANIFEST"
  exit 1
fi

# Deduplicate: keep the first occurrence of each filename
declare -A SEEN
NAMES=()
URLS=()
for i in "${!ALL_NAMES[@]}"; do
  name="${ALL_NAMES[$i]}"
  if [ -z "${SEEN[$name]+x}" ]; then
    SEEN["$name"]=1
    NAMES+=("$name")
    URLS+=("${ALL_URLS[$i]}")
  fi
done

echo "📦 Found ${#NAMES[@]} unique upstream PDF(s) for ${COURSE}"

# Download missing PDFs and build manifest
downloaded=0
already_present=0
> "${MANIFEST}.tmp"

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  url="${URLS[$i]}"
  target="${PDF_DIR}/${name}"

  echo "${name}" >> "${MANIFEST}.tmp"

  if [ -f "$target" ]; then
    already_present=$((already_present + 1))
  else
    echo "  ⬇️  Downloading ${name}..."
    curl -sL --connect-timeout 30 "${CURL_AUTH[@]}" -o "$target" "$url"
    downloaded=$((downloaded + 1))
  fi
done

# Atomically replace manifest
mv "${MANIFEST}.tmp" "$MANIFEST"

echo "✅ Upstream PDFs: ${downloaded} downloaded, ${already_present} already present"
exit 0
