#!/usr/bin/env bash
# BIT Origin - FFmpeg Dashboard Setup
# Web-Interface für FFmpeg Video-Processing

set -euo pipefail

BASE="/opt/bit-origin"
PORT=8189

echo "=== FFMPEG DASHBOARD SETUP ==="
echo ""

# Prüfe ob als root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Bitte als root ausführen: sudo $0"
    exit 1
fi

# 1. FFmpeg installieren (falls nicht vorhanden)
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "1. FFmpeg installieren..."
    apt update
    apt install -y ffmpeg ffmpeg-doc
fi

# 2. Python installieren (falls nicht vorhanden)
if ! command -v python3 >/dev/null 2>&1; then
    echo "2. Python installieren..."
    apt install -y python3 python3-pip
fi

# 3. Dashboard-Verzeichnis erstellen
DASHBOARD_DIR="${BASE}/docker/ffmpeg-dashboard"
mkdir -p "${DASHBOARD_DIR}"

# 4. Docker Compose für FFmpeg Dashboard (Backend + Frontend)
# Docker Compose wird aus dem Repository verwendet
# Falls nicht vorhanden, wird es von GitHub geholt

# 5. Dashboard und Backend werden aus dem Repository kopiert
# Falls nicht vorhanden, wird es von GitHub geholt
mkdir -p "${DASHBOARD_DIR}/dashboard"
mkdir -p "${DASHBOARD_DIR}/backend"

# Falls die Dateien noch nicht existieren, erstelle sie manuell
# (Normalerweise werden sie von git pull geholt)
if [ ! -f "${DASHBOARD_DIR}/dashboard/index.html" ]; then
    echo "Hinweis: Dashboard-Dateien werden von GitHub geholt"
    echo "Bitte 'git pull' ausführen, um die neuesten Dateien zu erhalten"
fi

# Temporäres altes HTML (wird durch git pull überschrieben)
cat > "${DASHBOARD_DIR}/dashboard/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FFmpeg Dashboard - BIT Origin</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        h1 { font-size: 2.5em; margin-bottom: 10px; }
        .subtitle { opacity: 0.9; }
        .content { padding: 40px; }
        .section {
            margin-bottom: 40px;
            padding: 25px;
            background: #f8f9fa;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .section h2 {
            color: #333;
            margin-bottom: 20px;
            font-size: 1.5em;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            color: #555;
            font-weight: 600;
        }
        input[type="text"], input[type="file"], select {
            width: 100%;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 6px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input:focus, select:focus {
            outline: none;
            border-color: #667eea;
        }
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 14px 30px;
            border: none;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        .btn:active { transform: translateY(0); }
        .output {
            margin-top: 20px;
            padding: 15px;
            background: #1e1e1e;
            color: #00ff00;
            border-radius: 6px;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            max-height: 300px;
            overflow-y: auto;
        }
        .info-box {
            background: #e3f2fd;
            border-left: 4px solid #2196f3;
            padding: 15px;
            margin-top: 20px;
            border-radius: 4px;
        }
        .code {
            background: #f5f5f5;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: monospace;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🎬 FFmpeg Dashboard</h1>
            <p class="subtitle">Video & Audio Processing - BIT Origin</p>
        </header>
        <div class="content">
            <div class="section">
                <h2>Video Processing</h2>
                <form id="videoForm">
                    <div class="form-group">
                        <label>Operation:</label>
                        <select id="operation" required>
                            <option value="compress">Komprimieren</option>
                            <option value="resize">Größe ändern</option>
                            <option value="cut">Schneiden</option>
                            <option value="convert">Format konvertieren</option>
                            <option value="extract_audio">Audio extrahieren</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Input-Datei:</label>
                        <input type="file" id="inputFile" accept="video/*,audio/*" required>
                    </div>
                    <div class="form-group" id="paramsGroup"></div>
                    <button type="submit" class="btn">Process Video</button>
                </form>
                <div id="output" class="output" style="display:none;"></div>
            </div>

            <div class="section">
                <h2>FFmpeg Commands</h2>
                <div class="info-box">
                    <strong>Quick Commands:</strong><br><br>
                    <span class="code">ffmpeg -i input.mp4 -c:v libx264 -crf 23 output.mp4</span> - Komprimieren<br><br>
                    <span class="code">ffmpeg -i input.mp4 -vf scale=1920:1080 output.mp4</span> - Größe ändern<br><br>
                    <span class="code">ffmpeg -i input.mp4 -ss 00:01:00 -t 00:02:00 output.mp4</span> - Schneiden<br><br>
                    <span class="code">ffmpeg -i input.mp4 -vn -acodec copy output.aac</span> - Audio extrahieren
                </div>
            </div>
        </div>
    </div>

    <script>
        const form = document.getElementById('videoForm');
        const operation = document.getElementById('operation');
        const paramsGroup = document.getElementById('paramsGroup');
        const output = document.getElementById('output');

        operation.addEventListener('change', updateParams);
        updateParams();

        function updateParams() {
            const op = operation.value;
            let html = '';
            
            if (op === 'resize') {
                html = `
                    <label>Größe:</label>
                    <select id="size">
                        <option value="1920:1080">1920x1080 (Full HD)</option>
                        <option value="1280:720">1280x720 (HD)</option>
                        <option value="854:480">854x480 (SD)</option>
                        <option value="640:360">640x360 (niedrig)</option>
                    </select>
                `;
            } else if (op === 'cut') {
                html = `
                    <label>Start-Zeit (HH:MM:SS):</label>
                    <input type="text" id="startTime" placeholder="00:01:00">
                    <label style="margin-top:10px;">Dauer (HH:MM:SS):</label>
                    <input type="text" id="duration" placeholder="00:02:00">
                `;
            } else if (op === 'compress') {
                html = `
                    <label>Qualität (0-51, niedriger = besser):</label>
                    <input type="number" id="quality" value="23" min="0" max="51">
                `;
            } else if (op === 'convert') {
                html = `
                    <label>Ziel-Format:</label>
                    <select id="format">
                        <option value="mp4">MP4</option>
                        <option value="avi">AVI</option>
                        <option value="mov">MOV</option>
                        <option value="mkv">MKV</option>
                        <option value="webm">WebM</option>
                    </select>
                `;
            }
            
            paramsGroup.innerHTML = html;
        }

        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            output.style.display = 'block';
            output.textContent = 'Processing... Bitte warten...';
            
            // Für jetzt: Command anzeigen (später: API-Endpoint)
            const file = document.getElementById('inputFile').files[0];
            const op = operation.value;
            let cmd = '';
            
            if (op === 'compress') {
                const quality = document.getElementById('quality').value;
                cmd = `ffmpeg -i "${file.name}" -c:v libx264 -crf ${quality} -c:a copy output.mp4`;
            } else if (op === 'resize') {
                const size = document.getElementById('size').value;
                cmd = `ffmpeg -i "${file.name}" -vf scale=${size} output.mp4`;
            } else if (op === 'cut') {
                const start = document.getElementById('startTime').value || '00:00:00';
                const duration = document.getElementById('duration').value || '00:01:00';
                cmd = `ffmpeg -i "${file.name}" -ss ${start} -t ${duration} -c copy output.mp4`;
            } else if (op === 'convert') {
                const format = document.getElementById('format').value;
                cmd = `ffmpeg -i "${file.name}" -c copy output.${format}`;
            } else if (op === 'extract_audio') {
                cmd = `ffmpeg -i "${file.name}" -vn -acodec copy output.aac`;
            }
            
            output.textContent = `FFmpeg Command:\n${cmd}\n\n(API-Endpoint wird später implementiert)`;
        });
    </script>
</body>
</html>
HTML

# 6. Container starten
echo "3. Dashboard starten..."
cd "${DASHBOARD_DIR}"
docker compose up -d

echo ""
echo "=== FFMPEG DASHBOARD READY ==="
echo ""
echo "Dashboard: http://192.168.42.133:8189"
echo "API Backend: http://192.168.42.133:8000"
echo ""
echo "Features:"
echo "- Video erstellen mit Musik-Timeline (Sekunden-basiert)"
echo "- Lautstärke anpassen"
echo "- Fotos schneiden"
echo "- Video komprimieren, schneiden, konvertieren"
echo ""
echo "WICHTIG: Docker Compose neu starten nach git pull:"
echo "  cd ${DASHBOARD_DIR}"
echo "  docker compose down"
echo "  docker compose up -d --build"

