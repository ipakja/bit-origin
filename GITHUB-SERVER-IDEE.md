# Server auf GitHub schalten - Idee & Zusammenfassung

## KONZEPT

Den kompletten Server-Setup und alle Konfigurationen als Infrastructure-as-Code (IaC) auf GitHub verwalten. Das bedeutet: Alle Scripts, Docker-Compose-Dateien, Konfigurationen und Dokumentation werden in einem Git-Repository gespeichert und versioniert.

## WARUM DAS SINNVOLL IST

### Vorteile

1. **Versionierung** - Alle Änderungen werden nachvollziehbar gespeichert
2. **Backup** - Code ist in der Cloud gesichert (GitHub)
3. **Kollaboration** - Team kann gemeinsam am Server arbeiten
4. **Reproduzierbarkeit** - Server kann jederzeit neu aufgesetzt werden
5. **Dokumentation** - Alles ist zentral dokumentiert
6. **Automatisierung** - GitHub Actions für Tests und Deployment
7. **Transparenz** - Klare Struktur, nachvollziehbare Änderungen

### Was bereits auf GitHub ist

- Alle Setup-Scripts
- Docker Compose Konfigurationen
- Dokumentation
- Projekt-Struktur

### Was NICHT auf GitHub gehört

- Secrets (Passwörter, API-Keys) - bereits in `.gitignore`
- Kundendaten - bleiben auf dem Server
- Datenbank-Inhalte - bleiben auf dem Server
- Upload-Dateien - bleiben auf dem Server

## AKTUELLER STAND

### Bereits implementiert

- Repository existiert: github.com/ipakja/bit-origin
- Code ist auf GitHub
- `.gitignore` schützt Secrets
- Struktur ist klar dokumentiert

### Workflow

1. **Lokale Entwicklung** - Änderungen auf Windows PC
2. **Commit & Push** - Änderungen auf GitHub
3. **Pull auf Server** - Server holt sich Updates von GitHub

## VOLLSTÄNDIGE IMPLEMENTIERUNG

### Schritt 1: Server als Git-Repository

```bash
# Auf dem Server
cd /opt/bit-origin
git init
git remote add origin https://github.com/ipakja/bit-origin.git
git pull origin main
```

### Schritt 2: Automatische Updates

```bash
# Cronjob für automatischen Pull (z.B. täglich)
0 2 * * * cd /opt/bit-origin && git pull origin main >> /var/log/git-pull.log 2>&1
```

### Schritt 3: Deployment-Automatisierung

```bash
# Script nach git pull ausführen
cd /opt/bit-origin
git pull
./scripts/deploy-updates.sh  # Docker Container neu starten, etc.
```

## STRUKTUR AUF GITHUB

```
bit-origin/
├── scripts/              # Alle Setup- und Betriebs-Scripts
├── docker/               # Docker Compose Konfigurationen
├── docs/                 # Dokumentation
├── config/               # Konfigurations-Templates
├── .github/              # GitHub Actions (CI/CD)
│   └── workflows/
│       ├── deploy.yml    # Automatisches Deployment
│       └── test.yml      # Tests vor Deployment
├── .gitignore            # Secrets werden nicht committed
└── README.md             # Projekt-Übersicht
```

## GITHUB ACTIONS - AUTOMATISIERUNG

### Automatisches Deployment

Wenn Code auf GitHub gepusht wird, kann automatisch:
1. Tests ausgeführt werden
2. Server benachrichtigt werden
3. Updates auf Server deployt werden

### Beispiel: GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy to Server
on:
  push:
    branches: [ main ]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Server
        run: |
          ssh user@192.168.42.133 "cd /opt/bit-origin && git pull && docker compose up -d"
```

## VORTEILE FÜR DEN SERVER

### 1. Zentrale Verwaltung

- Alle Änderungen werden auf GitHub getrackt
- Keine lokalen Änderungen, die verloren gehen
- Klare Historie aller Anpassungen

### 2. Einfache Wartung

- Updates einfach per `git pull`
- Rollback möglich durch `git checkout`
- Vergleich von Versionen möglich

### 3. Skalierung

- Server kann jederzeit neu aufgesetzt werden
- Identische Konfiguration auf mehreren Servern
- Backup durch GitHub garantiert

### 4. Teamarbeit

- Mehrere Personen können am Server arbeiten
- Code-Reviews möglich
- Klare Verantwortlichkeiten

## SICHERHEIT

### Was geschützt ist

- `.gitignore` verhindert Commit von Secrets
- Secrets bleiben auf Server in `/opt/bit-origin/secrets/`
- Kundendaten bleiben auf Server
- Keine Passwörter im Code

### Best Practices

1. **Nie Secrets committen** - Bereits in `.gitignore`
2. **Private Repository** - Optional für zusätzliche Sicherheit
3. **Branch-Protection** - Nur main-Branch für Production
4. **Access-Control** - Nur berechtigte Personen haben Zugriff

## MIGRATION - SCHRITT FÜR SCHRITT

### Phase 1: Repository synchronisieren

```bash
# Auf Server: Code mit GitHub synchronisieren
cd /opt/bit-origin
git remote add origin https://github.com/ipakja/bit-origin.git
git pull origin main
```

### Phase 2: Automatische Updates

```bash
# Cronjob für tägliche Updates
crontab -e
# Einfügen:
0 2 * * * cd /opt/bit-origin && git pull origin main >> /var/log/git-pull.log 2>&1
```

### Phase 3: Deployment-Automatisierung

```bash
# Script nach git pull
cat > /opt/bit-origin/scripts/deploy-updates.sh << 'EOF'
#!/bin/bash
cd /opt/bit-origin
git pull origin main

# Docker Container neu starten falls Änderungen
cd docker/ffmpeg-dashboard
docker compose up -d --build

cd ../uptime-kuma
docker compose up -d

cd ../zammad
docker compose up -d
EOF

chmod +x /opt/bit-origin/scripts/deploy-updates.sh
```

## ZUSAMMENFASSUNG

### Was bedeutet "Server auf GitHub schalten"?

- Alle Server-Konfigurationen werden als Code auf GitHub gespeichert
- Server holt sich Updates automatisch von GitHub
- Änderungen werden versioniert und nachvollziehbar

### Vorteile

- Zentrale Verwaltung
- Automatische Backups
- Einfache Wartung
- Reproduzierbarkeit
- Team-Kollaboration

### Aktueller Status

- Repository existiert bereits
- Code ist auf GitHub
- Secrets sind geschützt
- Server kann Updates von GitHub holen

### Nächste Schritte

1. Server mit GitHub synchronisieren (git pull)
2. Automatische Updates einrichten (Cronjob)
3. Deployment-Automatisierung (Scripts)
4. GitHub Actions für CI/CD (optional)

## FAZIT

Den Server auf GitHub zu schalten bedeutet, dass der komplette Server-Setup als Code verwaltet wird. Das ermöglicht einfache Wartung, automatische Updates und sichere Backups. Der Server bleibt funktional, wird aber durch GitHub zentral verwaltet und dokumentiert.

---

**Status:** Idee dokumentiert  
**Nächster Schritt:** Server mit GitHub synchronisieren


