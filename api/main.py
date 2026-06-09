"""
SmartPark API - Main Application

Run:
  uvicorn api.main:app --reload --port 8000

Docs:
  http://localhost:8000/docs  (Swagger UI)
  http://localhost:8000/redoc (ReDoc)

Simulation:
  http://localhost:8000/simulation  (RPi5 Camera Simulation)
"""

from pathlib import Path
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles

from api.config import API_TITLE, API_VERSION, API_DESCRIPTION, CAPTURE_DIR
from api.schemas import HealthResponse

# Import routers
from api.routers import anpr as anpr_router
from api.routers import ocr as ocr_router
from api.routers import pipeline as pipeline_router
from api.routers import color as color_router
from api.routers import device as device_router

# Import engines
from api.engine.anpr import ANPREngine
from api.engine.ocr import OCREngine
from api.engine.vehicle import VehicleClassifier

# Global engine instances
anpr_engine: ANPREngine | None = None
ocr_engine: OCREngine | None = None
vehicle_classifier: VehicleClassifier | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load models on startup, cleanup on shutdown."""
    global anpr_engine, ocr_engine, vehicle_classifier

    print("\n" + "=" * 50)
    print("SmartPark API - Loading models...")
    print("=" * 50)

    # Load ANPR engine
    anpr_engine = ANPREngine()
    anpr_router.set_engine(anpr_engine)

    # Load OCR engine
    ocr_engine = OCREngine()

    # Load vehicle classifier
    vehicle_classifier = VehicleClassifier()

    # Inject engines into routers
    ocr_router.set_engines(anpr_engine, ocr_engine)
    color_router.set_engines(anpr_engine, vehicle_classifier)
    pipeline_router.set_engines(anpr_engine, ocr_engine, vehicle_classifier)
    device_router.set_engines(anpr_engine, ocr_engine, vehicle_classifier)

    print("=" * 50)
    print("SmartPark API - Ready!")
    print("=" * 50 + "\n")

    yield

    # Cleanup
    print("SmartPark API - Shutting down...")


# === FastAPI App ===
app = FastAPI(
    title=API_TITLE,
    version=API_VERSION,
    description=API_DESCRIPTION,
    lifespan=lifespan,
)

# CORS (allow all for development)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(anpr_router.router)
app.include_router(ocr_router.router)
app.include_router(pipeline_router.router)
app.include_router(color_router.router)
app.include_router(device_router.router)

# Mount static files
_static_dir = Path(__file__).parent / "static"
_static_dir.mkdir(exist_ok=True)
app.mount("/static", StaticFiles(directory=str(_static_dir)), name="static")

# Serve the web simulation pages (iot-dashboard.html, integrasi.html) directly
# from the project's simulasi/ folder so the camera works on http://localhost.
_simulasi_dir = Path(__file__).resolve().parent.parent / "simulasi"
if _simulasi_dir.is_dir():
    app.mount("/simulasi", StaticFiles(directory=str(_simulasi_dir), html=True), name="simulasi")

# Serve captured frames so the IoT dashboard can show event thumbnails (/captures/<file>).
app.mount("/captures", StaticFiles(directory=str(CAPTURE_DIR)), name="captures")


# === Root & Health ===

@app.get("/", tags=["System"])
async def root():
    return {
        "name": API_TITLE,
        "version": API_VERSION,
        "docs": "/docs",
        "simulation": "/simulation",
        "esp32_simulator": "/esp32-simulator",
        "endpoints": {
            "anpr": "/anpr/detect",
            "ocr_full": "/ocr/read",
            "ocr_cropped": "/ocr/read-cropped",
            "color": "/color/detect",
            "pipeline": "/pipeline/verify",
            "device_trigger": "/device/trigger",
            "device_upload": "/device/process-image",
        },
    }


@app.get("/simulation", response_class=HTMLResponse, tags=["System"])
async def simulation_page():
    """Serve the RPi5 simulation web interface."""
    html_path = Path(__file__).parent / "static" / "simulation.html"
    return HTMLResponse(content=html_path.read_text(encoding="utf-8"), status_code=200)


@app.get("/esp32-simulator", response_class=HTMLResponse, tags=["System"])
async def esp32_simulator_page():
    """Serve the ESP32-CAM hardware simulator web interface."""
    html_path = Path(__file__).parent / "static" / "esp32_simulator.html"
    return HTMLResponse(content=html_path.read_text(encoding="utf-8"), status_code=200)


@app.get("/health", response_model=HealthResponse, tags=["System"])
async def health_check():
    return HealthResponse(
        status="ok",
        anpr_model_loaded=anpr_engine.is_loaded if anpr_engine else False,
        ocr_engine_loaded=ocr_engine.is_loaded if ocr_engine else False,
        version=API_VERSION,
    )
