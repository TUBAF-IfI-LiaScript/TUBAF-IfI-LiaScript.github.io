all: index digitalesysteme prozprog robotikprojekt softwareentwicklung

clean-assets-index:
	rm -f index.html index.zip
	rm -rf assets/index/ || true

clean-assets-digitalesysteme:
	rm -f digitalesysteme.html digitalesysteme.zip
	rm -rf assets/digitalesysteme/ || true
	rm -rf assets/pdf/* || true

clean-assets-prozprog:
	rm -f prozprog.html prozprog.zip
	rm -rf assets/prozprog/ || true
	rm -rf assets/pdf/* || true

clean-assets-robotikprojekt:
	rm -f robotikprojekt.html robotikprojekt.zip
	rm -rf assets/robotikprojekt/ || true
	rm -rf assets/pdf/* || true

clean-assets-softwareentwicklung:
	rm -f softwareentwicklung.html softwareentwicklung.zip
	rm -rf assets/softwareentwicklung/ || true
	rm -rf assets/pdf/* || true

git-update:
	git add assets/ || true
	git add -A
	git commit --amend --no-edit
	git push origin main -f

index: clean-assets-index index-build organize-assets-index git-update

index-build:
	liaex --input index.yml --output index --format project

organize-assets-index:
	mkdir -p assets/index/pdf || true
	find assets/pdf -name "*.pdf" -newer index.yml -exec cp {} assets/index/pdf/ \; 2>/dev/null || true

digitalesysteme: clean-assets-digitalesysteme digitalesysteme-build organize-assets-digitalesysteme git-update

digitalesysteme-build:
	liaex --input digitalesysteme.yml --output digitalesysteme --format project --project-generate-pdf --scorm-organization "TU-Bergakademie Freiberg" --scorm-embed --scorm-masteryScore 80

organize-assets-digitalesysteme:
	mkdir -p assets/digitalesysteme/pdf || true
	cp assets/pdf/*.pdf assets/digitalesysteme/pdf/ 2>/dev/null || true
	sed -i 's|assets/pdf/|assets/digitalesysteme/pdf/|g' digitalesysteme.html

prozprog: clean-assets-prozprog prozprog-build organize-assets-prozprog git-update

prozprog-build:
	liaex --input prozprog.yml --output prozprog --format project --project-generate-pdf --scorm-organization "TU-Bergakademie Freiberg" --scorm-embed --scorm-masteryScore 80

organize-assets-prozprog:
	mkdir -p assets/prozprog/pdf || true
	cp assets/pdf/*.pdf assets/prozprog/pdf/ 2>/dev/null || true
	sed -i 's|assets/pdf/|assets/prozprog/pdf/|g' prozprog.html

robotikprojekt: clean-assets-robotikprojekt robotikprojekt-build organize-assets-robotikprojekt git-update

robotikprojekt-build:
	liaex --input robotikprojekt.yml --output robotikprojekt --format project --project-generate-pdf --scorm-organization "TU-Bergakademie Freiberg" --scorm-embed --scorm-masteryScore 80

organize-assets-robotikprojekt:
	mkdir -p assets/robotikprojekt/pdf || true
	cp assets/pdf/*.pdf assets/robotikprojekt/pdf/ 2>/dev/null || true
	sed -i 's|assets/pdf/|assets/robotikprojekt/pdf/|g' robotikprojekt.html

softwareentwicklung: clean-assets-softwareentwicklung softwareentwicklung-build organize-assets-softwareentwicklung git-update

softwareentwicklung-build:
	liaex --input softwareentwicklung.yml --output softwareentwicklung --format project --project-generate-pdf --scorm-organization "TU-Bergakademie Freiberg" --scorm-embed --scorm-masteryScore 80

organize-assets-softwareentwicklung:
	mkdir -p assets/softwareentwicklung/pdf || true
	cp assets/pdf/*.pdf assets/softwareentwicklung/pdf/ 2>/dev/null || true
	sed -i 's|assets/pdf/|assets/softwareentwicklung/pdf/|g' softwareentwicklung.html
