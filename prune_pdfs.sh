#!/usr/bin/env bash
set -euo pipefail

# Remove PDFs in assets/**/pdf that are not referenced by any generated HTML
# Usage: ./prune_pdfs.sh [--dry-run]

DRY_RUN=false
if [[ ${1-} == "--dry-run" ]]; then
  DRY_RUN=true
fi

repo_root="$(cd "$(dirname "$0")" && pwd)"
cd "$repo_root"

# Collect referenced PDFs from all HTML files
mapfile -t html_files < <(ls *.html 2>/dev/null || true)
if [[ ${#html_files[@]} -eq 0 ]]; then
  echo "No HTML files found; nothing to prune."
  exit 0
fi

echo "Scanning HTML files for PDF references..."
referenced=$(grep -hoE 'assets/[A-Za-z0-9_-]+/pdf/[A-Za-z0-9._-]+\.pdf|assets/pdf/[A-Za-z0-9._-]+\.pdf' -- *.html 2>/dev/null | sort -u || true)

# Normalize to absolute paths
declare -A keep
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  abs="$repo_root/$rel"
  keep["$abs"]=1
done < <(printf "%s\n" "$referenced")

# Find all PDFs under assets/**/pdf
mapfile -t all_pdfs < <(find assets -type f -name '*.pdf')

# Determine unreferenced PDFs
unreferenced=()
for f in "${all_pdfs[@]}"; do
  if [[ -z ${keep["$repo_root/${f#${repo_root}/}"]+x} && -z ${keep["$f"]+x} ]]; then
    unreferenced+=("$f")
  fi
done

count_total=${#all_pdfs[@]}
count_keep=${#keep[@]}
count_delete=${#unreferenced[@]}

echo "Total PDFs: $count_total"
echo "Referenced PDFs: $count_keep"
if [[ $count_delete -eq 0 ]]; then
  echo "No unreferenced PDFs to delete."
  exit 0
fi

echo "Unreferenced PDFs to delete ($count_delete):"
printf " - %s\n" "${unreferenced[@]}"

if $DRY_RUN; then
  echo "Dry run: not deleting files."
  exit 0
fi

echo "Deleting unreferenced PDFs..."
for f in "${unreferenced[@]}"; do
  rm -f -- "$f"
done

echo "Done."
