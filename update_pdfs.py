"""Einzelne PDFs einer Kursübersicht neu bauen, statt das ganze Projekt.

Die Übersichtsseiten (z. B. digitalesysteme.html) verlinken zu jeder
Vorlesung ein PDF unter assets/pdf/<hash>.pdf. Dieses Skript sucht für die
angegebenen Vorlesungsdateien die zugehörige Karte, erzeugt das PDF mit
liaex aus der lokalen Arbeitskopie neu und ersetzt die Datei unter
demselben Namen. Links und Seite bleiben unverändert.

Aufruf im Wurzelverzeichnis dieses Repositorys:

    # bestimmte Vorlesungen
    python3 update_pdfs.py digitalesysteme.html ../VL_EingebetteteSysteme 00_Einfuehrung.md 01_HistorischerUeberblick.md

    # alle Vorlesungen, die sich seit einem Commit des Kursrepos geändert haben
    python3 update_pdfs.py digitalesysteme.html ../VL_EingebetteteSysteme --since 4ed5144

Vorher die Vorlesungen pushen: Die Kurse importieren config.md und
Vorlagen von GitHub, das PDF zeigt also den Stand von master.
"""
import argparse, os, re, shutil, subprocess, sys, tempfile

ap = argparse.ArgumentParser()
ap.add_argument("seite", help="Übersichtsseite, z. B. digitalesysteme.html")
ap.add_argument("kursrepo", help="lokale Arbeitskopie des Kursrepos")
ap.add_argument("dateien", nargs="*", help="Vorlesungsdateien, z. B. 00_Einfuehrung.md")
ap.add_argument("--since", help="alle seit diesem Commit geänderten Vorlesungen")
ap.add_argument("--timeout", default="15000", help="--pdf-timeout für liaex (ms)")
args = ap.parse_args()

dateien = list(args.dateien)
if args.since:
    out = subprocess.run(["git", "-C", args.kursrepo, "diff", "--name-only", args.since, "HEAD",
                          "--", "[0-9][0-9]_*.md"], capture_output=True, text=True, check=True).stdout
    dateien += [d for d in out.split() if d not in dateien]
if not dateien:
    sys.exit("Keine Vorlesungsdateien angegeben oder geändert.")

seite = open(args.seite, encoding="utf-8").read()
# Karte: Link auf die Vorlesung, danach (vor der nächsten Karte) der PDF-Link
karten = re.findall(r'href="https://liascript\.github\.io/course/\?([^"]+)".*?href="(assets/pdf/[^"]+\.pdf)"',
                    seite, re.S)
pdf_von = {url.rsplit("/", 1)[-1]: pdf for url, pdf in karten}

fehler = []
for datei in dateien:
    pdf = pdf_von.get(datei)
    quelle = os.path.join(args.kursrepo, datei)
    if not pdf:
        fehler.append(f"{datei}: keine Karte in {args.seite}")
        continue
    if not os.path.exists(quelle):
        fehler.append(f"{datei}: nicht in {args.kursrepo}")
        continue
    with tempfile.TemporaryDirectory() as tmp:
        ziel = os.path.join(tmp, "vorlesung")
        print(f"{datei} → {pdf} ...", flush=True)
        r = subprocess.run(["liaex", "-i", os.path.abspath(quelle), "-f", "pdf", "-o", ziel,
                            "--pdf-timeout", args.timeout], capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(ziel + ".pdf"):
            fehler.append(f"{datei}: liaex fehlgeschlagen\n{r.stdout[-500:]}{r.stderr[-500:]}")
            continue
        shutil.move(ziel + ".pdf", pdf)
        print(f"  ok ({os.path.getsize(pdf) // 1024} KB)")

if fehler:
    sys.exit("\n".join(fehler))
