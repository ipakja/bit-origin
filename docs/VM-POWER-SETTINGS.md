# VM Power Settings - Bildschirm nie ausschalten

## Übersicht

Diese Anleitung beschreibt, wie du beide VMs (`bit-origin` und `bit-admin`) so konfigurierst, dass der Bildschirm nie ausgeht und die grafische Session aktiv bleibt.

**Wichtig:** Diese Einstellungen müssen **in jeder VM separat** vorgenommen werden.

---

## Variante A – über die Oberfläche (GNOME Desktop)

### Für jede VM (`bit-origin` und `bit-admin`):

1. **Activities / Aktivitäten** öffnen (oben links)
2. **Settings / Einstellungen** öffnen

#### Power / Energie-Einstellungen:

1. Links auf **"Power / Energie"** klicken
2. **"Blank screen / Bildschirm verdunkeln"** → auf **"Never / Nie"** stellen
3. **"Automatic suspend / Automatischer Ruhezustand"** → **AUS** stellen
   - Sowohl für **"On battery"** als auch **"Plugged in"**

#### Privacy / Datenschutz-Einstellungen:

1. Links auf **"Privacy / Datenschutz"** klicken
2. **"Screen Lock / Bildschirmsperre"** öffnen
3. **"Automatic Screen Lock"** → **AUS**
4. Falls vorhanden: **"Blank screen after"** → **"Never / Nie"**

---

## Variante B – Xfce Desktop (falls verwendet)

Falls du Xfce statt GNOME verwendest:

1. **Settings → Power Manager → Display**
2. Folgende Einstellungen auf **"Never"** setzen:
   - **Display sleep**
   - **Blank**
   - **DPMS**

---

## Variante C – Terminal (für beide Desktops)

Alternativ kannst du die Einstellungen auch über das Terminal setzen:

```bash
# Bildschirm nie ausschalten
gsettings set org.gnome.desktop.session idle-delay 0

# Automatischer Ruhezustand deaktivieren
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'

# Bildschirmsperre deaktivieren
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
```

---

## Verifikation

Nach den Einstellungen:

1. VM für einige Minuten laufen lassen
2. Prüfen, ob der Bildschirm aktiv bleibt
3. Prüfen, ob keine automatische Sperre auftritt

---

## Warum diese Einstellungen wichtig sind

- **Stabilität:** Verhindert unerwartete Unterbrechungen bei lang laufenden Prozessen
- **Monitoring:** Grafische Tools bleiben sichtbar
- **Remote-Zugriff:** VNC/RDP-Sessions bleiben aktiv
- **Docker-Services:** Laufen kontinuierlich ohne Unterbrechung

---

**Hinweis:** Diese Einstellungen sind für Server-VMs gedacht, die kontinuierlich laufen. Für Laptops oder Workstations sollten diese Einstellungen nicht verwendet werden, da sie den Energieverbrauch erhöhen.

