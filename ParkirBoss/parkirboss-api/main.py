from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from core.database import engine, Base, SessionLocal
from core.seed import seed_data
from api import auth, vehicles, wallet, parking, notifications, gps

# The gate/ANPR and bridge routers pull heavy vision deps (ultralytics/easyocr/opencv).
# Make them optional so the rest of the API still runs in a lightweight setup.
try:
    from api import gate, bridge
    _GATE_AVAILABLE = True
except Exception as e:  # noqa: BLE001
    gate = None
    bridge = None
    _GATE_AVAILABLE = False
    print(f"[WARN] Gate/ANPR/Bridge routers disabled (vision deps not installed): {e}")

# Create database tables
Base.metadata.create_all(bind=engine)

# Seed initial data
with SessionLocal() as db:
    seed_data(db)

app = FastAPI(title="Parkir Boss API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(vehicles.router)
app.include_router(wallet.router)
app.include_router(gps.router)
if _GATE_AVAILABLE:
    app.include_router(gate.router)
    app.include_router(bridge.router)
app.include_router(parking.router)
app.include_router(notifications.router)

@app.get("/")
def root():
    return {
        "message": "Welcome to Parkir Boss API",
        "version": "2.0.0",
        "status": "running",
        "endpoints": {
            "auth": "/api/auth/register, /api/auth/login",
            "vehicles": "/api/vehicles",
            "wallet": "/api/wallet/balance, /api/wallet/topup",
            "gps": "/api/gps/heartbeat",
            "gate": "/api/gate/entry, /api/gate/exit",
            "bridge": "/api/device/event",
            "parking": "/api/parking/active, /api/parking/history, /api/parking/locations",
            "notifications": "/api/notifications",
        }
    }
