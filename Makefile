all: index digitalesysteme prozprog robotikprojekt softwareentwicklung

index:
	liaex --input index.yml --output index --format project

digitalesysteme:
	liaex --input digitalesysteme.yml --output digitalesysteme --format project --project-generate-pdf 

prozprog:
	liaex --input prozprog.yml --output prozprog --format project --project-generate-pdf 

robotikprojekt:
	liaex --input robotikprojekt.yml --output robotikprojekt --format project --project-generate-pdf
softwareentwicklung:
	liaex --input softwareentwicklung.yml --output softwareentwicklung --format project --project-generate-pdf
