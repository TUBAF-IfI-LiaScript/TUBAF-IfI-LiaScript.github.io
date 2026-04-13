#!/bin/bash
# Generate course websites for all courses listed in the first argument.
# Usage: ./scripts/generate_courses.sh "<space-separated course names>"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=courses_lib.sh
. "${SCRIPT_DIR}/courses_lib.sh"

# ---------------------------------------------------------------------------
# determine_pdf_needs – decide if PDF generation is required for a course.
# Sets the caller-visible variable `needs_pdfs` to "true" or "false".
# Must be called from a context where `needs_pdfs` is already declared.
# ---------------------------------------------------------------------------
determine_pdf_needs() {
  local course="$1"
  local yaml_file="${course}.yml"
  local manifest=".cache/${course}_upstream_pdfs"

  # Try to download upstream PDFs (creates/updates the manifest)
  if bash "$SCRIPT_DIR/download_upstream_pdfs.sh" "$course"; then
    # Count lessons and compare with upstream PDF coverage
    local lesson_count upstream_count
    lesson_count=$(grep -c '^[[:space:]]*- url:' "$yaml_file" 2>/dev/null) || lesson_count=0
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
    local pdf_dir="assets/${course}/pdf"
    if [ ! -d "$pdf_dir" ] || [ -z "$(ls -A "$pdf_dir" 2>/dev/null)" ]; then
      echo "📄 No upstream PDFs and no local PDFs for ${course} – will generate"
      needs_pdfs=true
    else
      echo "✅ No upstream PDFs but local PDFs exist for ${course} – skipping generation"
      needs_pdfs=false
    fi
  fi
}

# ---------------------------------------------------------------------------
# run_liaex – run the liaex command for a given course.
# $1: course name  $2: "true" if PDF generation is needed, "false" otherwise
# ---------------------------------------------------------------------------
run_liaex() {
  local course="$1"
  local needs_pdfs="$2"
  local yaml_file="${course}.yml"

  case "$course" in
    "index")
      liaex -i "$yaml_file" -o "$course" --format project --project-category-blur
      ;;
    *)
      # If the course has an upstream repo mapping it is a full SCORM/PDF course
      local _repo
      _repo=$(lookup_repo "$course")
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
}

# ---------------------------------------------------------------------------
# generate_course – orchestrate PDF-need check and liaex call for one course.
# ---------------------------------------------------------------------------
generate_course() {
  local course="$1"
  local yaml_file="${course}.yml"
  local html_file="${course}.html"

  if [ ! -f "$yaml_file" ]; then
    echo "⚠️  YAML file $yaml_file not found"
    return
  fi

  echo "Generating $html_file from $yaml_file..."

  # Initialize needs_pdfs; determine_pdf_needs() will update it if applicable.
  # Not declared local so that determine_pdf_needs can write to the same variable.
  needs_pdfs=false
  if [ "$course" != "index" ]; then
    determine_pdf_needs "$course"
  fi

  run_liaex "$course" "$needs_pdfs"

  if [ -f "$html_file" ]; then
    echo "✅ Successfully generated $html_file"
  else
    echo "❌ Failed to generate $html_file"
  fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  IFS=' ' read -ra course_list <<< "$1"
  echo "=== Generating Courses ==="
  for course in "${course_list[@]}"; do
    generate_course "$course"
  done
}

main "$@"
