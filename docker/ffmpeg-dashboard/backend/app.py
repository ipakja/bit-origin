#!/usr/bin/env python3
"""
BIT Origin - FFmpeg Dashboard Backend
FastAPI Backend für Video/Audio-Verarbeitung mit FFmpeg
"""

import os
import subprocess
import shutil
import uuid
from pathlib import Path
from typing import Optional, List
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
import json

app = FastAPI(title="FFmpeg Dashboard API", version="1.0.0")

# CORS für Frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Verzeichnisse
BASE_DIR = Path("/app")
UPLOAD_DIR = BASE_DIR / "uploads"
OUTPUT_DIR = BASE_DIR / "output"
UPLOAD_DIR.mkdir(exist_ok=True)
OUTPUT_DIR.mkdir(exist_ok=True)

# FFmpeg prüfen
FFMPEG_CMD = shutil.which("ffmpeg") or "/usr/bin/ffmpeg"


class AudioTrack(BaseModel):
    """Audio-Track für Timeline"""
    file: str  # Dateiname im Upload-Verzeichnis
    start_time: float  # Start in Sekunden
    duration: Optional[float] = None  # Dauer (None = bis Ende)
    volume: float = 1.0  # Lautstärke-Multiplikator (1.0 = 100%)


class VideoCreateRequest(BaseModel):
    """Request für Video-Erstellung mit Musik"""
    duration: float  # Video-Dauer in Sekunden
    width: int = 1920
    height: int = 1080
    fps: int = 30
    background_color: str = "black"
    audio_tracks: List[AudioTrack] = []


@app.get("/")
def root():
    return {"status": "ok", "service": "FFmpeg Dashboard API"}


@app.get("/health")
def health():
    """Health Check"""
    return {"status": "healthy", "ffmpeg": os.path.exists(FFMPEG_CMD)}


@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    """Datei hochladen"""
    file_id = str(uuid.uuid4())
    file_ext = Path(file.filename).suffix
    file_path = UPLOAD_DIR / f"{file_id}{file_ext}"
    
    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)
    
    return {
        "file_id": file_id,
        "filename": file.filename,
        "path": str(file_path),
        "size": len(content)
    }


@app.post("/process/compress")
async def compress_video(
    file_id: str = Form(...),
    quality: int = Form(23)
):
    """Video komprimieren"""
    input_file = None
    for f in UPLOAD_DIR.glob(f"{file_id}.*"):
        input_file = f
        break
    
    if not input_file or not input_file.exists():
        raise HTTPException(404, "File not found")
    
    output_file = OUTPUT_DIR / f"{file_id}_compressed.mp4"
    
    cmd = [
        FFMPEG_CMD, "-y",
        "-i", str(input_file),
        "-c:v", "libx264",
        "-crf", str(quality),
        "-c:a", "copy",
        str(output_file)
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return {
            "status": "success",
            "output_file": str(output_file),
            "download_url": f"/download/{output_file.name}"
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(500, f"FFmpeg error: {e.stderr}")


@app.post("/process/resize")
async def resize_video(
    file_id: str = Form(...),
    width: int = Form(1920),
    height: int = Form(1080)
):
    """Video-Größe ändern"""
    input_file = None
    for f in UPLOAD_DIR.glob(f"{file_id}.*"):
        input_file = f
        break
    
    if not input_file or not input_file.exists():
        raise HTTPException(404, "File not found")
    
    output_file = OUTPUT_DIR / f"{file_id}_resized.mp4"
    
    cmd = [
        FFMPEG_CMD, "-y",
        "-i", str(input_file),
        "-vf", f"scale={width}:{height}",
        "-c:a", "copy",
        str(output_file)
    ]
    
    try:
        subprocess.run(cmd, capture_output=True, text=True, check=True)
        return {
            "status": "success",
            "output_file": str(output_file),
            "download_url": f"/download/{output_file.name}"
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(500, f"FFmpeg error: {e.stderr}")


@app.post("/process/cut")
async def cut_video(
    file_id: str = Form(...),
    start_time: str = Form(...),  # HH:MM:SS oder Sekunden
    duration: str = Form(...)  # HH:MM:SS oder Sekunden
):
    """Video schneiden"""
    input_file = None
    for f in UPLOAD_DIR.glob(f"{file_id}.*"):
        input_file = f
        break
    
    if not input_file or not input_file.exists():
        raise HTTPException(404, "File not found")
    
    output_file = OUTPUT_DIR / f"{file_id}_cut.mp4"
    
    cmd = [
        FFMPEG_CMD, "-y",
        "-i", str(input_file),
        "-ss", start_time,
        "-t", duration,
        "-c", "copy",
        str(output_file)
    ]
    
    try:
        subprocess.run(cmd, capture_output=True, text=True, check=True)
        return {
            "status": "success",
            "output_file": str(output_file),
            "download_url": f"/download/{output_file.name}"
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(500, f"FFmpeg error: {e.stderr}")


@app.post("/process/audio-volume")
async def adjust_audio_volume(
    file_id: str = Form(...),
    volume: float = Form(1.0)  # 1.0 = 100%, 0.5 = 50%, 2.0 = 200%
):
    """Lautstärke anpassen (Audio oder Video)"""
    input_file = None
    for f in UPLOAD_DIR.glob(f"{file_id}.*"):
        input_file = f
        break
    
    if not input_file or not input_file.exists():
        raise HTTPException(404, "File not found")
    
    output_file = OUTPUT_DIR / f"{file_id}_volume.mp4"
    
    # Volume-Filter: -filter:a "volume=1.5" bedeutet 150%
    cmd = [
        FFMPEG_CMD, "-y",
        "-i", str(input_file),
        "-filter:a", f"volume={volume}",
        "-c:v", "copy",
        str(output_file)
    ]
    
    try:
        subprocess.run(cmd, capture_output=True, text=True, check=True)
        return {
            "status": "success",
            "output_file": str(output_file),
            "download_url": f"/download/{output_file.name}"
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(500, f"FFmpeg error: {e.stderr}")


@app.post("/process/crop-image")
async def crop_image(
    file_id: str = Form(...),
    x: int = Form(0),
    y: int = Form(0),
    width: int = Form(1920),
    height: int = Form(1080)
):
    """Foto/Bild schneiden (crop)"""
    input_file = None
    for f in UPLOAD_DIR.glob(f"{file_id}.*"):
        input_file = f
        break
    
    if not input_file or not input_file.exists():
        raise HTTPException(404, "File not found")
    
    output_file = OUTPUT_DIR / f"{file_id}_cropped{input_file.suffix}"
    
    # Crop: -filter:v "crop=width:height:x:y"
    cmd = [
        FFMPEG_CMD, "-y",
        "-i", str(input_file),
        "-filter:v", f"crop={width}:{height}:{x}:{y}",
        str(output_file)
    ]
    
    try:
        subprocess.run(cmd, capture_output=True, text=True, check=True)
        return {
            "status": "success",
            "output_file": str(output_file),
            "download_url": f"/download/{output_file.name}"
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(500, f"FFmpeg error: {e.stderr}")


@app.post("/process/create-video")
async def create_video_with_music(data: VideoCreateRequest):
    """Video erstellen mit Musik-Timeline (Sekunden-basiert)"""
    output_file = OUTPUT_DIR / f"{uuid.uuid4()}_created.mp4"
    
    # Schritt 1: Basis-Video erstellen (farbiger Hintergrund)
    temp_video = OUTPUT_DIR / f"temp_{uuid.uuid4()}.mp4"
    
    # Farbiges Video generieren
    cmd_base = [
        FFMPEG_CMD, "-y",
        "-f", "lavfi",
        "-i", f"color=c={data.background_color}:s={data.width}x{data.height}:d={data.duration}:r={data.fps}",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        str(temp_video)
    ]
    
    try:
        subprocess.run(cmd_base, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as e:
        raise HTTPException(500, f"Base video creation failed: {e.stderr}")
    
    # Schritt 2: Audio-Tracks hinzufügen (Timeline-basiert)
    if data.audio_tracks:
        # Komplexer Filter für mehrere Audio-Tracks mit Timeline
        audio_inputs = []
        audio_filters = []
        
        for i, track in enumerate(data.audio_tracks):
            # Datei kann als UUID oder vollständiger Pfad übergeben werden
            track_file = UPLOAD_DIR / track.file
            if not track_file.exists():
                # Versuche mit verschiedenen Endungen
                found = False
                for ext in ['.mp3', '.wav', '.aac', '.m4a', '.ogg', '.flac']:
                    test_file = UPLOAD_DIR / f"{track.file}{ext}"
                    if test_file.exists():
                        track_file = test_file
                        found = True
                        break
                if not found:
                    continue
            
            # Audio-Input hinzufügen
            audio_inputs.extend(["-i", str(track_file)])
            
            # Volume-Filter für diesen Track
            volume_filter = f"volume={track.volume}"
            
            # Delay-Filter (Start-Zeit)
            delay_filter = f"adelay={int(track.start_time * 1000)}|{int(track.start_time * 1000)}"
            
            # Duration-Filter (falls angegeben)
            if track.duration:
                atrim_filter = f"atrim=0:{track.duration}"
                audio_filters.append(f"[{len(audio_inputs)//2}:a]{volume_filter},{delay_filter},{atrim_filter}[a{i}]")
            else:
                audio_filters.append(f"[{len(audio_inputs)//2}:a]{volume_filter},{delay_filter}[a{i}]")
        
        # Alle Audio-Tracks mischen
        mix_inputs = "".join([f"[a{i}]" for i in range(len(audio_filters))])
        mix_filter = f"{mix_inputs}amix=inputs={len(audio_filters)}:duration=longest:dropout_transition=3[audio]"
        
        # Kompletter Filter-String
        filter_complex = ";".join(audio_filters) + ";" + mix_filter
        
        # Finales Video mit Audio
        cmd_final = [
            FFMPEG_CMD, "-y",
            "-i", str(temp_video)
        ] + audio_inputs + [
            "-filter_complex", filter_complex,
            "-map", "0:v",
            "-map", "[audio]",
            "-c:v", "copy",
            "-c:a", "aac",
            "-b:a", "192k",
            "-shortest",
            str(output_file)
        ]
        
        try:
            subprocess.run(cmd_final, capture_output=True, text=True, check=True)
        except subprocess.CalledProcessError as e:
            # Cleanup
            temp_video.unlink(missing_ok=True)
            raise HTTPException(500, f"Audio mixing failed: {e.stderr}")
        
        # Temp-Video löschen
        temp_video.unlink(missing_ok=True)
    else:
        # Keine Audio-Tracks → nur Video kopieren
        temp_video.rename(output_file)
    
    return {
        "status": "success",
        "output_file": str(output_file),
        "download_url": f"/download/{output_file.name}"
    }


@app.get("/download/{filename}")
def download_file(filename: str):
    """Output-Datei herunterladen"""
    file_path = OUTPUT_DIR / filename
    if not file_path.exists():
        raise HTTPException(404, "File not found")
    return FileResponse(file_path, media_type="application/octet-stream")


@app.get("/files")
def list_files():
    """Uploaded Files auflisten"""
    files = []
    for f in UPLOAD_DIR.glob("*"):
        if f.is_file():
            files.append({
                "filename": f.name,
                "size": f.stat().st_size,
                "path": str(f)
            })
    return {"files": files}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
