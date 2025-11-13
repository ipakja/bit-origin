# Cursor Repo Analysis Prompt

**Einfügen in Cursor als Instruction-Block oder direkt als Prompt verwenden**

---

Du arbeitest in einem bestehenden GitHub-Repository namens `bit-origin`.

**Ziel:** Das Projekt soll auf einem Debian-12-Server mit Docker Compose v2 stabil und reproduzierbar laufen.

## Deine Aufgaben

### 1. Projektstruktur analysieren

Analysiere die gesamte Projektstruktur (`scripts`, `lib`, `docker`, `backup`, `docs`, `.github/workflows`), damit du das System als Ganzes verstehst.

### 2. Fehler identifizieren

Identifiziere alle offensichtlichen Fehler, Inkonsistenzen und Broken Paths in:
- Shell-Skripten
- Docker Compose Files
- GitHub Actions Workflows

### 3. Shell-Skripte überprüfen

Überprüfe alle Shell-Skripte im Ordner `scripts/`, `lib/` und `bit-lab/` logisch auf:

- Tippfehler in Befehlen
- fehlende `set -euo pipefail` / Fehlerbehandlung
- falsche oder relative Pfade
- veraltete oder nicht vorhandene Binärpfade
- nicht gesetzte Variablen, die später verwendet werden

### 4. Debian-12-Kompatibilität sicherstellen

Sorge dafür, dass alle Skripte auf einer frischen Debian-12-Installation mit installiertem Docker und Docker Compose v2 lauffähig sind, ohne manuelle Nachbesserungen.

### 5. Docker-Konfigurationen prüfen

Prüfe die Docker-Konfigurationen im Ordner `docker/` auf:

- korrekte Image-Tags
- konsistente Port-Mappings
- sinnvolle Volumes für Persistenz
- Kompatibilität mit aktueller `docker compose` Syntax

### 6. GitHub Actions Workflows validieren

Öffne `.github/workflows` und stelle sicher, dass alle Workflows:

- auf dem Branch `main` laufen
- mit `ubuntu-latest` funktionieren
- keine Secrets erwarten, die im Repository nicht dokumentiert sind
- im Fehlerfall sinnvolle Logs ausgeben

### 7. Dokumentation aktualisieren

Dokumentiere alle zwingenden Voraussetzungen in der README:

- Debian-Version
- benötigte Pakete
- Docker-Version
- RAM/CPU-Anforderungen

Die Dokumentation soll so vollständig sein, dass ein fremder Senior Admin das System ohne Rückfragen installieren kann.

### 8. Änderungsrichtlinien

Wenn du Skripte oder Workflows anpassen musst, achte darauf:

- Verhalten nicht unnötig zu verändern
- Änderungen einheitlich zu kommentieren
- Sicherheitsaspekte zu berücksichtigen:
  - keine Klartext-Passwörter
  - kein Speichern von Secrets in Git

### 9. Abschlussübersicht

Am Ende sollst du eine kurze Übersicht schreiben:

- welche Dateien geändert wurden
- welche Klassen von Fehlern behoben wurden
- welche Tests man ausführen soll, um die Funktionalität zu verifizieren (`docker compose`, zentrale Setup-Skripte, etc.)

---

## Arbeitsweise

Handle wie ein erfahrener Senior DevOps / SRE mit Fokus auf:
- **Stabilität** – reproduzierbare, fehlerfreie Ausführung
- **Sicherheit** – keine Hardcoded Secrets, sichere Defaults
- **Wartbarkeit** – klare Struktur, dokumentierte Abhängigkeiten

---

**Hinweis:** Dieser Prompt kann direkt in Cursor eingefügt werden, um eine vollständige Codebase-Analyse und -Reparatur durchzuführen.

