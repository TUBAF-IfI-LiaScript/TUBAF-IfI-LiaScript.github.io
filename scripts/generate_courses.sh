#!/bin/bash
# Generate course websites for all courses listed in the first argument.
# Usage: ./scripts/generate_courses.sh "<space-separated course names>"

set -euo pipefail

IFS=' ' read -ra course_list <<< "$1"

echo "=== Generating Courses ==="

for course in "${course_list[@]}"; do
  yaml_file="${course}.yml"
  html_file="${course}.html"

  if [ ! -f "$yaml_file" ]; then
    echo "⚠️  YAML file $yaml_file not found"
    continue
  fi

  echo "Generating $html_file from $yaml_file..."

  # Check whether PDFs already exist for this course
  pdf_dir="assets/${course}/pdf"
  needs_pdfs=false

  if [ "$course" != "index" ]; then
    if [ ! -d "$pdf_dir" ] || [ -z "$(ls -A "$pdf_dir" 2>/dev/null)" ]; then
      needs_pdfs=true
      echo "📄 PDFs missing for $course - will generate"
    else
      echo "✅ PDFs already exist for $course - skipping generation"
    fi
  fi

  case "$course" in
    "index")
      liaex -i "$yaml_file" -o "$course" --format project --project-category-blur
      ;;
    "digitalesysteme"|"prozprog"|"softwareentwicklung"|"robotikprojekt")
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
      ;;
    *)
      liaex -i "$yaml_file" -o "$course" --format project --project-category-blur
      ;;
  esac

  if [ -f "$html_file" ]; then
    echo "✅ Successfully generated $html_file"
  else
    echo "❌ Failed to generate $html_file"
  fi
done
