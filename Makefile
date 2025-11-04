# Course configuration
COURSES = index digitalesysteme prozprog robotikprojekt softwareentwicklung
PDF_COURSES = digitalesysteme prozprog robotikprojekt softwareentwicklung
SCORM_ORG = "TU-Bergakademie Freiberg"
SCORM_SCORE = 80

.DEFAULT_GOAL := all
all: $(COURSES) git-update-if-needed

# Generic function to build a course
define build_course
$(1): $(1).yml $(wildcard assets/$(1)/pdf/*.pdf)
	@echo "=== Checking changes for $(1) ==="
	@if ./check_changes.sh $(1); then \
		$(MAKE) force-build-$(1); \
	else \
		echo "📄 Using existing $(1).html and assets"; \
	fi

force-build-$(1): clean-$(1) build-$(1) organize-$(1) update-cache-$(1) mark-changed

clean-$(1):
	@echo "🧹 Cleaning old files for $(1)..."
	rm -f $(1).html $(1).zip
	rm -rf assets/$(1)/ || true
	$(if $(filter $(1),$(PDF_COURSES)),rm -rf assets/pdf/* || true)



build-$(1):
	$(if $(filter $(1),$(PDF_COURSES)), \
		liaex --input $(1).yml --output $(1) --format project --project-generate-pdf --scorm-organization $(SCORM_ORG) --scorm-embed --scorm-masteryScore $(SCORM_SCORE), \
		liaex --input $(1).yml --output $(1) --format project)

organize-$(1):
	$(if $(filter $(1),$(PDF_COURSES)), \
		mkdir -p assets/$(1)/pdf && \
		cp assets/pdf/*.pdf assets/$(1)/pdf/ 2>/dev/null || true && \
		sed -i 's|assets/pdf/|assets/$(1)/pdf/|g' $(1).html)
endef

# Generate targets for all courses
$(foreach course,$(COURSES),$(eval $(call build_course,$(course))))

mark-changed:
	@touch .cache/build_occurred

update-cache-%:
	@YAML_HASH=$$(sha256sum $*.yml 2>/dev/null | cut -d' ' -f1 || echo "missing"); \
	case "$*" in \
		"digitalesysteme") REPO_NAME="EingebetteteSysteme" ;; \
		"prozprog") REPO_NAME="ProzeduraleProgrammierung" ;; \
		"softwareentwicklung") REPO_NAME="Softwareentwicklung" ;; \
		"robotikprojekt") REPO_NAME="Robotikprojekt" ;; \
		"index") REPO_NAME="" ;; \
		*) REPO_NAME="" ;; \
	esac; \
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
		git add assets/ || true; \
		git add -A; \
		git commit --amend --no-edit; \
		git push origin main -f; \
		rm -f .cache/build_occurred; \
	else \
		echo "✅ No courses rebuilt - git repository unchanged"; \
	fi

git-update:
	@echo "🔍 Checking for changes..."
	@echo "📝 Adding modified tracked files..."
	git add -u
	@echo "🔍 Looking for new PDFs..."
	@if [ -n "$$(find assets/*/pdf -name "*.pdf" -type f 2>/dev/null)" ]; then \
		echo "📎 Adding new PDF files..."; \
		git add -f assets/*/pdf/*.pdf; \
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
		repo_name=$$(echo $$course | sed 's/digitalesysteme/EingebetteteSysteme/;s/prozprog/ProzeduraleProgrammierung/;s/softwareentwicklung/Softwareentwicklung/;s/robotikprojekt/Robotikprojekt/;s/index/INDEX_SKIP/'); \
		if [ "$$repo_name" != "INDEX_SKIP" ]; then \
			echo "  🌐 Monitoring: VL_$$repo_name"; \
		else \
			echo "  🌐 No remote monitoring (index)"; \
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

.PHONY: all clean-all clean-cache force-all status git-update help $(COURSES)
