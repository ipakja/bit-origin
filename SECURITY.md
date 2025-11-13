# BIT Origin - Sicherheitsrichtlinien

## Wichtige Sicherheitshinweise

### Was auf GitHub gehört

- ✅ Code und Scripts
- ✅ Dokumentation
- ✅ Konfigurations-Templates (ohne Passwörter)
- ✅ Docker Compose Files (ohne Secrets)

### Was NIEMALS auf GitHub gehört

- ❌ Passwörter
- ❌ Private Keys
- ❌ VPN Configs
- ❌ Datenbank-Zugangsdaten
- ❌ SSL Certificates
- ❌ Benutzer-Zugangsdaten

## Secrets Management

### Lokale Secrets

Alle sensiblen Daten gehören in `/secrets/`:

- `.env` Dateien mit Passwörtern
- Private Keys
- VPN Configs
- Datenbank-Zugangsdaten

### Backup-Strategie

```bash
# Secrets verschlüsseln
tar -czf secrets.tar.gz secrets/
gpg -c secrets.tar.gz

# Backup auf USB oder sicherer Cloud
```

## .gitignore

Die `.gitignore` Datei schützt automatisch vor versehentlichem Committen von Secrets.

**Wichtig:** Prüfe vor jedem Commit, dass keine sensiblen Daten enthalten sind!

## Reporting Security Issues

Falls du Sicherheitslücken findest, bitte direkt per E-Mail melden:
- info@boksitsupport.ch

**Nicht** öffentlich im GitHub Issue-Tracker!

---

**BIT Origin - Security Policy**





