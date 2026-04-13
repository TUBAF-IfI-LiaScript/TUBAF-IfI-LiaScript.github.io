#!/usr/bin/env bash
set -euo pipefail

# Remove PDFs in assets/**/pdf that are not referenced by any generated HTML
# Usage: ./prune_pdfs.sh [--dry-run]

DRY_RUN=false
if [[ ${1-} == "--dry-run" ]]; then
  DRY_RUN=true
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

# Associative array of PDF absolute paths to keep
declare -A keep

# ---------------------------------------------------------------------------
# collect_html_refs – scan HTML files and add referenced PDFs to `keep`
# ---------------------------------------------------------------------------
collect_html_refs() {
  mapfile -t html_files < <(ls *.html 2>/dev/null || true)
  if [[ ${#html_files[@]} -eq 0 ]]; then
    echo "No HTML files found; nothing to prune."
    exit 0
  fi

  echo "Scanning HTML files for PDF references..."
  local referenced
  referenced=$(grep -hoE 'assets/[A-Za-z0-9_-]+/pdf/[A-Za-z0-9._-]+\.pdf|assets/pdf/[A-Za-z0-9._-]+\.pdf' -- *.html 2>/dev/null | sort -u || true)

  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    keep["$repo_root/$rel"]=1
  done < <(printf "%s\n" "$referenced")
}

# ---------------------------------------------------------------------------
# collect_manifest_refs – protect upstream PDFs listed in .cache/ manifests
# ---------------------------------------------------------------------------
collect_manifest_refs() {
  for manifest in .cache/*_upstream_pdfs; do
    [ -f "$manifest" ] || continue
    local course
    course="$(basename "$manifest" _upstream_pdfs)"
    while IFS=$'\t' read -r pdf_name _url; do
      [[ -z "$pdf_name" ]] && continue
      keep["$repo_root/assets/${course}/pdf/${pdf_name}"]=1
    done < "$manifest"
  done
}

# ---------------------------------------------------------------------------
# find_unreferenced – compare all on-disk PDFs against `keep`.
# Populates `unreferenced` array.
# ---------------------------------------------------------------------------
find_unreferenced() {
  mapfile -t all_pdfs < <(find assets -type f -name '*.pdf')

  unreferenced=()
  for f in "${all_pdfs[@]}"; do
    if [[ -z ${keep["$repo_root/${f#${repo_root}/}"]+x} && -z ${keep["$f"]+x} ]]; then
      unreferenced+=("$f")
    fi
  done

  local count_total=${#all_pdfs[@]}
  local count_keep=${#keep[@]}
  local count_delete=${#unreferenced[@]}

  echo "Total PDFs: $count_total"
  echo "Referenced PDFs: $count_keep"

  if [[ $count_delete -eq 0 ]]; then
    echo "No unreferenced PDFs to delete."
    exit 0
  fi

  echo "Unreferenced PDFs to delete ($count_delete):"
  printf " - %s\n" "${unreferenced[@]}"
}

# ---------------------------------------------------------------------------
# delete_unreferenced – remove unreferenced PDFs (respects --dry-run)
# ---------------------------------------------------------------------------
delete_unreferenced() {
  if $DRY_RUN; then
    echo "Dry run: not deleting files."
    exit 0
  fi

  echo "Deleting unreferenced PDFs..."
  for f in "${unreferenced[@]}"; do
    rm -f -- "$f"
  done
  echo "Done."
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  collect_html_refs
  collect_manifest_refs
  find_unreferenced
  delete_unreferenced
}

main
