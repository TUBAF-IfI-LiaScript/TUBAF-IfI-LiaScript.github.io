#!/usr/bin/env bash
# Download PDF release assets for a course from its upstream GitHub repository.
#
# Usage:  ./scripts/download_upstream_pdfs.sh <course_name>
# Env:    GITHUB_TOKEN  – optional, used to authenticate API calls and avoid rate-limiting
#
# Outputs:
#   assets/<course>/pdf/<name>.pdf  – downloaded files (re-downloaded when upstream URL changes)
#   .cache/<course>_upstream_pdfs   – manifest: one "filename<TAB>url" line per PDF
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

# Resolve this script's directory so courses.conf is always found regardless
# of the working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COURSES_CONF="${SCRIPT_DIR}/courses.conf"

# Map course name → upstream repository name via central config
REPO_NAME=$(grep -v '^\s*#' "$COURSES_CONF" | grep "^${COURSE}:" | cut -d: -f2 | tr -d '[:space:]' || true)
if [ -z "$REPO_NAME" ]; then
  echo "ℹ️  No upstream repo mapped for course '$COURSE'" >&2
  exit 1
fi

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
API_RESPONSE=$(curl -sL --connect-timeout 15 "${CURL_AUTH[@]}" "$API_URL")

# Check for API error / rate-limit response
if echo "$API_RESPONSE" | grep -q '"message"' && ! echo "$API_RESPONSE" | grep -q '"assets"'; then
  MSG=$(echo "$API_RESPONSE" | grep -o '"message":"[^"]*"' | head -1 | sed 's/"message":"//;s/"$//')
  echo "⚠️  GitHub API error: ${MSG:-unknown error}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️  jq is not installed – cannot parse GitHub release assets" >&2
  exit 1
fi

# Extract PDF asset names and their download URLs.
# Releases API returns newest-first; deduplicate by filename so the newest
# release's URL wins for each lesson PDF.
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

# Deduplicate: keep the first occurrence of each filename (= most-recent release)
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

# Load previously cached URLs so we can detect version updates.
# Manifest format: "<filename>\t<url>"
declare -A CACHED_URL
if [ -f "$MANIFEST" ]; then
  while IFS=$'\t' read -r cached_name cached_url; do
    [[ -z "$cached_name" ]] && continue
    CACHED_URL["$cached_name"]="$cached_url"
  done < "$MANIFEST"
fi

# Download PDFs that are missing or whose upstream URL has changed (new version).
downloaded=0
updated=0
already_present=0
> "${MANIFEST}.tmp"

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  url="${URLS[$i]}"
  target="${PDF_DIR}/${name}"

  printf '%s\t%s\n' "${name}" "${url}" >> "${MANIFEST}.tmp"

  if [ -f "$target" ] && [ "${CACHED_URL[$name]+x}" ] && [ "${CACHED_URL[$name]}" = "$url" ]; then
    # File exists and URL hasn't changed → already up-to-date
    already_present=$((already_present + 1))
  else
    if [ -f "$target" ]; then
      echo "  🔄 Updating ${name} (new release available)..."
      updated=$((updated + 1))
    else
      echo "  ⬇️  Downloading ${name}..."
      downloaded=$((downloaded + 1))
    fi
    if ! curl -fsSL --connect-timeout 30 "${CURL_AUTH[@]}" -o "$target" "$url"; then
      echo "  ⚠️  Failed to download ${name} from ${url}" >&2
      rm -f "$target"
      # Remove from manifest so the next run retries
      grep -v "^${name}	" "${MANIFEST}.tmp" > "${MANIFEST}.tmp2" && mv "${MANIFEST}.tmp2" "${MANIFEST}.tmp" || true
    fi
  fi
done

# Atomically replace manifest
mv "${MANIFEST}.tmp" "$MANIFEST"

echo "✅ Upstream PDFs: ${downloaded} new, ${updated} updated, ${already_present} already up-to-date"
exit 0
