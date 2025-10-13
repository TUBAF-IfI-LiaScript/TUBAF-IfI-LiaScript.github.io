# TUBAF-IfI-LiaScript.github.io

Course-Overview der Arbeitsgruppe Softwareentwicklung und Robotik (TU Freiberg)

## Asset-Generierung und Deployment

Die Kurs-Assets werden lokal generiert und intelligent deployed. Der Ablauf nutzt ein optimiertes Makefile für die lokale Entwicklung und eine schlanke GitHub Action als Fallback.

```mermaid
sequenceDiagram
    participant Dev as Entwickler
    participant Make as Makefile
    participant Git as Git Repository  
    participant Action as GitHub Action
    participant Pages as GitHub Pages

    Note over Dev,Pages: Lokaler Entwicklungsworkflow (Standard)
    
    Dev->>Make: make digitalesysteme
    Make->>Make: liaex -i digitalesysteme.yml
    Note right of Make: Generiert HTML + PDFs
    Make->>Make: mkdir -p assets/digitalesysteme/pdf
    Make->>Make: cp *.pdf assets/digitalesysteme/pdf/
    Note right of Make: Organisiert Assets in Kursordner
    Make->>Make: sed -i 's|assets/pdf/|assets/digitalesysteme/pdf/|g'
    Note right of Make: Korrigiert PDF-Pfade in HTML
    Make->>Git: git add . && git commit --amend
    Make->>Git: git push --force
    Note right of Make: Automatischer Git-Workflow
    
    Git->>Action: Push Trigger
    Action->>Action: git diff --name-only HEAD~1 HEAD
    Note right of Action: Erkennt geänderte YAML-Dateien
    
    alt YAML geändert oder HTML fehlt
        Action->>Action: liaex -i [changed].yml
        Note right of Action: Regeneriert nur bei Bedarf
        Action->>Pages: Deploy Assets
    else Keine Änderungen nötig
        Action->>Pages: Deploy existierende Assets
        Note right of Action: Überspringt Generierung
    end
    
    Note over Dev,Pages: Fallback-Szenario (wenn lokal nicht generiert)
    
    Dev->>Git: git push (nur YAML-Änderung)
    Git->>Action: Push Trigger
    Action->>Action: Erkennt fehlendes HTML
    Action->>Action: npm install -g @liascript/exporter
    Action->>Action: liaex -i digitalesysteme.yml (mit PDF-Generation)
    Action->>Pages: Deploy neu generierte Assets
    
    Note over Dev,Pages: Vorteile des Hybrid-Ansatzes
    Note right of Dev: ⚡ Schnelle lokale Entwicklung
    Note right of Make: 🎯 Automatisierte Asset-Organisation  
    Note right of Action: 🧠 Intelligente Erkennung
    Note right of Pages: 🔄 Zuverlässiges Fallback
```

## Verfügbare Make-Targets

```bash
# Einzelne Kurse generieren
make digitalesysteme    # Digitale Systeme / Eingebettete Systeme
make prozprog          # Prozedurale Programmierung
make softwareentwicklung  # Softwareentwicklung
make robotikprojekt    # Robotikprojekt
make index            # Übersichtsseite

# Alle Kurse
make all

# Hilfe anzeigen
make help
```

## Konfiguration

Das Makefile ist zentral konfiguriert:

```makefile
# Kurse mit PDF-Generierung
PDF_COURSES = digitalesysteme prozprog softwareentwicklung robotikprojekt

# SCORM-Parameter
SCORM_ORG = "TU-Bergakademie Freiberg"
SCORM_SCORE = 80
```

## Ordnerstruktur

```
├── digitalesysteme.yml     # Kurskonfiguration
├── digitalesysteme.html    # Generierte Webseite
├── assets/
│   └── digitalesysteme/
│       └── pdf/           # Kurs-spezifische PDFs
│           ├── 070f8b44f.pdf
│           └── ...
├── Makefile               # Build-System
└── .github/workflows/
    └── generateOERoverview.yml  # Intelligente GitHub Action
```

## Entwicklungsworkflow

1. **Lokal entwickeln**: `make digitalesysteme`
   - Generiert HTML und PDFs
   - Organisiert Assets automatisch
   - Korrigiert Pfade in HTML-Dateien

2. **Automatischer Git-Workflow**:
   - `git add .` und `git commit --amend` 
   - `git push --force` für saubere History

3. **Intelligentes Deployment**:
   - GitHub Action erkennt Änderungen
   - Regeneriert nur bei Bedarf
   - Fungiert als zuverlässiges Fallback
