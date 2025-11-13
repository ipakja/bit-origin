# Kunden erstellen - Anleitung

## Einfacher Workflow

Ein Befehl erstellt alles:

```bash
sudo /opt/bit-origin/scripts/create-customer.sh <name> <password>
```

**Beispiel:**
```bash
sudo /opt/bit-origin/scripts/create-customer.sh anna Anna!2025
```

## Was wird erstellt?

1. **Linux-Systemuser**
   - Benutzername: `<name>`
   - Passwort: `<password>`
   - Home-Verzeichnis: `/home/<name>`

2. **Nextcloud-Instanz**
   - Container: `nc-<name>`
   - Port: Automatisch nächster freier Port (8081-8100)
   - Admin: `<name>` / `<password>`
   - URL: `http://192.168.42.133:<PORT>`

3. **VPN-Client-Config** (falls WireGuard Server läuft)
   - Datei: `/etc/wireguard/clients/<name>.conf`
   - IP: Automatisch nächste freie IP (10.20.0.10-200)
   - QR-Code: `/opt/bit-origin/users/<name>/<name>-vpn-qr.png`

4. **Uptime-Kuma Monitor** (falls API Key konfiguriert)
   - Name: `Nextcloud-<name>`
   - URL: `http://192.168.42.133:<PORT>`
   - Interval: 60 Sekunden

5. **Kunden-Daten**
   - Übersicht: `/opt/bit-origin/users/SUMMARY.md`
   - Verzeichnis: `/opt/bit-origin/users/<name>/`

## Übersicht aller Kunden

```bash
cat /opt/bit-origin/users/SUMMARY.md
```

## Kunden-Daten abrufen

### VPN Config
```bash
cat /etc/wireguard/clients/<name>.conf
```

### QR-Code
```bash
ls -la /opt/bit-origin/users/<name>/
```

### Nextcloud Zugang
```bash
# Port aus SUMMARY.md:
http://192.168.42.133:<PORT>
# Login: <name> / <password>
```

## Troubleshooting

### Port bereits belegt
Das Script findet automatisch den nächsten freien Port. Falls alle Ports belegt sind, wird ein Fehler ausgegeben.

### VPN-Config nicht erstellt
- Prüfe ob WireGuard Server läuft: `systemctl status wg-quick@wg0`
- Prüfe ob Server-Publickey existiert: `ls -la /etc/wireguard/publickey`

### QR-Code fehlt
- Prüfe ob `qrencode` installiert ist: `which qrencode`
- Installieren: `apt install -y qrencode`

### Uptime-Kuma Monitor nicht hinzugefügt
- Prüfe ob API Key existiert: `cat /opt/bit-origin/secrets/uptime.env`
- Prüfe ob Uptime-Kuma läuft: `docker ps | grep uptime-kuma`
- API Key neu generieren in Uptime-Kuma UI

---

**BIT Origin - Kunden erstellen**





