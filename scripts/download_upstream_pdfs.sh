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

# Resolve this script's directory so courses_lib.sh is always found regardless
# of the working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=courses_lib.sh
. "${SCRIPT_DIR}/courses_lib.sh"

# Global state shared between functions
NAMES=()        # deduplicated PDF asset names (set by parse_pdf_assets)
URLS=()         # corresponding download URLs  (set by parse_pdf_assets)
declare -A CACHED_URL  # manifest cache: name → url (set by load_manifest)

# ---------------------------------------------------------------------------
# validate_args – check required arguments and resolve course→repo mapping
# ---------------------------------------------------------------------------
validate_args() {
  COURSE="${1:-}"
  if [ -z "$COURSE" ]; then
    echo "Usage: $0 <course_name>" >&2
    exit 1
  fi

  REPO_NAME=$(lookup_repo "$COURSE")
  if [ -z "$REPO_NAME" ]; then
    echo "ℹ️  No upstream repo mapped for course '$COURSE'" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# setup_paths – set global path/URL variables and create required directories
# ---------------------------------------------------------------------------
setup_paths() {
  REPO_ORG="TUBAF-IfI-LiaScript"
  API_URL="https://api.github.com/repos/${REPO_ORG}/VL_${REPO_NAME}/releases?per_page=100"
  PDF_DIR="assets/${COURSE}/pdf"
  MANIFEST=".cache/${COURSE}_upstream_pdfs"
  mkdir -p "$PDF_DIR" .cache
}

# ---------------------------------------------------------------------------
# build_curl_auth – populate CURL_AUTH array with auth header (if token set)
# ---------------------------------------------------------------------------
build_curl_auth() {
  CURL_AUTH=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    CURL_AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
}

# ---------------------------------------------------------------------------
# fetch_release_assets – call the GitHub Releases API and store in API_RESPONSE
# ---------------------------------------------------------------------------
fetch_release_assets() {
  echo "🔍 Checking upstream releases for VL_${REPO_NAME}..."
  if ! API_RESPONSE=$(curl -fsSL --connect-timeout 15 "${CURL_AUTH[@]}" "$API_URL" 2>/dev/null); then
    echo "⚠️  Failed to reach the GitHub API for VL_${REPO_NAME}" >&2
    exit 1
  fi

  # Check for API error / rate-limit response
  if echo "$API_RESPONSE" | grep -q '"message"' && ! echo "$API_RESPONSE" | grep -q '"assets"'; then
    MSG=$(echo "$API_RESPONSE" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    echo "⚠️  GitHub API error: ${MSG:-unknown error}" >&2
    exit 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "⚠️  jq is not installed – cannot parse GitHub release assets" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# parse_pdf_assets – extract PDF names/URLs and deduplicate by filename
# Populates NAMES[] and URLS[] arrays (newest release wins per filename).
# ---------------------------------------------------------------------------
parse_pdf_assets() {
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
    local name="${ALL_NAMES[$i]}"
    if [ -z "${SEEN[$name]+x}" ]; then
      SEEN["$name"]=1
      NAMES+=("$name")
      URLS+=("${ALL_URLS[$i]}")
    fi
  done

  echo "📦 Found ${#NAMES[@]} unique upstream PDF(s) for ${COURSE}"
}

# ---------------------------------------------------------------------------
# load_manifest – read the cached URL manifest into CACHED_URL associative array
# ---------------------------------------------------------------------------
load_manifest() {
  if [ -f "$MANIFEST" ]; then
    while IFS=$'\t' read -r cached_name cached_url; do
      [[ -z "$cached_name" ]] && continue
      CACHED_URL["$cached_name"]="$cached_url"
    done < "$MANIFEST"
  fi
}

# ---------------------------------------------------------------------------
# sanitize_name – apply path-traversal sanitization to an asset filename.
# Prints the sanitized name and emits a warning when the name was changed.
# ---------------------------------------------------------------------------
sanitize_name() {
  local name="$1"
  local safe
  safe="$(basename -- "$name")"
  safe="${safe//../_}"
  if [ "$safe" != "$name" ]; then
    echo "  ⚠️  Unsafe asset name '${name}' sanitized to '${safe}'" >&2
  fi
  printf '%s' "$safe"
}

# ---------------------------------------------------------------------------
# download_pdfs – iterate NAMES/URLS, download new/updated PDFs, update manifest
# ---------------------------------------------------------------------------
download_pdfs() {
  local downloaded=0 updated=0 already_present=0
  > "${MANIFEST}.tmp"

  for i in "${!NAMES[@]}"; do
    local name="${NAMES[$i]}"
    local url="${URLS[$i]}"
    local safe_name target

    safe_name="$(sanitize_name "$name")"
    target="${PDF_DIR}/${safe_name}"

    # Use safe_name as the manifest key so the manifest reflects what is on disk.
    printf '%s\t%s\n' "${safe_name}" "${url}" >> "${MANIFEST}.tmp"

    if [ -f "$target" ] && [ "${CACHED_URL[$safe_name]+x}" ] && [ "${CACHED_URL[$safe_name]}" = "$url" ]; then
      # File exists and URL hasn't changed → already up-to-date
      already_present=$((already_present + 1))
    else
      local is_update=false
      if [ -f "$target" ]; then
        echo "  🔄 Updating ${name} (new release available)..."
        is_update=true
      else
        echo "  ⬇️  Downloading ${name}..."
      fi
      if curl -fsSL --connect-timeout 30 "${CURL_AUTH[@]}" -o "$target" "$url"; then
        # Increment only after a confirmed successful download
        if [ "$is_update" = true ]; then
          updated=$((updated + 1))
        else
          downloaded=$((downloaded + 1))
        fi
      else
        echo "  ⚠️  Failed to download ${name} from ${url}" >&2
        rm -f "$target"
        # Remove from manifest so the next run retries.
        # Split on the tab separator and compare the first field exactly so that
        # filenames that are substrings of each other don't cause false removals.
        awk -F'\t' -v prefix="${safe_name}" '$1 != prefix' "${MANIFEST}.tmp" > "${MANIFEST}.tmp2" && mv "${MANIFEST}.tmp2" "${MANIFEST}.tmp" || true
      fi
    fi
  done

  # Atomically replace manifest
  mv "${MANIFEST}.tmp" "$MANIFEST"

  echo "✅ Upstream PDFs: ${downloaded} new, ${updated} updated, ${already_present} already up-to-date"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  validate_args "$@"
  setup_paths
  build_curl_auth
  fetch_release_assets
  parse_pdf_assets
  load_manifest
  download_pdfs
}

main "$@"
