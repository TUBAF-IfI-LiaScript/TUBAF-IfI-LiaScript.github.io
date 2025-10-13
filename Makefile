# Course configuration
COURSES = index digitalesysteme prozprog robotikprojekt softwareentwicklung
PDF_COURSES = digitalesysteme prozprog robotikprojekt softwareentwicklung
SCORM_ORG = "TU-Bergakademie Freiberg"
SCORM_SCORE = 80

.DEFAULT_GOAL := all
all: $(COURSES)

# Generic function to build a course
define build_course
$(1): clean-$(1) build-$(1) organize-$(1) git-update

clean-$(1):
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

git-update:
	git add assets/ || true
	git add -A
	git commit --amend --no-edit
	git push origin main -f

# Utility targets
clean-all:
	rm -f *.html *.zip
	rm -rf assets/*/

help:
	@echo "Available targets:"
	@echo "  all                 - Build all courses"
	@echo "  clean-all          - Clean all generated files"
	@echo "  git-update         - Update git repository"
	@echo ""
	@echo "Individual courses:"
	@$(foreach course,$(COURSES),echo "  $(course)";)
	@echo ""
	@echo "Course configuration:"
	@echo "  PDF courses: $(PDF_COURSES)"
	@echo "  SCORM org:   $(SCORM_ORG)"
	@echo "  SCORM score: $(SCORM_SCORE)"

.PHONY: all clean-all git-update help $(COURSES)
