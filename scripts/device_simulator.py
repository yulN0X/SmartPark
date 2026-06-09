#!/usr/bin/env python3
"""
SmartPark — Device Simulator
=============================

Simulates ESP32 IoT devices for testing without physical hardware.
The laptop/Mac acts as the "Brain" (replacing Raspberry Pi), and this
script simulates sensor triggers, gate responses, and the full IoT flow.

Usage:
  # Interactive mode (menu)
  python scripts/device_simulator.py

  # Single trigger
  python scripts/device_simulator.py --once --gate GATE-A-IN --type entry

  # Auto-trigger every N seconds
  python scripts/device_simulator.py --auto --interval 10

  # Upload an image directly
  python scripts/device_simulator.py --image "foto test/plat_hitam.png"

  # Specify API URL
  python scripts/device_simulator.py --host 192.168.1.100 --port 8000
"""

import argparse
import json
import os
import random
import sys
import time
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Attempt to import requests; fall back to urllib if unavailable
# ---------------------------------------------------------------------------
try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    import urllib.request
    import urllib.error
    HAS_REQUESTS = False


# ═══════════════════════════════════════════════════════════════════════════
# ANSI COLOURS
# ═══════════════════════════════════════════════════════════════════════════

class C:
    """ANSI colour codes for terminal output."""
    RESET   = "\033[0m"
    BOLD    = "\033[1m"
    DIM     = "\033[2m"
    RED     = "\033[91m"
    GREEN   = "\033[92m"
    YELLOW  = "\033[93m"
    BLUE    = "\033[94m"
    MAGENTA = "\033[95m"
    CYAN    = "\033[96m"
    WHITE   = "\033[97m"
    BG_GREEN = "\033[42m"
    BG_RED   = "\033[41m"
    BG_YELLOW = "\033[43m"


# ═══════════════════════════════════════════════════════════════════════════
# ASCII ART
# ═══════════════════════════════════════════════════════════════════════════

BANNER = f"""
{C.CYAN}{C.BOLD}
  ╔═══════════════════════════════════════════════════════╗
  ║                                                       ║
  ║   ███████╗███╗   ███╗ █████╗ ██████╗ ████████╗       ║
  ║   ██╔════╝████╗ ████║██╔══██╗██╔══██╗╚══██╔══╝       ║
  ║   ███████╗██╔████╔██║███████║██████╔╝   ██║          ║
  ║   ╚════██║██║╚██╔╝██║██╔══██║██╔══██╗   ██║          ║
  ║   ███████║██║ ╚═╝ ██║██║  ██║██║  ██║   ██║          ║
  ║   ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝          ║
  ║                                                       ║
  ║   ██████╗  █████╗ ██████╗ ██╗  ██╗                   ║
  ║   ██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝                   ║
  ║   ██████╔╝███████║██████╔╝█████╔╝                    ║
  ║   ██╔═══╝ ██╔══██║██╔══██╗██╔═██╗                    ║
  ║   ██║     ██║  ██║██║  ██║██║  ██╗                   ║
  ║   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝                   ║
  ║                                                       ║
  ║          🚗  Device Simulator  🚗                    ║
  ║                                                       ║
  ╚═══════════════════════════════════════════════════════╝
{C.RESET}"""

GATE_CLOSED = f"""{C.RED}
    ╔══════╗          ╔══════╗
    ║      ║██████████║      ║
    ║      ║▓▓▓▓▓▓▓▓▓▓║      ║
    ║  ██  ║██████████║  ██  ║
    ║  ██  ║          ║  ██  ║
    ║  ██  ║ 🚫 TUTUP ║  ██  ║
    ╚══════╝          ╚══════╝
{C.RESET}"""

GATE_OPEN = f"""{C.GREEN}
    ╔══════╗          ╔══════╗
    ║      ╠═╗        ║      ║
    ║      ║ ║        ║      ║
    ║  ██  ║ ║        ║  ██  ║
    ║  ██  ║ ║        ║  ██  ║
    ║  ██  ║ ╚═══     ║  ██  ║
    ╚══════╝  ✅ BUKA ╚══════╝
{C.RESET}"""

GATE_PROCESSING = f"""{C.YELLOW}
    ╔══════╗          ╔══════╗
    ║      ║██████████║      ║
    ║      ║▓▓▓▓▓▓▓▓▓▓║      ║
    ║  ██  ║██████████║  ██  ║
    ║  ██  ║          ║  ██  ║
    ║  ██  ║ ⏳ PROSES║  ██  ║
    ╚══════╝          ╚══════╝
{C.RESET}"""


# ═══════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════

def timestamp() -> str:
    return datetime.now().strftime("%H:%M:%S")


def log(msg: str, level: str = "info"):
    icons = {
        "info":    f"{C.BLUE}ℹ{C.RESET}",
        "success": f"{C.GREEN}✅{C.RESET}",
        "error":   f"{C.RED}❌{C.RESET}",
        "warning": f"{C.YELLOW}⚠️{C.RESET}",
        "sensor":  f"{C.MAGENTA}📡{C.RESET}",
        "gate":    f"{C.CYAN}🚧{C.RESET}",
        "api":     f"{C.WHITE}🌐{C.RESET}",
    }
    icon = icons.get(level, icons["info"])
    print(f"  {C.DIM}[{timestamp()}]{C.RESET} {icon}  {msg}")


def divider(title: str = ""):
    if title:
        print(f"\n  {C.DIM}{'─' * 10}{C.RESET} {C.BOLD}{title}{C.RESET} {C.DIM}{'─' * 30}{C.RESET}")
    else:
        print(f"  {C.DIM}{'─' * 55}{C.RESET}")


# ═══════════════════════════════════════════════════════════════════════════
# API CLIENT
# ═══════════════════════════════════════════════════════════════════════════

class SmartParkAPI:
    """Thin wrapper around SmartPark API endpoints."""

    def __init__(self, host: str = "localhost", port: int = 8000):
        self.base_url = f"http://{host}:{port}"

    def health(self) -> dict | None:
        return self._get("/health")

    def device_status(self) -> dict | None:
        return self._get("/device/status")

    def trigger(self, gate_id: str, gate_type: str, distance_cm: float,
                device_id: str = "simulator") -> dict | None:
        payload = {
            "device_id": device_id,
            "gate_id": gate_id,
            "gate_type": gate_type,
            "sensor": "simulator",
            "distance_cm": distance_cm,
            "confidence": 0.25,
            "nearest_only": True,
        }
        return self._post("/device/trigger", payload)

    def process_image(self, image_path: str, gate_id: str = "GATE-A-IN",
                      gate_type: str = "entry") -> dict | None:
        if HAS_REQUESTS:
            try:
                with open(image_path, "rb") as f:
                    files = {"file": (os.path.basename(image_path), f, "image/jpeg")}
                    data = {
                        "device_id": "simulator-upload",
                        "gate_id": gate_id,
                        "gate_type": gate_type,
                    }
                    resp = requests.post(
                        f"{self.base_url}/device/process-image",
                        files=files, data=data, timeout=30,
                    )
                    resp.raise_for_status()
                    return resp.json()
            except Exception as e:
                log(f"Upload error: {e}", "error")
                return None
        else:
            log("Image upload requires 'requests' library. Install: pip install requests", "error")
            return None

    # ── internal ──

    def _get(self, path: str) -> dict | None:
        url = f"{self.base_url}{path}"
        try:
            if HAS_REQUESTS:
                resp = requests.get(url, timeout=10)
                resp.raise_for_status()
                return resp.json()
            else:
                req = urllib.request.Request(url)
                with urllib.request.urlopen(req, timeout=10) as resp:
                    return json.loads(resp.read().decode())
        except Exception as e:
            log(f"GET {path} failed: {e}", "error")
            return None

    def _post(self, path: str, payload: dict) -> dict | None:
        url = f"{self.base_url}{path}"
        try:
            if HAS_REQUESTS:
                resp = requests.post(url, json=payload, timeout=30)
                resp.raise_for_status()
                return resp.json()
            else:
                data = json.dumps(payload).encode("utf-8")
                req = urllib.request.Request(
                    url, data=data,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                with urllib.request.urlopen(req, timeout=30) as resp:
                    return json.loads(resp.read().decode())
        except Exception as e:
            log(f"POST {path} failed: {e}", "error")
            return None


# ═══════════════════════════════════════════════════════════════════════════
# SIMULATOR
# ═══════════════════════════════════════════════════════════════════════════

class DeviceSimulator:
    """Simulates an ESP32 gate controller."""

    def __init__(self, api: SmartParkAPI):
        self.api = api
        self.trigger_count = 0
        self.log_lines: list[str] = []

    def check_api(self) -> bool:
        """Check if API is reachable."""
        log("Checking API connection...", "api")
        health = self.api.health()
        if health and health.get("status") == "ok":
            log(f"API Online — ANPR: {health.get('anpr_model_loaded')}, "
                f"OCR: {health.get('ocr_engine_loaded')}, "
                f"Version: {health.get('version')}", "success")
            return True
        else:
            log("API is not reachable. Is SmartPark API running?", "error")
            log(f"Expected at: {self.api.base_url}", "warning")
            log("Start with: uvicorn api.main:app --reload --host 0.0.0.0 --port 8000", "info")
            return False

    def simulate_sensor_reading(self) -> float:
        """Simulate HC-SR04 sensor reading (vehicle at 5–25 cm)."""
        return round(random.uniform(5.0, 25.0), 1)

    def trigger_gate(self, gate_id: str, gate_type: str,
                     distance_cm: float | None = None,
                     device_id: str = "simulator") -> dict | None:
        """Simulate a full sensor trigger cycle."""
        if distance_cm is None:
            distance_cm = self.simulate_sensor_reading()

        self.trigger_count += 1
        divider(f"Trigger #{self.trigger_count}")

        # 1. Sensor reading
        log(f"Sensor reading: {C.BOLD}{distance_cm} cm{C.RESET}", "sensor")
        log(f"Gate: {C.BOLD}{gate_id}{C.RESET} ({gate_type})", "gate")
        print(GATE_PROCESSING)

        # 2. Send to API
        log(f"Sending trigger to {self.api.base_url}/device/trigger ...", "api")
        start = time.time()
        response = self.api.trigger(
            gate_id=gate_id,
            gate_type=gate_type,
            distance_cm=distance_cm,
            device_id=device_id,
        )
        elapsed = (time.time() - start) * 1000

        if not response:
            log("No response from API", "error")
            print(GATE_CLOSED)
            return None

        # 3. Parse response
        log(f"Response received in {C.BOLD}{elapsed:.0f}ms{C.RESET}", "api")
        self._display_result(response, gate_type)

        # 4. Log
        self.log_lines.append(
            f"[{timestamp()}] {gate_id} ({gate_type}) "
            f"dist={distance_cm}cm → {response.get('command', {}).get('action', '?')}"
        )

        return response

    def upload_image(self, image_path: str, gate_id: str, gate_type: str) -> dict | None:
        """Upload an image directly to the API."""
        divider("Image Upload")
        log(f"Uploading: {C.BOLD}{image_path}{C.RESET}", "api")
        log(f"Gate: {C.BOLD}{gate_id}{C.RESET} ({gate_type})", "gate")
        print(GATE_PROCESSING)

        start = time.time()
        response = self.api.process_image(image_path, gate_id, gate_type)
        elapsed = (time.time() - start) * 1000

        if not response:
            log("Upload failed", "error")
            print(GATE_CLOSED)
            return None

        log(f"Response received in {C.BOLD}{elapsed:.0f}ms{C.RESET}", "api")
        self._display_result(response, gate_type)
        return response

    def _display_result(self, response: dict, gate_type: str):
        """Display the API response in a formatted way."""
        command = response.get("command", {})
        action = command.get("action", "UNKNOWN")
        reason = command.get("reason", "")
        open_seconds = command.get("gate_open_seconds", 0)

        pipeline = response.get("pipeline", {})
        results = pipeline.get("results", [])
        proc_time = pipeline.get("processing_time_ms", 0)

        # Extract plate info
        plate_text = ""
        plate_conf = 0.0
        ocr_conf = 0.0
        vehicle_color = ""
        decision = ""

        if results:
            r = results[0]
            plate_text = r.get("plate_text", "")
            plate_conf = r.get("plate_confidence", 0.0)
            ocr_conf = r.get("ocr_confidence", 0.0)
            vehicle_color = r.get("vehicle", {}).get("color", "")
            decision = r.get("access", {}).get("decision", "")

        # Display
        divider("Hasil Deteksi")

        if plate_text:
            log(f"Plat Nomor  : {C.BOLD}{C.WHITE} {plate_text} {C.RESET}", "success")
        else:
            log(f"Plat Nomor  : {C.DIM}(tidak terdeteksi){C.RESET}", "warning")

        if plate_conf > 0:
            conf_bar = self._conf_bar(plate_conf)
            log(f"Confidence  : {conf_bar} {plate_conf:.1%}", "info")

        if ocr_conf > 0:
            ocr_bar = self._conf_bar(ocr_conf)
            log(f"OCR Conf    : {ocr_bar} {ocr_conf:.1%}", "info")

        if vehicle_color:
            log(f"Warna       : {vehicle_color}", "info")

        log(f"Processing  : {proc_time:.0f}ms", "info")

        divider("Keputusan Gate")

        if action == "OPEN_GATE":
            log(f"{C.BG_GREEN}{C.BOLD} ✅ GATE TERBUKA {C.RESET} "
                f"(selama {open_seconds:.0f}s)", "gate")
            print(GATE_OPEN)

            if gate_type == "exit":
                log(f"💰 Terima kasih! Selamat jalan.", "success")

        elif action == "MANUAL_REQUIRED":
            log(f"{C.BG_YELLOW}{C.BOLD} ⚠️  MANUAL REQUIRED {C.RESET}", "gate")
            log(f"Reason: {reason}", "warning")
            print(GATE_CLOSED)

        elif action == "KEEP_CLOSED":
            log(f"{C.BG_RED}{C.BOLD} 🚫 GATE TETAP TUTUP {C.RESET}", "gate")
            log(f"Reason: {reason}", "error")
            print(GATE_CLOSED)

        elif action == "INSUFFICIENT_BALANCE":
            log(f"{C.BG_RED}{C.BOLD} 💰 SALDO TIDAK CUKUP {C.RESET}", "gate")
            log("Silakan top-up di aplikasi SmartPark", "warning")
            print(GATE_CLOSED)

        else:
            log(f"Action: {action}", "warning")
            log(f"Reason: {reason}", "info")
            print(GATE_CLOSED)

        print()

    @staticmethod
    def _conf_bar(value: float, width: int = 20) -> str:
        filled = int(value * width)
        empty = width - filled
        if value >= 0.85:
            color = C.GREEN
        elif value >= 0.60:
            color = C.YELLOW
        else:
            color = C.RED
        return f"{color}{'█' * filled}{'░' * empty}{C.RESET}"


# ═══════════════════════════════════════════════════════════════════════════
# INTERACTIVE MENU
# ═══════════════════════════════════════════════════════════════════════════

def interactive_menu(sim: DeviceSimulator):
    """Run the interactive CLI menu."""
    print(BANNER)
    divider("System Check")

    if not sim.check_api():
        print(f"\n  {C.YELLOW}Hint: Jalankan API dulu, lalu jalankan simulator ini lagi.{C.RESET}\n")
        ans = input(f"  Lanjutkan tanpa API? (y/N): ").strip().lower()
        if ans != "y":
            return

    while True:
        print(f"""
  {C.CYAN}{C.BOLD}═══ MENU UTAMA ══════════════════════════════{C.RESET}

    {C.GREEN}1{C.RESET}) 🚗 Trigger Gate Masuk  (GATE-A-IN)
    {C.GREEN}2{C.RESET}) 🚗 Trigger Gate Keluar (GATE-A-OUT)
    {C.GREEN}3{C.RESET}) 📁 Upload Foto Kendaraan
    {C.GREEN}4{C.RESET}) 🔄 Auto-Trigger (interval)
    {C.GREEN}5{C.RESET}) 📊 Cek Status API
    {C.GREEN}6{C.RESET}) 📋 Lihat Log
    {C.GREEN}0{C.RESET}) 🚪 Keluar

  {C.DIM}{'─' * 48}{C.RESET}""")

        choice = input(f"  {C.BOLD}Pilihan [1-6, 0]: {C.RESET}").strip()

        if choice == "1":
            sim.trigger_gate("GATE-A-IN", "entry")

        elif choice == "2":
            sim.trigger_gate("GATE-A-OUT", "exit")

        elif choice == "3":
            path = input(f"  Path foto: ").strip().strip('"').strip("'")
            if not path:
                log("Path kosong, batal.", "warning")
                continue
            if not os.path.isfile(path):
                log(f"File tidak ditemukan: {path}", "error")
                continue
            gt = input(f"  Gate type (entry/exit) [entry]: ").strip() or "entry"
            gid = "GATE-A-IN" if gt == "entry" else "GATE-A-OUT"
            sim.upload_image(path, gid, gt)

        elif choice == "4":
            try:
                interval = int(input(f"  Interval (detik) [10]: ").strip() or "10")
                count = int(input(f"  Jumlah trigger (0=unlimited) [5]: ").strip() or "5")
            except ValueError:
                log("Input tidak valid", "error")
                continue
            gate_type = input(f"  Gate type (entry/exit) [entry]: ").strip() or "entry"
            gate_id = "GATE-A-IN" if gate_type == "entry" else "GATE-A-OUT"

            log(f"Auto-trigger setiap {interval}s, count={count}, gate={gate_id}", "info")
            log("Tekan Ctrl+C untuk berhenti", "warning")

            try:
                i = 0
                while count == 0 or i < count:
                    sim.trigger_gate(gate_id, gate_type)
                    i += 1
                    if count == 0 or i < count:
                        log(f"Next trigger in {interval}s...", "info")
                        time.sleep(interval)
            except KeyboardInterrupt:
                log("\nAuto-trigger dihentikan.", "warning")

        elif choice == "5":
            divider("API Status")
            sim.check_api()
            status = sim.api.device_status()
            if status:
                log(f"Mode       : {status.get('mode')}", "info")
                log(f"Camera Idx : {status.get('camera_index')}", "info")
                log(f"Save Caps  : {status.get('save_captures')}", "info")
                log(f"Gate Open  : {status.get('gate_open_seconds')}s", "info")

        elif choice == "6":
            divider("Log History")
            if sim.log_lines:
                for line in sim.log_lines:
                    print(f"    {line}")
            else:
                log("Belum ada log.", "info")

        elif choice == "0" or choice.lower() == "q":
            log("Simulator ditutup. Sampai jumpa! 👋", "info")
            break

        else:
            log("Pilihan tidak valid", "warning")


# ═══════════════════════════════════════════════════════════════════════════
# CLI ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="SmartPark Device Simulator — test IoT tanpa hardware",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/device_simulator.py                              # Interactive
  python scripts/device_simulator.py --once --gate GATE-A-IN      # Single trigger
  python scripts/device_simulator.py --auto --interval 10         # Auto every 10s
  python scripts/device_simulator.py --image foto.jpg             # Upload image
        """,
    )
    parser.add_argument("--host", default="localhost", help="API host (default: localhost)")
    parser.add_argument("--port", type=int, default=8000, help="API port (default: 8000)")
    parser.add_argument("--once", action="store_true", help="Single trigger then exit")
    parser.add_argument("--auto", action="store_true", help="Auto-trigger mode")
    parser.add_argument("--interval", type=int, default=10, help="Auto interval in seconds")
    parser.add_argument("--count", type=int, default=0, help="Auto trigger count (0=unlimited)")
    parser.add_argument("--gate", default="GATE-A-IN", help="Gate ID")
    parser.add_argument("--type", dest="gate_type", default="entry",
                        choices=["entry", "exit"], help="Gate type")
    parser.add_argument("--image", help="Upload image file instead of sensor trigger")
    parser.add_argument("--distance", type=float, help="Override sensor distance (cm)")

    args = parser.parse_args()

    api = SmartParkAPI(host=args.host, port=args.port)
    sim = DeviceSimulator(api)

    # Single image upload
    if args.image:
        print(BANNER)
        if not os.path.isfile(args.image):
            log(f"File tidak ditemukan: {args.image}", "error")
            sys.exit(1)
        sim.check_api()
        sim.upload_image(args.image, args.gate, args.gate_type)
        return

    # Single trigger
    if args.once:
        print(BANNER)
        sim.check_api()
        sim.trigger_gate(args.gate, args.gate_type, args.distance)
        return

    # Auto mode
    if args.auto:
        print(BANNER)
        if not sim.check_api():
            sys.exit(1)
        log(f"Auto-trigger: interval={args.interval}s, count={args.count or '∞'}", "info")
        log("Tekan Ctrl+C untuk berhenti", "warning")
        try:
            i = 0
            while args.count == 0 or i < args.count:
                sim.trigger_gate(args.gate, args.gate_type, args.distance)
                i += 1
                if args.count == 0 or i < args.count:
                    log(f"Next trigger in {args.interval}s...", "info")
                    time.sleep(args.interval)
        except KeyboardInterrupt:
            log("\nAuto-trigger dihentikan.", "warning")
        return

    # Interactive (default)
    interactive_menu(sim)


if __name__ == "__main__":
    main()
