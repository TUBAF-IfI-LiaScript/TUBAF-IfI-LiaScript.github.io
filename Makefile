# Course configuration
COURSES = index digitalesysteme prozprog robotikprojekt softwareentwicklung
PDF_COURSES = digitalesysteme prozprog robotikprojekt softwareentwicklung
SCORM_ORG = "TU-Bergakademie Freiberg"
SCORM_SCORE = 80

.DEFAULT_GOAL := all
all: $(COURSES) prune-pdfs git-update-if-needed

# Generic function to build a course
define build_course
$(1): $(1).yml
	@echo "=== Checking changes for $(1) ==="
	@if ./scripts/check_changes.sh $(1); then \
		$(MAKE) force-build-$(1); \
	else \
		echo "📄 Using existing $(1).html and assets"; \
	fi

force-build-$(1): clean-$(1) download-pdfs-$(1) build-$(1) organize-$(1) update-cache-$(1) mark-changed

clean-$(1):
	@echo "🧹 Cleaning old files for $(1)..."
	rm -f $(1).html $(1).zip
	rm -rf assets/$(1)/ || true



build-$(1):
	$(if $(filter $(1),$(PDF_COURSES)), \
		if [ -f ".cache/$(1)_skip_pdf_gen" ]; then \
			echo "🔨 Building $(1) (all PDFs from upstream)..."; \
			liaex --input $(1).yml --output $(1) --format project --scorm-organization $(SCORM_ORG) --scorm-embed --scorm-masteryScore $(SCORM_SCORE) --project-category-blur; \
		else \
			echo "🔨 Building $(1) with PDF generation..."; \
			liaex --input $(1).yml --output $(1) --format project --project-generate-pdf --scorm-organization $(SCORM_ORG) --scorm-embed --scorm-masteryScore $(SCORM_SCORE) --project-category-blur; \
		fi, \
		liaex --input $(1).yml --output $(1) --format project --project-category-blur)

organize-$(1):
	$(if $(filter $(1),$(PDF_COURSES)), \
		echo "🔗 Using shared assets/pdf for $(1); skipping duplication" )
endef

# Generate targets for all courses
$(foreach course,$(COURSES),$(eval $(call build_course,$(course))))

# Download upstream release PDFs for a single course.
# Creates .cache/<course>_skip_pdf_gen when all lessons are covered by upstream PDFs.
download-pdfs-%:
	@if [ -n "$(filter $*,$(PDF_COURSES))" ]; then \
		mkdir -p .cache; \
		[ -x scripts/download_upstream_pdfs.sh ] || chmod +x scripts/download_upstream_pdfs.sh; \
		LESSON_COUNT=$$(grep -c '^[[:space:]]*- url:' "$*.yml" 2>/dev/null) || LESSON_COUNT=0; \
		if bash scripts/download_upstream_pdfs.sh "$*"; then \
			if [ -f ".cache/$*_upstream_pdfs" ]; then \
				UPSTREAM_COUNT=$$(wc -l < ".cache/$*_upstream_pdfs" | tr -d ' '); \
			else \
				UPSTREAM_COUNT=0; \
			fi; \
			if [ "$$UPSTREAM_COUNT" -ge "$$LESSON_COUNT" ] && [ "$$LESSON_COUNT" -gt 0 ]; then \
				touch ".cache/$*_skip_pdf_gen"; \
				echo "✅ All $$UPSTREAM_COUNT upstream PDFs present for $* – PDF generation will be skipped"; \
			else \
				rm -f ".cache/$*_skip_pdf_gen"; \
				echo "📄 $$UPSTREAM_COUNT/$$LESSON_COUNT upstream PDFs for $* – PDF generation needed"; \
			fi; \
		else \
			rm -f ".cache/$*_skip_pdf_gen"; \
			echo "📄 No upstream PDFs for $* – PDF generation needed"; \
		fi; \
	fi

# Download upstream PDFs for all PDF courses (useful for local mode: make download-pdfs)
download-pdfs: $(foreach course,$(PDF_COURSES),download-pdfs-$(course))

mark-changed:
	@touch .cache/build_occurred

update-cache-%:
	@YAML_HASH=$$(sha256sum $*.yml 2>/dev/null | cut -d' ' -f1 || echo "missing"); \
	REPO_NAME=$$(grep -v '^\s*#' scripts/courses.conf | grep '^$*:' | cut -d: -f2 | tr -d '[:space:]' || true); \
	if [ -n "$$REPO_NAME" ]; then \
		API_URL="https://api.github.com/repos/TUBAF-IfI-LiaScript/VL_$${REPO_NAME}/commits/master"; \
		API_RESPONSE=$$(curl -sL --connect-timeout 10 "$$API_URL" 2>/dev/null); \
		if command -v jq >/dev/null 2>&1; then \
			REMOTE_HASH=$$(echo "$$API_RESPONSE" | jq -r '.sha' 2>/dev/null || echo "unreachable"); \
		else \
			REMOTE_HASH=$$(echo "$$API_RESPONSE" | sed -n 's/.*"sha":"\([^"]*\)".*/\1/p' | head -1); \
			if [ -z "$$REMOTE_HASH" ]; then REMOTE_HASH="unreachable"; fi; \
		fi; \
		if [ "$$REMOTE_HASH" = "unreachable" ] || [ -z "$$REMOTE_HASH" ]; then \
			REMOTE_HASH="unreachable"; \
		fi; \
	else \
		REMOTE_HASH="no-remote"; \
	fi; \
	mkdir -p .cache; \
	echo "$$YAML_HASH" > ".cache/$*"; \
	echo "$$REMOTE_HASH" >> ".cache/$*"; \
	echo "📝 Cache updated for $*"

git-update-if-needed:
	@if [ -f .cache/build_occurred ]; then \
		echo "🔄 Changes detected - updating git repository..."; \
		echo "📝 Staging modified tracked files..."; \
		git add -u; \
		echo "📦 Staging asset changes (including new files)..."; \
		git add -A assets/ || true; \
		echo "📄 Staging HTML files..."; \
		git add *.html || true; \
		if git diff --cached --quiet; then \
			echo "🟡 No staged changes; skipping commit"; \
		else \
			echo "📝 Amending last commit and pushing..."; \
			git commit --amend --no-edit; \
			git push origin main -f; \
		fi; \
		rm -f .cache/build_occurred; \
	else \
		echo "✅ No courses rebuilt - checking for new PDFs..."; \
		NEW_PDFS=$$(git ls-files --others --exclude-standard assets/pdf/*.pdf 2>/dev/null); \
		if [ -n "$$NEW_PDFS" ]; then \
			echo "📎 Found new PDFs: $$NEW_PDFS"; \
			git add assets/pdf/*.pdf; \
			git commit -m "Add new PDF files"; \
			git push origin main; \
		else \
			echo "✅ No new PDFs found"; \
		fi; \
	fi

git-update:
	@echo "🔍 Checking for changes..."
	@echo "📝 Adding modified tracked files..."
	git add -u
	@echo "🔍 Looking for new PDFs..."
	@if [ -n "$$(git ls-files --others --exclude-standard assets/pdf/*.pdf 2>/dev/null)" ]; then \
		echo "📎 Adding new PDF files from assets/pdf/..."; \
		git add assets/pdf/*.pdf; \
	fi
	@echo "📄 Adding HTML files..."
	git add *.html
	@echo "📝 Committing changes..."
	git commit --amend --no-edit
	@echo "🚀 Pushing to remote..."
	git push origin main -f

# Utility targets
clean-all:
	rm -f *.html *.zip
	rm -rf assets/*/
	rm -rf .cache/

clean-cache:
	rm -rf .cache/
	@echo "All cache files cleared - next build will regenerate everything"

force-all: clean-cache
	$(MAKE) all

status:
	@echo "=== Build Status ==="
	@for course in $(COURSES); do \
		echo ""; \
		echo "📚 Course: $$course"; \
		if [ -f "$$course.html" ]; then \
			echo "  ✅ HTML file exists"; \
		else \
			echo "  ❌ HTML file missing"; \
		fi; \
		if [ -f ".cache/$$course" ]; then \
			echo "  📋 Cache file exists"; \
			cached_yaml=$$(sed -n '1p' ".cache/$$course" 2>/dev/null || echo "missing"); \
			cached_remote=$$(sed -n '2p' ".cache/$$course" 2>/dev/null || echo "missing"); \
			echo "  💾 Cached YAML: $$(echo $$cached_yaml | cut -c1-8)..."; \
			echo "  💾 Cached remote: $$(echo $$cached_remote | cut -c1-8)..."; \
		else \
			echo "  ⚪ No cache file"; \
		fi; \
		if [ -d "assets/$$course" ]; then \
			pdf_count=$$(find "assets/$$course" -name "*.pdf" 2>/dev/null | wc -l); \
			echo "  📁 Assets: $$pdf_count PDFs"; \
		else \
			echo "  📁 No assets"; \
		fi; \
		repo_name=$$(grep -v '^\s*#' scripts/courses.conf | grep "^$$course:" | cut -d: -f2 | tr -d '[:space:]' || true); \
		if [ -n "$$repo_name" ]; then \
			echo "  🌐 Monitoring: VL_$$repo_name"; \
		else \
			echo "  🌐 No remote monitoring"; \
		fi; \
	done

help:
	@echo "Available targets:"
	@echo "  all                 - Build all courses (with change detection)"
	@echo "  force-all           - Force rebuild all courses (clears cache)"  
	@echo "  clean-all          - Clean all generated files and cache"
	@echo "  clean-cache        - Clear only cache files"
	@echo "  status             - Show build status of all courses"
	@echo "  git-update         - Update git repository"
	@echo "  prune-pdfs         - Remove PDFs not referenced by any HTML"
	@echo "  download-pdfs      - Download upstream release PDFs for all PDF courses"
	@echo ""
	@echo "Individual courses (with change detection):"
	@$(foreach course,$(COURSES),echo "  $(course)";)
	@echo ""
	@echo "Force rebuild individual courses:"
	@$(foreach course,$(COURSES),echo "  force-build-$(course)";)
	@echo ""
	@echo "Course configuration:"
	@echo "  PDF courses: $(PDF_COURSES)"
	@echo "  SCORM org:   $(SCORM_ORG)"
	@echo "  SCORM score: $(SCORM_SCORE)"

.PHONY: all clean-all clean-cache force-all status git-update help prune-pdfs download-pdfs $(COURSES)

prune-pdfs:
	@echo "🗑️  Pruning unreferenced PDFs..."
	@if [ -x ./scripts/prune_pdfs.sh ]; then \
		./scripts/prune_pdfs.sh || true; \
	else \
		chmod +x scripts/prune_pdfs.sh && ./scripts/prune_pdfs.sh || true; \
	fi
