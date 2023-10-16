all: index digitalesysteme prozprog robotikprojekt softwareentwicklung

index:
	liaex --input index.yml --output index --format project

digitalesysteme:
	liaex --input digitalesysteme.yml --output digitalesysteme --format project --project-generate-pdf --scorm-organization "TU-Bergakademie Freiberg" --scorm-embed --scorm-masteryScore 80

prozprog:
	liaex --input prozprog.yml --output prozprog --format project --project-generate-pdf --scorm-organization "TU-Bergakademie Freiberg" --scorm-embed --scorm-masteryScore 80

robotikprojekt:
	liaex --input robotikprojekt.yml --output robotikprojekt --format project --project-generate-pdf --scorm-organization "TU-Bergakademie Freiberg" --scorm-embed --scorm-masteryScore 80

softwareentwicklung:
	liaex --input softwareentwicklung.yml --output softwareentwicklung --format project --project-generate-pdf --scorm-organization "TU-Bergakademie Freiberg" --scorm-embed --scorm-masteryScore 80
