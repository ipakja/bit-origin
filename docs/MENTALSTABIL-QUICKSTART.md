# Mentalstabil - Quickstart Guide

## Was ist installiert:

1. **E-Mail:** mentalstabil@boksitsupport.ch
2. **Nextcloud:** Eigene Cloud-Instanz
3. **KI-Video-Dashboard:** ComfyUI (http://192.168.42.133:8188)
4. **FFmpeg:** Video/Audio Processing
5. **AI-Tools:** Integration für Cursor AI Pro & ChatGPT Pro

---

## Zugänge

### Nextcloud
- URL: http://192.168.42.133:8082 (oder nächster Port)
- Login: `mentalstabil` / Passwort: (siehe Setup)

### KI-Video-Dashboard (ComfyUI)
- URL: http://192.168.42.133:8188
- Erster Start: 5-10 Minuten (Modelle werden heruntergeladen)
- CPU-Version: langsamer, aber funktioniert
- GPU-Version: viel schneller (falls GPU vorhanden)

### E-Mail
- IMAP: imap.boksitsupport.ch
- SMTP: smtp.boksitsupport.ch
- Login: mentalstabil@boksitsupport.ch

---

## FFmpeg Commands

### Video komprimieren
```bash
ffmpeg -i input.mp4 -c:v libx264 -preset slow -crf 22 -c:a copy output.mp4
```

### Video skalieren
```bash
ffmpeg -i input.mp4 -vf scale=1920:1080 output.mp4
```

### Video schneiden
```bash
ffmpeg -i input.mp4 -ss 00:01:00 -t 00:02:00 -c copy output.mp4
```

### Video-Processing Script
```bash
/opt/mentalstabil/video-process.sh input.mp4 output.mp4
```

---

## KI-Video-Generierung

### ComfyUI Dashboard
1. Browser öffnen: http://192.168.42.133:8188
2. Workflow erstellen oder Template verwenden
3. Video generieren

### API-Integration (für Cursor AI Pro / ChatGPT Pro)
```bash
# ComfyUI API Endpoint
curl -X POST http://192.168.42.133:8188/api/v1/queue
```

---

## Cursor AI Pro Integration

Cursor AI Pro läuft client-seitig. Du kannst:
1. Repository klonen: `git clone https://github.com/ipakja/bit-origin.git`
2. In Cursor öffnen
3. API-Keys für KI-Services konfigurieren

---

## ChatGPT Pro Integration

### Option 1: API verwenden
- OpenAI API Key in Scripts konfigurieren
- API-Calls für Text-Generierung

### Option 2: Web-Interface
- ChatGPT Pro direkt nutzen (client-seitig)

---

## Tools-Verzeichnis

Alle Scripts sind unter `/opt/mentalstabil/`:
- `video-process.sh` - FFmpeg Wrapper
- `ai-tools.sh` - AI-Tools Übersicht

---

## Support

Bei Fragen oder Problemen:
- Logs: `docker logs comfyui`
- FFmpeg: `ffmpeg -version`
- Status: `docker ps | grep comfyui`

