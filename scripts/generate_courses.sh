#!/bin/bash
# Generate course websites for all courses listed in the first argument.
# Usage: ./scripts/generate_courses.sh "<space-separated course names>"

set -euo pipefail

IFS=' ' read -ra course_list <<< "$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Generating Courses ==="

for course in "${course_list[@]}"; do
  yaml_file="${course}.yml"
  html_file="${course}.html"

  if [ ! -f "$yaml_file" ]; then
    echo "⚠️  YAML file $yaml_file not found"
    continue
  fi

  echo "Generating $html_file from $yaml_file..."

  # Determine whether PDF generation is needed for this course
  needs_pdfs=false
  manifest=".cache/${course}_upstream_pdfs"

  if [ "$course" != "index" ]; then
    # Try to download upstream PDFs (creates/updates the manifest)
    if bash "$SCRIPT_DIR/download_upstream_pdfs.sh" "$course"; then
      # Count lessons and compare with upstream PDF coverage
      lesson_count=$(grep -c '^[[:space:]]*- url:' "$yaml_file" 2>/dev/null || true)
      if [ -f "$manifest" ]; then
        upstream_count=$(wc -l < "$manifest" | tr -d ' ')
      else
        upstream_count=0
      fi

      if [ "$upstream_count" -ge "$lesson_count" ] && [ "$lesson_count" -gt 0 ]; then
        echo "✅ All ${upstream_count} upstream PDFs available for ${course} – skipping PDF generation"
        needs_pdfs=false
      else
        echo "📄 ${upstream_count}/${lesson_count} upstream PDFs for ${course} – will generate remaining"
        needs_pdfs=true
      fi
    else
      # No upstream PDFs available or mapping not found
      pdf_dir="assets/${course}/pdf"
      if [ ! -d "$pdf_dir" ] || [ -z "$(ls -A "$pdf_dir" 2>/dev/null)" ]; then
        echo "📄 No upstream PDFs and no local PDFs for ${course} – will generate"
        needs_pdfs=true
      else
        echo "✅ No upstream PDFs but local PDFs exist for ${course} – skipping generation"
        needs_pdfs=false
      fi
    fi
  fi

  case "$course" in
    "index")
      liaex -i "$yaml_file" -o "$course" --format project --project-category-blur
      ;;
    *)
      # If the course has an upstream repo mapping it is a full SCORM/PDF course
      _repo=$(grep -v '^\s*#' "$SCRIPT_DIR/courses.conf" | grep "^${course}:" | cut -d: -f2 | tr -d '[:space:]' || true)
      if [ -n "$_repo" ]; then
        if [ "$needs_pdfs" = true ]; then
          echo "🔨 Generating course with PDFs..."
          liaex -i "$yaml_file" -o "$course" --format project \
            --project-generate-cache \
            --project-generate-pdf \
            --project-generate-scorm2004 \
            --scorm-organization "TU-Bergakademie Freiberg" \
            --scorm-embed \
            --scorm-masteryScore 80 \
            --project-category-blur
        else
          echo "🔨 Generating course without PDFs..."
          liaex -i "$yaml_file" -o "$course" --format project \
            --project-generate-cache \
            --project-generate-scorm2004 \
            --scorm-organization "TU-Bergakademie Freiberg" \
            --scorm-embed \
            --scorm-masteryScore 80 \
            --project-category-blur
        fi
      else
        liaex -i "$yaml_file" -o "$course" --format project --project-category-blur
      fi
      ;;
  esac

  if [ -f "$html_file" ]; then
    echo "✅ Successfully generated $html_file"
  else
    echo "❌ Failed to generate $html_file"
  fi
done
