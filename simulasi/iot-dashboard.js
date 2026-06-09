/* 
  Parkir Boss Web Demo — Application Logic
  Self-contained simulator with localStorage state management
*/

// ═══════════════════════════════════════════════════════════════════════
// 1. DATABASE STATE INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════
const DEFAULT_STATE = {
  users: {
    1: {
      id: 1,
      name: "Alex Boss",
      email: "alex.boss@student.its.ac.id",
      balance: 42500,
      vehicles: ["B 1234 ABC"]
    },
    2: {
      id: 2,
      name: "Budi Santoso",
      email: "budi.s@student.its.ac.id",
      balance: 150000,
      vehicles: ["B 5678 XYZ"]
    }
  },
  activeUser: 1, // Currently logged-in user in app
  sessions: [],  // Parking sessions
  transactions: [
    {
      id: "TX-001",
      user_id: 1,
      type: "TOPUP",
      amount: 50000,
      time: new Date(Date.now() - 3600000 * 24).toISOString(), // 1 day ago
      description: "Top Up via GoPay"
    },
    {
      id: "TX-002",
      user_id: 1,
      type: "PARKING_FEE",
      amount: -7500,
      time: new Date(Date.now() - 3600000 * 2).toISOString(),  // 2 hours ago
      description: "Parkir B 1234 ABC — 90 menit"
    }
  ],
  slots: {
    // Floor 0 (Lantai A)
    0: {
      A1: { status: "available" },
      A2: { status: "occupied" },
      A3: { status: "recommended", label: "TERDEKAT" },
      B1: { status: "available" },
      B2: { status: "available" },
      B3: { status: "occupied" },
      C1: { status: "available" },
      C2: { status: "available" },
      C3: { status: "available" },
      A4: { status: "available" }
    },
    // Floor 1 (Lantai B)
    1: {
      A1: { status: "occupied" },
      A2: { status: "occupied" },
      A3: { status: "available" },
      B1: { status: "available" },
      B2: { status: "recommended", label: "REKOMENDASI" },
      B3: { status: "occupied" },
      C1: { status: "occupied" },
      C2: { status: "available" },
      C3: { status: "available" },
      A4: { status: "available" }
    },
    // Floor 2 (Lantai C)
    2: {
      A1: { status: "available" },
      A2: { status: "available" },
      A3: { status: "occupied" },
      B1: { status: "available" },
      B2: { status: "available" },
      B3: { status: "available" },
      C1: { status: "recommended", label: "REKOMENDASI" },
      C2: { status: "occupied" },
      C3: { status: "occupied" },
      A4: { status: "available" }
    }
  },
  onboardingCompleted: false
};

// Load or seed database
let db = JSON.parse(localStorage.getItem('parkirboss_demo_db'));
if (!db) {
  db = JSON.parse(JSON.stringify(DEFAULT_STATE));
  localStorage.setItem('parkirboss_demo_db', JSON.stringify(db));
}

// System Constants
const PARKING_RATE_PER_HOUR = 5000;
const PARKING_MAX_DAILY = 50000;

// ═══════════════════════════════════════════════════════════════════════
// REALTIME CONFIG — driven by the real SmartPark device API (ESP32 sensor)
// ═══════════════════════════════════════════════════════════════════════
let BASE = (localStorage.getItem('sp_base') ||
            (location.protocol.startsWith('http') ? location.origin : 'http://10.209.254.249:8000')
           ).replace(/\/+$/, '');
let lastEventId = 0;
let backendOnline = false;

// Non-blocking toast — replaces alert() so the event polling loop never blocks.
function showToast(msg) {
  let t = document.getElementById('sp-toast');
  if (!t) {
    t = document.createElement('div');
    t.id = 'sp-toast';
    t.style.cssText = 'position:fixed;left:50%;bottom:24px;transform:translateX(-50%);z-index:9999;max-width:90%;' +
      'background:#1d1b20;color:#fff;border:3px solid #000;box-shadow:6px 6px 0 #000;padding:12px 16px;' +
      'font-family:monospace;font-size:13px;white-space:pre-line;';
    document.body.appendChild(t);
  }
  t.textContent = msg;
  t.style.display = 'block';
  clearTimeout(t._timer);
  t._timer = setTimeout(() => { t.style.display = 'none'; }, 4200);
}
// Route blocking alerts to the toast + console so realtime polling stays smooth.
window.alert = (msg) => { showToast(String(msg)); addLog('[NOTICE] ' + String(msg).replace(/\n/g, ' — '), 'warn'); };

// ═══════════════════════════════════════════════════════════════════════
// 2. HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════
function saveDB() {
  localStorage.setItem('parkirboss_demo_db', JSON.stringify(db));
}

function formatRupiah(amount) {
  const formatted = Math.abs(amount).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  return (amount < 0 ? "- " : "") + "Rp " + formatted;
}

function getTimestampString() {
  const now = new Date();
  return now.toTimeString().split(' ')[0];
}

function addLog(message, type = "info") {
  const consoleBox = document.getElementById("console-output-box");
  const timeStr = getTimestampString();
  const line = document.createElement("div");
  line.className = "console-line";
  
  let typeClass = "info";
  if (type === "success") typeClass = "success";
  if (type === "warn") typeClass = "warn";
  if (type === "error") typeClass = "error";

  line.innerHTML = `<span class="console-line timestamp">[${timeStr}]</span> <span class="console-line ${typeClass}">${message}</span>`;
  consoleBox.appendChild(line);
  consoleBox.scrollTop = consoleBox.scrollHeight;
}

// ═══════════════════════════════════════════════════════════════════════
// 3. SIMULATOR INTERACTION LOGIC
// ═══════════════════════════════════════════════════════════════════════
let localStream = null;
let isLiveCameraOn = false;

async function startCamera() {
  const videoEl = document.getElementById('cctv-video');
  const imgEl = document.getElementById('cctv-car-img');
  const viewport = document.getElementById('cctv-viewport');
  
  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    const errorMsg = 'Fitur kamera tidak tersedia karena masalah keamanan browser. Akses kamera (getUserMedia) hanya diizinkan melalui localhost atau koneksi aman (HTTPS).';
    addLog("[CAMERA] ❌ API mediaDevices tidak tersedia (butuh HTTPS/localhost).", "error");
    alert("Gagal mengakses kamera:\n\n" + errorMsg);
    return;
  }
  
  try {
    localStream = await navigator.mediaDevices.getUserMedia({
      video: {
        width: { ideal: 1280 },
        height: { ideal: 720 },
        facingMode: "environment"
      }
    });
    
    if (videoEl) {
      videoEl.srcObject = localStream;
      videoEl.style.display = "block";
      if (imgEl) imgEl.style.display = "none";
      viewport.classList.add('live-active');
      
      isLiveCameraOn = true;
      document.getElementById('btn-start-live').style.display = 'none';
      document.getElementById('btn-stop-live').style.display = '';
      const modeLabel = document.getElementById('cctv-mode-label');
      if (modeLabel) modeLabel.textContent = 'LIVE WEBCAM STREAM';
      
      addLog("[CAMERA] ✅ Kamera live berhasil diaktifkan.", "success");
      addLog("[CAMERA] Webcam menyimulasikan ESP32-CAM OV2640.", "info");
      
      setupAutoScan();
      const chkAutoScan = document.getElementById('chk-auto-scan');
      if (chkAutoScan && chkAutoScan.checked) {
        startAutoScanLoop();
      }
    }
  } catch (err) {
    addLog("[CAMERA] ❌ Gagal mengakses kamera: " + err.message, "error");
    console.warn("Error accessing camera:", err);
    if (videoEl) videoEl.style.display = "none";
    if (imgEl) imgEl.style.display = "block";
    viewport.classList.remove('live-active');
  }
}

function stopCamera() {
  if (localStream) {
    localStream.getTracks().forEach(t => t.stop());
    localStream = null;
  }
  const videoEl = document.getElementById('cctv-video');
  const imgEl = document.getElementById('cctv-car-img');
  const viewport = document.getElementById('cctv-viewport');
  
  if (videoEl) { videoEl.srcObject = null; videoEl.style.display = 'none'; }
  if (imgEl) imgEl.style.display = 'block';
  viewport.classList.remove('live-active');
  isLiveCameraOn = false;
  
  document.getElementById('btn-start-live').style.display = '';
  document.getElementById('btn-stop-live').style.display = 'none';
  const modeLabel = document.getElementById('cctv-mode-label');
  if (modeLabel) modeLabel.textContent = 'SENSOR-TRIGGERED CAPTURE';
  
  // Stop auto-scan if running
  const chk = document.getElementById('chk-auto-scan');
  if (chk) chk.checked = false;
  stopAutoScanLoop();
  clearDetectionOverlay();
  
  addLog("[CAMERA] Kamera live dihentikan.", "warn");
}

// Wire up camera buttons
document.getElementById('btn-start-live').addEventListener('click', startCamera);
document.getElementById('btn-stop-live').addEventListener('click', stopCamera);

// ═══════════════════════════════════════════════════════════════════════
// ESP32-CAM LIVE STREAM + BACKEND-PULL AUTO-SCAN (real IoT, hybrid mode)
// The ESP32-CAM streams MJPEG (shown as the live feed). The backend pulls one
// frame every ~1.8s via /device/scan, runs ANPR+OCR, and emits an event — the
// /device/events poller then draws the box + OCR over the stream.
// ═══════════════════════════════════════════════════════════════════════
let isEsp32CamOn = false;
let esp32ScanInterval = null;
let esp32Cameras = {};                 // gate_id -> camera info from /device/cameras
const ESP32_SCAN_INTERVAL_MS = 1800;

// Per-plate dedup so continuous auto-scan does not re-run billing/session logic
// for the same vehicle. Shared by the ESP32 scan + local webcam auto-scan.
let lastProcessedPlate = '';
let lastProcessedAt = 0;
const PLATE_DEDUP_MS = 8000;

function maybeProcessGate(plate, gateId) {
  const norm = (plate || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
  const now = Date.now();
  if (norm && (norm !== lastProcessedPlate || now - lastProcessedAt > PLATE_DEDUP_MS)) {
    lastProcessedPlate = norm;
    lastProcessedAt = now;
    processGatePipeline(plate, gateId);
    return true;
  }
  return false;  // same plate within cooldown — visual already refreshed, skip business logic
}

async function discoverEsp32Cameras() {
  try {
    const r = await fetch(BASE + '/device/cameras', { signal: AbortSignal.timeout(2500) });
    if (!r.ok) return esp32Cameras;
    const data = await r.json();
    esp32Cameras = {};
    (data.cameras || []).forEach(c => { esp32Cameras[c.gate_id] = c; });
  } catch { /* keep previous list */ }
  return esp32Cameras;
}

async function startEsp32Camera() {
  const gateId = document.getElementById('select-gate-id').value;
  await discoverEsp32Cameras();
  let cam = esp32Cameras[gateId];

  // Fallback: let the operator type the stream URL if the camera hasn't registered.
  if (!cam) {
    const manual = prompt(
      'Tidak ada ESP32-CAM ter-registrasi untuk ' + gateId + '.\n' +
      'Masukkan URL stream ESP32-CAM (mis. http://192.168.1.50:81/stream),\n' +
      'atau kosongkan untuk batal:', '');
    if (!manual) { addLog('[ESP32] Dibatalkan — tidak ada kamera.', 'warn'); return; }
    const ip = (manual.match(/https?:\/\/([^:\/]+)/) || [])[1] || '';
    cam = { gate_id: gateId, stream_url: manual.trim(), capture_url: ip ? ('http://' + ip + '/capture') : '' };
    esp32Cameras[gateId] = cam;
  }

  if (isLiveCameraOn) stopCamera();  // stop local webcam if active

  const streamImg = document.getElementById('cctv-esp32-stream');
  const carImg = document.getElementById('cctv-car-img');
  const viewport = document.getElementById('cctv-viewport');

  // cache-bust so a restarted ESP32 stream re-attaches
  streamImg.src = cam.stream_url + (cam.stream_url.includes('?') ? '&' : '?') + 't=' + Date.now();
  streamImg.onerror = () => addLog('[ESP32] ⚠️ Tidak bisa memuat stream ' + cam.stream_url + ' (cek IP/WiFi/port 81).', 'error');
  streamImg.style.display = 'block';
  if (carImg) carImg.style.display = 'none';
  viewport.classList.add('live-active');

  isEsp32CamOn = true;
  document.getElementById('btn-esp32-cam').style.display = 'none';
  document.getElementById('btn-esp32-stop').style.display = '';
  const modeLabel = document.getElementById('cctv-mode-label');
  if (modeLabel) modeLabel.textContent = 'ESP32-CAM LIVE STREAM';

  addLog('[ESP32] Live stream aktif: ' + cam.stream_url, 'success');
  addLog('[ESP32] Auto-scan ANPR via backend tiap ' + (ESP32_SCAN_INTERVAL_MS / 1000) + ' detik.', 'info');
  startEsp32ScanLoop();
}

function stopEsp32Camera() {
  stopEsp32ScanLoop();
  const streamImg = document.getElementById('cctv-esp32-stream');
  const carImg = document.getElementById('cctv-car-img');
  const viewport = document.getElementById('cctv-viewport');
  if (streamImg) { streamImg.onerror = null; streamImg.src = ''; streamImg.style.display = 'none'; }
  if (carImg) carImg.style.display = 'block';
  viewport.classList.remove('live-active');
  isEsp32CamOn = false;
  document.getElementById('btn-esp32-cam').style.display = '';
  document.getElementById('btn-esp32-stop').style.display = 'none';
  const modeLabel = document.getElementById('cctv-mode-label');
  if (modeLabel) modeLabel.textContent = 'SENSOR-TRIGGERED CAPTURE';
  clearDetectionOverlay();
  addLog('[ESP32] Live stream dihentikan.', 'warn');
}

function startEsp32ScanLoop() {
  stopEsp32ScanLoop();
  esp32ScanInterval = setInterval(async () => {
    if (!isEsp32CamOn) { stopEsp32ScanLoop(); return; }
    const gateId = document.getElementById('select-gate-id').value;
    const cam = esp32Cameras[gateId];
    const qs = '?gate_id=' + encodeURIComponent(gateId) +
               (cam && cam.capture_url ? '&camera_url=' + encodeURIComponent(cam.capture_url) : '') +
               '&confidence=0.25&nearest_only=true';
    try {
      // Box + OCR are rendered by the /device/events poller from the emitted event.
      await fetch(BASE + '/device/scan' + qs, { method: 'POST', signal: AbortSignal.timeout(8000) });
    } catch { /* drop this frame, try again next tick */ }
  }, ESP32_SCAN_INTERVAL_MS);
}

function stopEsp32ScanLoop() {
  if (esp32ScanInterval) { clearInterval(esp32ScanInterval); esp32ScanInterval = null; }
}

document.getElementById('btn-esp32-cam').addEventListener('click', startEsp32Camera);
document.getElementById('btn-esp32-stop').addEventListener('click', stopEsp32Camera);

let autoScanInterval = null;

function setupAutoScan() {
  const chkAutoScan = document.getElementById('chk-auto-scan');
  if (!chkAutoScan) return;

  if (chkAutoScan.dataset.setupDone === "true") return;
  chkAutoScan.dataset.setupDone = "true";

  chkAutoScan.addEventListener('change', function() {
    if (this.checked) {
      addLog("[AUTOSCAN] Mode deteksi otomatis diaktifkan.", "info");
      startAutoScanLoop();
    } else {
      addLog("[AUTOSCAN] Mode deteksi otomatis dimatikan.", "info");
      stopAutoScanLoop();
    }
  });
}

function startAutoScanLoop() {
  if (autoScanInterval) clearInterval(autoScanInterval);
  autoScanInterval = setInterval(async () => {
    const chkAutoScan = document.getElementById('chk-auto-scan');
    if (!chkAutoScan || !chkAutoScan.checked) {
      stopAutoScanLoop();
      return;
    }

    const videoEl = document.getElementById('cctv-video');
    const gateIndicator = document.getElementById('gate-barrier-status');
    const isGateClosed = gateIndicator && gateIndicator.classList.contains('closed');
    
    if (localStream && videoEl && videoEl.srcObject && videoEl.videoWidth > 0 && isGateClosed) {
      await performAutoScan();
    }
  }, 1500);
}

function stopAutoScanLoop() {
  if (autoScanInterval) {
    clearInterval(autoScanInterval);
    autoScanInterval = null;
  }
}

async function performAutoScan() {
  const videoEl = document.getElementById('cctv-video');
  const scannerLine = document.querySelector('.cctv-scanner-line');
  const gateId = document.getElementById('select-gate-id').value;
  
  if (!videoEl || !videoEl.srcObject || videoEl.videoWidth === 0) return;

  if (scannerLine) scannerLine.style.animationDuration = '0.5s';

  try {
    const imgW = videoEl.videoWidth;
    const imgH = videoEl.videoHeight;
    const canvas = document.createElement('canvas');
    canvas.width = imgW;
    canvas.height = imgH;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(videoEl, 0, 0, imgW, imgH);
    
    const blob = await new Promise((resolve) => {
      canvas.toBlob((b) => resolve(b), 'image/jpeg', 0.9);
    });
    
    const formData = new FormData();
    formData.append('file', blob, 'autoscan.jpg');
    
    // Use /pipeline/verify which returns bbox data for bounding box drawing
    const response = await fetch(BASE + '/pipeline/verify?confidence=0.25&nearest_only=true', {
      method: 'POST',
      body: formData
    });

    if (!response.ok) return;

    const data = await response.json();

    // Draw bounding boxes on the overlay
    drawBoundingBoxes(data, imgW, imgH);
    updateDetectBar(data);

    if (data.results && data.results.length > 0 && data.results[0].plate_text) {
      const r = data.results[0];
      const plate = r.plate_text;
      const confidence = ((r.plate_confidence || 0) * 100).toFixed(1);

      addLog(`[AUTOSCAN] Plat terdeteksi: "${plate}" (Confidence: ${confidence}%)`, "success");
      document.getElementById('plate-ocr-result').textContent = plate;

      // Proceed to Pipeline Process (deduped so continuous scan won't double-bill)
      maybeProcessGate(plate, gateId);
    } else {
      addLog('[AUTOSCAN] Tidak ada plat terdeteksi pada frame ini.', 'warn');
    }
  } catch (err) {
    console.error("Autoscan error:", err);
  } finally {
    if (scannerLine) scannerLine.style.animationDuration = '3s';
  }
}

/* ─── BOUNDING BOX DRAWING ─── */
function drawBoundingBoxes(data, imageWidth, imageHeight) {
  const overlayCanvas = document.getElementById('cctv-detect-overlay');
  const viewport = document.getElementById('cctv-viewport');
  if (!overlayCanvas || !viewport) return;

  const vpRect = viewport.getBoundingClientRect();
  overlayCanvas.width = vpRect.width;
  overlayCanvas.height = vpRect.height;

  const ctx = overlayCanvas.getContext('2d');
  ctx.clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);

  if (!data.results || data.results.length === 0) return;

  // Calculate scale to map image coordinates to viewport coordinates
  const vpAspect = vpRect.width / vpRect.height;
  const imgAspect = imageWidth / imageHeight;
  let drawW, drawH, offsetX, offsetY;
  if (imgAspect > vpAspect) {
    drawW = vpRect.width;
    drawH = vpRect.width / imgAspect;
    offsetX = 0;
    offsetY = (vpRect.height - drawH) / 2;
  } else {
    drawH = vpRect.height;
    drawW = vpRect.height * imgAspect;
    offsetX = (vpRect.width - drawW) / 2;
    offsetY = 0;
  }
  const scaleX = drawW / imageWidth;
  const scaleY = drawH / imageHeight;

  for (const result of data.results) {
    if (!result.bbox) continue;

    const { x1, y1, x2, y2 } = result.bbox;
    const bx = offsetX + x1 * scaleX;
    const by = offsetY + y1 * scaleY;
    const bw = (x2 - x1) * scaleX;
    const bh = (y2 - y1) * scaleY;

    const isGranted = result.access && (result.access.decision === 'GRANTED' || result.access.decision === 'GRANTED_WITH_LOG');
    const boxColor = isGranted ? '#00e676' : '#ff5252';
    const boxGlow = isGranted ? 'rgba(0,230,118,0.4)' : 'rgba(255,82,82,0.4)';

    // Glow + box
    ctx.shadowColor = boxGlow;
    ctx.shadowBlur = 10;
    ctx.strokeStyle = boxColor;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.rect(bx, by, bw, bh);
    ctx.stroke();

    // Corner accents
    ctx.shadowBlur = 0;
    ctx.lineWidth = 3;
    const cl = Math.min(bw, bh) * 0.2;
    ctx.beginPath(); ctx.moveTo(bx, by + cl); ctx.lineTo(bx, by); ctx.lineTo(bx + cl, by); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(bx + bw - cl, by); ctx.lineTo(bx + bw, by); ctx.lineTo(bx + bw, by + cl); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(bx, by + bh - cl); ctx.lineTo(bx, by + bh); ctx.lineTo(bx + cl, by + bh); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(bx + bw - cl, by + bh); ctx.lineTo(bx + bw, by + bh); ctx.lineTo(bx + bw, by + bh - cl); ctx.stroke();

    // Label
    const plateText = result.plate_text || '???';
    const conf = ((result.plate_confidence || 0) * 100).toFixed(0);
    const labelText = `${plateText}  ${conf}%`;
    ctx.font = 'bold 11px monospace';
    const tm = ctx.measureText(labelText);
    const lw = tm.width + 12;
    const lh = 18;
    const lx = bx;
    const ly = by - lh - 3;

    ctx.fillStyle = boxColor;
    ctx.shadowColor = boxGlow;
    ctx.shadowBlur = 6;
    ctx.fillRect(lx, Math.max(0, ly), lw, lh);
    ctx.shadowBlur = 0;

    ctx.fillStyle = '#000';
    ctx.font = 'bold 10px monospace';
    ctx.fillText(labelText, lx + 6, Math.max(0, ly) + 13);
  }
}

function clearDetectionOverlay() {
  const overlayCanvas = document.getElementById('cctv-detect-overlay');
  if (overlayCanvas) {
    const ctx = overlayCanvas.getContext('2d');
    ctx.clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);
  }
  const bar = document.getElementById('cctv-detect-bar');
  if (bar) bar.classList.remove('show');
}

function updateDetectBar(data) {
  const bar = document.getElementById('cctv-detect-bar');
  if (!bar) return;
  if (!data.results || data.results.length === 0 || !data.results[0].plate_text) {
    bar.classList.remove('show');
    return;
  }
  const r = data.results[0];
  const detectConf = ((r.plate_confidence || 0) * 100).toFixed(1);
  const ocrConf = ((r.ocr_confidence || 0) * 100).toFixed(1);
  const decision = r.access?.decision || 'DENIED';
  const isGranted = decision === 'GRANTED' || decision === 'GRANTED_WITH_LOG';

  document.getElementById('cctv-detect-plate').textContent = r.plate_text;
  document.getElementById('cctv-detect-conf').textContent = `Det: ${detectConf}% · OCR: ${ocrConf}%`;

  const badge = document.getElementById('cctv-detect-badge');
  badge.textContent = isGranted ? '✅ GRANTED' : '🚫 DENIED';
  badge.className = 'cctv-detect-badge ' + (isGranted ? 'granted' : 'denied');

  bar.classList.add('show');
}

let selectedPresetPlate = "B 1234 ABC";
let simulatedDurationHours = 3; // Default simulated duration for exit billing

// Generate preset car SVG images to change viewport
const CAR_SVGS = {
  "B 1234 ABC": `<svg xmlns='http://www.w3.org/2000/svg' width='320' height='200' viewBox='0 0 320 200'><rect width='320' height='200' fill='#0e0a16'/><path d='M60 140 L100 80 L220 80 L260 140 Z' fill='#4F378A' stroke='#1d1b20' stroke-width='4'/><rect x='80' y='120' width='160' height='40' fill='#e9ddff' stroke='#1d1b20' stroke-width='4'/><circle cx='95' cy='160' r='20' fill='#1d1b20'/><circle cx='225' cy='160' r='20' fill='#1d1b20'/><rect x='130' y='135' width='60' height='15' fill='#ffffff' stroke='#1d1b20' stroke-width='2'/><text x='160' y='146' font-family='monospace' font-size='10' font-weight='bold' text-anchor='middle' fill='#1d1b20'>B 1234 ABC</text></svg>`,
  "B 5678 XYZ": `<svg xmlns='http://www.w3.org/2000/svg' width='320' height='200' viewBox='0 0 320 200'><rect width='320' height='200' fill='#0e0a16'/><path d='M60 140 L100 80 L220 80 L260 140 Z' fill='#765B00' stroke='#1d1b20' stroke-width='4'/><rect x='80' y='120' width='160' height='40' fill='#ffdf93' stroke='#1d1b20' stroke-width='4'/><circle cx='95' cy='160' r='20' fill='#1d1b20'/><circle cx='225' cy='160' r='20' fill='#1d1b20'/><rect x='130' y='135' width='60' height='15' fill='#ffffff' stroke='#1d1b20' stroke-width='2'/><text x='160' y='146' font-family='monospace' font-size='10' font-weight='bold' text-anchor='middle' fill='#1d1b20'>B 5678 XYZ</text></svg>`,
  "B 9999 BOSS": `<svg xmlns='http://www.w3.org/2000/svg' width='320' height='200' viewBox='0 0 320 200'><rect width='320' height='200' fill='#0e0a16'/><path d='M60 140 L100 80 L220 80 L260 140 Z' fill='#ba1a1a' stroke='#1d1b20' stroke-width='4'/><rect x='80' y='120' width='160' height='40' fill='#ffdad6' stroke='#1d1b20' stroke-width='4'/><circle cx='95' cy='160' r='20' fill='#1d1b20'/><circle cx='225' cy='160' r='20' fill='#1d1b20'/><rect x='130' y='135' width='60' height='15' fill='#ffffff' stroke='#1d1b20' stroke-width='2'/><text x='160' y='146' font-family='monospace' font-size='10' font-weight='bold' text-anchor='middle' fill='#1d1b20'>B 9999 BOSS</text></svg>`,
  "CUSTOM": `<svg xmlns='http://www.w3.org/2000/svg' width='320' height='200' viewBox='0 0 320 200'><rect width='320' height='200' fill='#0e0a16'/><path d='M60 140 L100 80 L220 80 L260 140 Z' fill='#63597c' stroke='#1d1b20' stroke-width='4'/><rect x='80' y='120' width='160' height='40' fill='#f2ecf4' stroke='#1d1b20' stroke-width='4'/><circle cx='95' cy='160' r='20' fill='#1d1b20'/><circle cx='225' cy='160' r='20' fill='#1d1b20'/><rect x='130' y='135' width='60' height='15' fill='#ffffff' stroke='#1d1b20' stroke-width='2'/><text x='160' y='146' font-family='monospace' font-size='10' font-weight='bold' text-anchor='middle' fill='#1d1b20' id='svg-custom-text'>CUSTOM</text></svg>`
};

// Viewer image updater helper
function updateCCTVImage(presetName, customText = "") {
  const viewport = document.getElementById('cctv-viewport');
  if (!presetName) presetName = "CUSTOM";
  
  let svgContent = CAR_SVGS[presetName];
  if (!svgContent) {
    // Dynamically clone B 1234 ABC SVG and replace the plate text
    svgContent = CAR_SVGS["B 1234 ABC"].replace("B 1234 ABC", presetName);
    CAR_SVGS[presetName] = svgContent; // Cache it
  }

  if (presetName === "CUSTOM" && customText) {
    svgContent = svgContent.replace('CUSTOM', customText);
  }
  
  const imgElement = viewport.querySelector('.car-image');
  if (imgElement) {
    imgElement.src = "data:image/svg+xml;utf8," + encodeURIComponent(svgContent);
  }
}

// GPS check is not part of the hardware gate flow (no GPS at the gate) — treat as near.
let gpsNearby = true;

// Gate is determined by the hardware event (gate_id/gate_type) — no manual selector.

// Reset Demo button
document.getElementById('btn-reset-demo').addEventListener('click', function() {
  if (confirm("Apakah Anda yakin ingin menyetel ulang data demo ke awal? Semua saldo, sesi, dan riwayat akan di-reset.")) {
    db = JSON.parse(JSON.stringify(DEFAULT_STATE));
    saveDB();
    addLog("[SYSTEM] Database reset to seed state.", "warn");
    initApp();
    refreshAdminTables();
    renderNearbySlots();
  }
});

// Clear Backend Console logs
document.getElementById('btn-clear-console').addEventListener('click', function() {
  document.getElementById('console-output-box').innerHTML = "";
  addLog("[SYSTEM] Console log cleared.");
});

// Manual webcam capture removed — image capture is triggered by the real ESP32
// sensor at the gate. Incoming captures arrive via the realtime device-event
// bridge (handleDeviceEvent) at the bottom of this file.

// Kept for reference; not wired to any button in realtime mode.
function runSimulatorFallback(triggerBtn, originalHtml, scannerLine, gateId) {
  setTimeout(() => {
    triggerBtn.disabled = false;
    triggerBtn.innerHTML = originalHtml;
    scannerLine.style.animationDuration = '3s';
    
    const activeUserObj = db.users[db.activeUser];
    let plate = activeUserObj && activeUserObj.vehicles && activeUserObj.vehicles[0] ? activeUserObj.vehicles[0] : "B 1234 ABC";
    
    if (!plate) {
      alert("Tidak ada kendaraan terdaftar untuk disimulasikan!");
      return;
    }
    
    addLog(`[OCR] Plate recognized (Simulated): "${plate}" (Accuracy: 98.7%)`, "success");
    document.getElementById('plate-ocr-result').textContent = plate;
    processGatePipeline(plate, gateId);
  }, 1000);
}

// ═══════════════════════════════════════════════════════════════════════
// TEST TRIGGER (tanpa hardware): kirim foto ke /device/process-image.
// Backend memproses ANPR+OCR & mencatat event; poller realtime menampilkannya
// persis seperti saat sensor ESP32 yang memicu capture.
// ═══════════════════════════════════════════════════════════════════════
const btnFileUpload = document.getElementById('btn-file-upload');
const inputFileUpload = document.getElementById('input-file-upload');

if (btnFileUpload && inputFileUpload) {
  btnFileUpload.addEventListener('click', () => inputFileUpload.click());

  inputFileUpload.addEventListener('change', async function() {
    const file = this.files[0];
    this.value = '';
    if (!file) return;

    const gateType = (document.getElementById('test-gate-type') || {}).value || 'entry';
    const gateId = gateType === 'exit' ? 'GATE-A-OUT' : 'GATE-A-IN';
    const prev = btnFileUpload.innerHTML;
    const scannerLine = document.querySelector('.cctv-scanner-line');

    btnFileUpload.disabled = true;
    btnFileUpload.innerHTML = `<i class="material-icons animate-spin">autorenew</i> MENGIRIM…`;
    if (scannerLine) scannerLine.style.animationDuration = '0.5s';
    setSensorState('MENGIRIM…', 'idle');
    addLog(`[TEST] Mengirim "${file.name}" sebagai trigger ${gateType} @ ${gateId}…`, 'info');

    // Local preview langsung di viewport (akan digantikan foto backend saat event masuk)
    const reader = new FileReader();
    reader.onload = (e) => { const img = document.getElementById('cctv-car-img'); if (img) { img.src = e.target.result; img.style.display = 'block'; } };
    reader.readAsDataURL(file);

    try {
      const fd = new FormData();
      fd.append('file', file);
      fd.append('device_id', 'dashboard-test');
      fd.append('gate_id', gateId);
      fd.append('gate_type', gateType);
      fd.append('sensor', 'dashboard-upload');
      fd.append('confidence', '0.25');
      fd.append('nearest_only', 'true');

      const res = await fetch(BASE + '/device/process-image', { method: 'POST', body: fd });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      addLog('[TEST] Terkirim ke /device/process-image. Menunggu event dari backend…', 'success');
      // Poller realtime akan mengambil event baru ini dan merendernya seperti trigger sensor asli.
    } catch (err) {
      addLog('[TEST] ❌ Gagal kirim ke backend: ' + err.message, 'error');
      showToast('Gagal kirim ke backend: ' + err.message);
    } finally {
      btnFileUpload.disabled = false;
      btnFileUpload.innerHTML = prev;
      if (scannerLine) scannerLine.style.animationDuration = '3s';
    }
  });
}

// ═══════════════════════════════════════════════════════════════════════
// 4. CORE PIPELINE SIMULATOR (FastAPI / DB logic)
// ═══════════════════════════════════════════════════════════════════════
// Helper for Levenshtein Distance (Fuzzy Match)
function getLevenshteinDistance(a, b) {
  const tmp = [];
  let i, j;
  for (i = 0; i <= a.length; i++) {
    tmp[i] = [i];
  }
  for (j = 0; j <= b.length; j++) {
    tmp[0][j] = j;
  }
  for (i = 1; i <= a.length; i++) {
    for (j = 1; j <= b.length; j++) {
      tmp[i][j] = a.charAt(i - 1) === b.charAt(j - 1) 
        ? tmp[i - 1][j - 1] 
        : Math.min(tmp[i - 1][j - 1] + 1, Math.min(tmp[i][j - 1] + 1, tmp[i - 1][j] + 1));
    }
  }
  return tmp[a.length][b.length];
}

function processGatePipeline(plate, gateId) {
  addLog(`[DB] Looking up vehicle "${plate}" in registered records...`, "info");
  
  // Normalize function
  const normalizePlate = (p) => p.toUpperCase().replace(/[^A-Z0-9]/g, "");
  const normPlate = normalizePlate(plate);

  let owner = null;
  let ownerId = null;
  let matchedPlate = null;
  let maxSimilarity = 0;

  // Search vehicle ownership with exact or fuzzy matching
  for (const uid in db.users) {
    for (const v of db.users[uid].vehicles) {
      const normV = normalizePlate(v);
      if (normV === normPlate) {
        owner = db.users[uid];
        ownerId = parseInt(uid);
        matchedPlate = v;
        maxSimilarity = 1.0;
        break;
      }
      
      const dist = getLevenshteinDistance(normPlate, normV);
      const maxLen = Math.max(normPlate.length, normV.length);
      const similarity = maxLen > 0 ? (maxLen - dist) / maxLen : 0;
      
      // Allow match if similarity >= 0.70 (or max 2 character difference)
      if (similarity >= 0.70 && similarity > maxSimilarity) {
        owner = db.users[uid];
        ownerId = parseInt(uid);
        matchedPlate = v;
        maxSimilarity = similarity;
      }
    }
    if (maxSimilarity === 1.0) break;
  }

  if (matchedPlate && matchedPlate !== plate) {
    addLog(`[DB] ⚠️ Plat terdeteksi "${plate}" mirip dengan "${matchedPlate}" (Kecocokan: ${(maxSimilarity * 100).toFixed(1)}%). Menggunakan "${matchedPlate}".`, "warn");
    plate = matchedPlate;
  }

  // ── ① DB Check ──
  if (!owner) {
    addLog(`[DB] ❌ Vehicle plate "${plate}" is NOT registered in the database.`, "error");
    addLog(`[GATE] Action: MANUAL_REQUIRED. Dispatching operator assistance.`, "warn");
    alert(`AKSI: MANUAL_REQUIRED\nAlasan: Kendaraan ${plate} tidak terdaftar.`);
    return;
  }
  
  addLog(`[DB] ✅ Vehicle registered. Owner: ${owner.name} (${owner.email})`, "success");

  // ── ② GPS Radius Check ──
  addLog(`[GPS] Checking user location relative to gate coordinates...`, "info");
  if (!gpsNearby) {
    const simulatedDistance = 250.4;
    addLog(`[GPS] ❌ Location verification failed. User is ${simulatedDistance}m away. Max allowed: 15m.`, "error");
    addLog(`[GATE] Action: REJECTED. Palang tetap ditutup.`, "error");
    alert(`AKSI: REJECTED\nAlasan: Lokasi GPS terlalu jauh (${simulatedDistance}m, maks 15m).`);
    return;
  }
  addLog(`[GPS] ✅ Location verified. User distance: 5.2 meters (Within radius).`, "success");

  // ── ③ Gate Entry vs Exit Flow ──
  if (gateId === "GATE-A-IN") {
    // Check if session already active
    const activeSession = db.sessions.find(s => s.plate === plate && s.status === "ACTIVE");
    if (activeSession) {
      addLog(`[DB] ❌ Vehicle "${plate}" already has an ACTIVE parking session (Sess ID: ${activeSession.id}).`, "error");
      alert(`AKSI: REJECTED\nAlasan: Sesi parkir kendaraan ${plate} sudah aktif.`);
      return;
    }

    // Start a new session
    const sessionId = "SESS-" + Math.floor(100 + Math.random() * 900);
    
    // Check if owner already pre-reserved a slot
    let assignedSlot = "A3";
    let assignedFloor = 0;
    if (owner.claimed_slot) {
      assignedSlot = owner.claimed_slot.slot;
      assignedFloor = owner.claimed_slot.floor;
      delete owner.claimed_slot;
      addLog(`[DB] Utilizing pre-reserved Slot ${assignedSlot} (Floor ${assignedFloor}) for this session.`, "success");
    } else {
      // Auto-assign the recommended slot if available
      if (db.slots[0]["A3"].status !== "occupied") {
        assignedSlot = "A3";
        assignedFloor = 0;
        db.slots[0]["A3"].status = "occupied";
        addLog(`[DB] Auto-assigned recommended Slot A3 (Floor 0) to session.`, "info");
      } else {
        // Find first available slot
        let found = false;
        for (let f = 0; f < 3; f++) {
          for (const sKey in db.slots[f]) {
            if (db.slots[f][sKey].status !== "occupied") {
              assignedSlot = sKey;
              assignedFloor = f;
              db.slots[f][sKey].status = "occupied";
              found = true;
              break;
            }
          }
          if (found) break;
        }
      }
    }

    const newSession = {
      id: sessionId,
      user_id: ownerId,
      plate: plate,
      gate_in: gateId,
      entry_time: new Date().toISOString(),
      status: "ACTIVE",
      slot: assignedSlot,
      floor: assignedFloor
    };
    db.sessions.push(newSession);
    saveDB();

    addLog(`[DB] ✅ Parking Session created successfully: ${sessionId}`, "success");
    addLog(`[GATE] Action: OPEN_GATE. Buka palang pintu masuk. Selamat datang!`, "success");
    
    triggerGateGateAnimation(true);
    
    // Instantly refresh current screen views if matching app logged in user
    initApp();
    refreshAdminTables();
    renderNearbySlots();
    
  } else if (gateId === "GATE-A-OUT") {
    // Find active session
    const sessionIndex = db.sessions.findIndex(s => s.plate === plate && s.status === "ACTIVE");
    if (sessionIndex === -1) {
      addLog(`[DB] ❌ No active parking session found for vehicle "${plate}".`, "error");
      alert(`AKSI: REJECTED\nAlasan: Kendaraan ${plate} tidak memiliki sesi parkir aktif.`);
      return;
    }

    const session = db.sessions[sessionIndex];
    
    // Real parking duration = now − entry time (no manual selector in realtime mode)
    const durationMinInput = document.getElementById('select-sim-duration');
    let durationMin;
    if (durationMinInput) {
      durationMin = parseInt(durationMinInput.value);
    } else {
      durationMin = Math.max(1, Math.round((Date.now() - new Date(session.entry_time).getTime()) / 60000));
    }
    const durationHours = Math.ceil(durationMin / 60);
    let cost = durationHours * PARKING_RATE_PER_HOUR;
    cost = Math.min(cost, PARKING_MAX_DAILY); // Cap at max daily Rp 50.000

    addLog(`[BILLING] Parking duration: ${durationMin} min (${durationHours} hours). Rate: Rp ${PARKING_RATE_PER_HOUR}/hour. Total cost: ${formatRupiah(cost)}`, "info");

    // Check user balance
    if (owner.balance < cost) {
      addLog(`[DB] ❌ Owner "${owner.name}" has insufficient balance. (Balance: ${formatRupiah(owner.balance)}, Required: ${formatRupiah(cost)}).`, "error");
      addLog(`[GATE] Action: INSUFFICIENT_BALANCE. Palang tertutup. Awaiting top up.`, "warn");
      alert(`AKSI: INSUFFICIENT_BALANCE\nAlasan: Saldo tidak cukup (${formatRupiah(owner.balance)}). Harap top-up di aplikasi.`);
      return;
    }

    // Deduct balance
    owner.balance -= cost;
    
    // Update session
    session.exit_time = new Date().toISOString();
    session.gate_out = gateId;
    session.duration_min = durationMin;
    session.total_cost = cost;
    session.status = "COMPLETED";

    // Add transaction history record
    const txId = "TX-" + Math.floor(100 + Math.random() * 900);
    db.transactions.unshift({
      id: txId,
      user_id: ownerId,
      type: "PARKING_FEE",
      amount: -cost,
      time: new Date().toISOString(),
      description: `Parkir ${plate} — ${durationMin} menit`
    });

    // Free slot in grid DB
    if (session.slot && session.floor !== undefined) {
      const defaultStatus = (session.slot === "A3" && session.floor === 0) || 
                            (session.slot === "B2" && session.floor === 1) || 
                            (session.slot === "C1" && session.floor === 2) 
                            ? "recommended" : "available";
      db.slots[session.floor][session.slot].status = defaultStatus;
      addLog(`[DB] Released Slot ${session.slot} on Floor ${session.floor}.`, "success");
    }

    saveDB();

    addLog(`[DB] ✅ Debited ${formatRupiah(cost)} from account of ${owner.name}. (New Balance: ${formatRupiah(owner.balance)})`, "success");
    addLog(`[DB] ✅ Parking Session completed: ${session.id}`, "success");
    addLog(`[GATE] Action: OPEN_GATE. Buka palang pintu keluar. Terima kasih!`, "success");

    triggerGateGateAnimation(false);

    // Refresh screens
    initApp();
    refreshAdminTables();
    renderNearbySlots();
  }
}

// Visual Gate Open/Close feedback
function triggerGateGateAnimation(isEntry) {
  const gateIndicator = document.getElementById('gate-barrier-status');
  gateIndicator.textContent = "GATE OPEN";
  gateIndicator.className = "cctv-gate-indicator";
  gateIndicator.style.borderColor = "var(--success)";
  gateIndicator.style.color = "var(--success)";
  
  // Reset back to closed after 4 seconds
  setTimeout(() => {
    gateIndicator.textContent = "GATE CLOSED";
    gateIndicator.className = "cctv-gate-indicator closed";
    gateIndicator.style.borderColor = "var(--error)";
    gateIndicator.style.color = "var(--error)";
    addLog(`[GATE] Barrier closed.`, "info");
  }, 4000);
}

function decrementAvailableSlots() {
  // Try to find an empty slot in Floor 0 and make it occupied
  for (const sKey in db.slots[0]) {
    if (db.slots[0][sKey].status === "available" || db.slots[0][sKey].status === "recommended") {
      db.slots[0][sKey].status = "occupied";
      break;
    }
  }
}

function incrementAvailableSlots() {
  // Try to find an occupied slot on Floor 0 and free it
  for (const sKey in db.slots[0]) {
    if (db.slots[0][sKey].status === "occupied") {
      db.slots[0][sKey].status = "available";
      break;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 5. SMARTPHONE APP INTERACTIVE LOGIC
// ═══════════════════════════════════════════════════════════════════════
let currentFloor = 0;
let selectedSlot = "A3";

// Time clock in Status bar
function updatePhoneClock() {
  const now = new Date();
  const timeStr = now.toTimeString().split(' ')[0].substring(0, 5);
  document.getElementById('phone-time').textContent = timeStr;
  
  // Also update CCTV system timestamps
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const seconds = String(now.getSeconds()).padStart(2, '0');
  
  const cctvTs = document.getElementById('cctv-timestamp');
  if (cctvTs) {
    cctvTs.textContent = `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  }
}
setInterval(updatePhoneClock, 1000);
updatePhoneClock();

// App Navigation Tab router
document.querySelectorAll('.phone-nav-btn').forEach(btn => {
  btn.addEventListener('click', function() {
    const target = this.getAttribute('data-target');
    
    // Switch active nav class
    document.querySelectorAll('.phone-nav-btn').forEach(b => b.classList.remove('active'));
    this.classList.add('active');
    
    // Switch screen views
    document.querySelectorAll('.phone-screen-view').forEach(s => s.classList.remove('active'));
    document.getElementById(`phone-screen-${target}`).classList.add('active');
    
    // Close any overlays
    document.getElementById('phone-modal-top-up').classList.remove('active');
    document.getElementById('phone-modal-success').classList.remove('active');

    // Custom view initializers
    if (target === "slots") {
      renderSlotsGrid();
    } else if (target === "history") {
      renderTransactionHistory();
    } else if (target === "profile") {
      renderProfileScreen();
    }
  });
});

// App Onboarding handlers
document.querySelector('.btn-skip-onboarding').addEventListener('click', skipOnboarding);
document.querySelector('.btn-next-onboarding').addEventListener('click', function() {
  // First slide done, update onboarding screen content to represent "Find closest slot map"
  const title = document.querySelector('#phone-screen-onboarding h3');
  const desc = document.querySelector('#phone-screen-onboarding p');
  const icon = document.querySelector('#phone-screen-onboarding .material-icons');
  const btn = document.querySelector('.btn-next-onboarding');

  if (btn.textContent.includes("LANJUT")) {
    icon.textContent = "local_parking";
    icon.style.color = "var(--tertiary)";
    icon.parentElement.style.backgroundColor = "var(--tertiary-fixed)";
    title.textContent = "SLOT PARKIR TERBAIK UNTUK ANDA";
    desc.textContent = "Algoritma cerdas kami secara otomatis merekomendasikan slot parkir terdekat dan ternyaman untuk menghemat waktu Anda.";
    btn.innerHTML = `MULAI SEKARANG <i class="material-icons">check</i>`;
  } else {
    skipOnboarding();
  }
});

function skipOnboarding() {
  db.onboardingCompleted = true;
  saveDB();
  document.getElementById('phone-screen-onboarding').classList.remove('active');
  document.getElementById('phone-screen-dashboard').classList.add('active');
  document.querySelectorAll('.phone-nav-btn')[0].classList.add('active');
  document.querySelector('.phone-nav-bar').style.display = "flex";
  initApp();
}

// ── App Init: Load User info, check Active Session, refresh balance ──
function initApp() {
  // Check onboarding completed
  if (!db.onboardingCompleted) {
    document.getElementById('phone-screen-onboarding').classList.add('active');
    document.getElementById('phone-screen-dashboard').classList.remove('active');
    document.querySelector('.phone-nav-bar').style.display = "none";
    return;
  } else {
    document.getElementById('phone-screen-onboarding').classList.remove('active');
    document.querySelector('.phone-nav-bar').style.display = "flex";
  }

  // Load Active user
  const user = db.users[db.activeUser];
  if (!user) return;
  
  // Set app balance text
  document.getElementById('app-balance-display').textContent = formatRupiah(user.balance);

  // Search active parking session for this user's vehicles
  const userVehicles = user.vehicles;
  const activeSession = db.sessions.find(s => userVehicles.includes(s.plate) && s.status === "ACTIVE");

  const sessionContainer = document.getElementById('app-active-session-container');
  sessionContainer.innerHTML = "";

  if (activeSession) {
    // Draw active session card (Matches flyer design)
    const card = document.createElement("div");
    card.className = "phone-session-card";
    
    // Calculate duration elapsed
    const entryTime = new Date(activeSession.entry_time);
    const elapsedMs = Date.now() - entryTime.getTime();
    
    // In our mockup, let's format it cleanly
    const elapsedSecs = Math.floor(elapsedMs / 1000);
    const elapsedHrs = Math.floor(elapsedSecs / 3600);
    const elapsedMins = Math.floor((elapsedSecs % 3600) / 60);
    const elapsedSecsRem = elapsedSecs % 60;
    
    const timeStr = `${String(elapsedHrs).padStart(2, '0')}:${String(elapsedMins).padStart(2, '0')}:${String(elapsedSecsRem).padStart(2, '0')}`;
    
    // Running fee computation (Rp 5.000 / hour)
    const runningHrs = Math.max(1, Math.ceil(elapsedMs / 3600000));
    const runningCost = Math.min(runningHrs * PARKING_RATE_PER_HOUR, PARKING_MAX_DAILY);

    const floorLabel = ["Lantai A", "Lantai B", "Lantai C"][activeSession.floor || 0];
    const slotLabel = activeSession.slot || "A3";

    card.innerHTML = `
      <div class="header">
        <div class="d-flex align-center">
          <span class="status-dot"></span>
          <span class="bold" style="font-size: 10px; font-family: var(--font-heading); color: var(--on-surface-variant)">ACTIVE SESSION • #${activeSession.id.split('-')[1] || '001'}</span>
        </div>
        <div class="timer-badge">
          <span id="session-live-timer">${timeStr}</span>
        </div>
      </div>
      <div class="body" style="padding: 12px; display: flex; flex-direction: column; gap: 8px;">
        <div class="location-group">
          <div class="bold uppercase" style="font-size: 9px; color: var(--on-surface-variant); font-family: var(--font-heading);">LOCATION</div>
          <div class="bold font-heading" style="font-size: 18px; color: var(--on-surface); line-height: 1.2;">Central Plaza ${floorLabel}</div>
        </div>
        
        <div style="display: flex; gap: 8px; align-items: center; margin: 4px 0;">
          <div style="flex: 1; border: 2.5px solid var(--on-background); padding: 4px; text-align: center; font-family: var(--font-heading); font-weight: 700; font-size: 13px; background-color: var(--tertiary-fixed); box-shadow: 2px 2px 0 var(--on-background);">
            SLOT ${slotLabel}
          </div>
          <div style="flex: 1.3; border: 2.5px solid var(--on-background); padding: 4px; text-align: center; font-family: var(--font-mono); font-weight: 700; font-size: 13px; background-color: var(--surface-container-lowest); box-shadow: 2px 2px 0 var(--on-background);">
            ${activeSession.plate}
          </div>
        </div>

        <div class="d-flex justify-between align-center" style="border-top: 1.5px dashed var(--outline-variant); padding-top: 8px; margin-top: 4px;">
          <span style="font-size: 11px; color: var(--on-surface-variant);">BIAYA BERJALAN</span>
          <span class="bold" id="session-live-cost" style="font-family: var(--font-heading); font-size: 15px; color: var(--tertiary);">${formatRupiah(runningCost)}</span>
        </div>
        
        <button class="btn-brutalist primary btn-details" id="app-btn-session-details" style="justify-content: center; padding: 6px; font-size: 11px; margin-top: 4px;">
          VIEW SLOT MAP
        </button>
      </div>
    `;
    sessionContainer.appendChild(card);
    
    // Navigate to Slots tab when clicked
    document.getElementById('app-btn-session-details').addEventListener('click', () => {
      document.querySelectorAll('.phone-nav-btn')[1].click();
    });

  } else {

    // Draw "TIDAK ADA SESI AKTIF" card
    const card = document.createElement("div");
    card.className = "phone-no-session";
    card.innerHTML = `
      <i class="material-icons">local_parking</i>
      <div class="bold" style="font-size: 13px; font-family: var(--font-heading);">TIDAK ADA SESI AKTIF</div>
      <p style="font-size: 11px; margin-top: 4px;">Gerbang masuk otomatis akan memicu sesi saat mendeteksi kendaraan terdaftar Anda.</p>
    `;
    sessionContainer.appendChild(card);
  }
}

// Real-time ticking updates for active sessions
setInterval(() => {
  const timerLabel = document.getElementById('session-live-timer');
  const costLabel = document.getElementById('session-live-cost');
  
  if (timerLabel && costLabel) {
    const user = db.users[db.activeUser];
    const activeSession = db.sessions.find(s => user.vehicles.includes(s.plate) && s.status === "ACTIVE");
    
    if (activeSession) {
      const entryTime = new Date(activeSession.entry_time);
      const elapsedMs = Date.now() - entryTime.getTime();
      const elapsedSecs = Math.floor(elapsedMs / 1000);
      const elapsedHrs = Math.floor(elapsedSecs / 3600);
      const elapsedMins = Math.floor((elapsedSecs % 3600) / 60);
      const elapsedSecsRem = elapsedSecs % 60;
      
      timerLabel.textContent = `${String(elapsedHrs).padStart(2, '0')}:${String(elapsedMins).padStart(2, '0')}:${String(elapsedSecsRem).padStart(2, '0')}`;
      
      const runningHrs = Math.max(1, Math.ceil(elapsedMs / 3600000));
      const runningCost = Math.min(runningHrs * PARKING_RATE_PER_HOUR, PARKING_MAX_DAILY);
      costLabel.textContent = formatRupiah(runningCost);
    }
  }
}, 1000);

// ── App Wallet Top-Up flows ──
document.getElementById('app-btn-top-up').addEventListener('click', function() {
  document.getElementById('phone-modal-top-up').classList.add('active');
});

document.getElementById('btn-close-topup').addEventListener('click', function() {
  document.getElementById('phone-modal-top-up').classList.remove('active');
});

// Top-up amount options click handler
document.querySelectorAll('.top-up-option').forEach(opt => {
  opt.addEventListener('click', function() {
    document.querySelectorAll('.top-up-option').forEach(o => o.classList.remove('active'));
    this.classList.add('active');
    document.getElementById('input-custom-topup').value = ""; // clear custom input
  });
});

document.getElementById('input-custom-topup').addEventListener('input', function() {
  if (this.value) {
    document.querySelectorAll('.top-up-option').forEach(o => o.classList.remove('remove'));
    // Deselect options
    document.querySelectorAll('.top-up-option').forEach(o => o.classList.remove('active'));
  }
});

// Submit Top Up
document.getElementById('btn-submit-topup').addEventListener('click', function() {
  const user = db.users[db.activeUser];
  
  // Determine amount
  let amount = 0;
  const customVal = document.getElementById('input-custom-topup').value;
  if (customVal) {
    amount = parseFloat(customVal);
  } else {
    const activeOpt = document.querySelector('.top-up-option.active');
    if (activeOpt) {
      amount = parseFloat(activeOpt.getAttribute('data-amount'));
    }
  }

  if (isNaN(amount) || amount <= 0) {
    alert("Harap pilih atau masukkan nominal top up yang valid!");
    return;
  }

  const method = document.getElementById('select-topup-method').value;

  // Process transaction
  user.balance += amount;
  
  const txId = "TX-" + Math.floor(100 + Math.random() * 900);
  const now = new Date();
  db.transactions.unshift({
    id: txId,
    user_id: user.id,
    type: "TOPUP",
    amount: amount,
    time: now.toISOString(),
    description: `Top Up via ${method}`
  });

  saveDB();
  addLog(`[API] Wallet Top Up successful: Account ${user.name} (+${formatRupiah(amount)} via ${method})`, "success");

  // Show success modal receipt screen
  document.getElementById('success-amount').textContent = formatRupiah(amount);
  document.getElementById('success-method').textContent = method.toUpperCase();
  
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  const timeStr = `${now.getDate()} ${months[now.getMonth()]} ${now.getFullYear()}, ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  document.getElementById('success-time').textContent = timeStr;
  document.getElementById('success-new-balance').textContent = formatRupiah(user.balance);

  document.getElementById('phone-modal-top-up').classList.remove('active');
  document.getElementById('phone-modal-success').classList.add('active');
});

document.getElementById('btn-success-close').addEventListener('click', function() {
  document.getElementById('phone-modal-success').classList.remove('active');
  initApp();
  refreshAdminTables();
});

// ── App Slots Map View flows ──
document.querySelectorAll('.phone-floor-tab').forEach(tab => {
  tab.addEventListener('click', function() {
    document.querySelectorAll('.phone-floor-tab').forEach(t => t.classList.remove('active'));
    this.classList.add('active');
    
    currentFloor = parseInt(this.getAttribute('data-floor'));
    renderSlotsGrid();
  });
});

function renderSlotsGrid() {
  const grid = document.getElementById('app-slots-grid');
  grid.innerHTML = "";
  
  const floorSlots = db.slots[currentFloor];
  
  // Available slots counting for header
  let availCount = 0;
  for (const sk in floorSlots) {
    if (floorSlots[sk].status !== "occupied") {
      availCount++;
    }
  }
  document.getElementById('app-available-slots-label').textContent = availCount;

  // 5-column layout: Left slots (A1, A2; B1, B2; C1, C2), Middle Road, Right slots (A3, A4; B3, EXIT_PATH; C3, EXIT_EMPTY)
  const gridMatrix = [
    ["A1", "A2", "ROAD", "A3", "A4"],
    ["B1", "B2", "ROAD", "B3", "EXIT_PATH"],
    ["C1", "C2", "ROAD", "C3", "EXIT_EMPTY"]
  ];

  gridMatrix.forEach(row => {
    row.forEach(cell => {
      if (cell === "EXIT_EMPTY") return;
      
      const cellEl = document.createElement("div");
      
      if (cell === "ROAD") {
        cellEl.className = "road-middle";
      } else if (cell === "EXIT_PATH") {
        cellEl.className = "exit-path-span";
        cellEl.textContent = "JALUR KELUAR";
      } else {
        const slotData = floorSlots[cell];
        cellEl.className = "phone-slot-cell";
        cellEl.textContent = cell;

        if (slotData.status === "occupied") {
          cellEl.classList.add("occupied");
        } else if (slotData.status === "recommended") {
          cellEl.classList.add("recommended");
          cellEl.innerHTML += `<span class="recommended-badge">TERDEKAT</span>`;
        }

        if (cell === selectedSlot) {
          cellEl.classList.add("selected");
        }

        // Click slot handler
        cellEl.addEventListener('click', function() {
          if (slotData.status === "occupied") {
            alert(`Slot ${cell} tidak tersedia (sedang ditempati).`);
            return;
          }
          selectedSlot = cell;
          document.querySelectorAll('.phone-slot-cell').forEach(c => c.classList.remove('selected'));
          this.classList.add('selected');
          updateSlotDetailsSheet(cell);
        });
      }
      grid.appendChild(cellEl);
    });
  });

  updateSlotDetailsSheet(selectedSlot);
}

function updateSlotDetailsSheet(slotName) {
  const floorName = ["Lantai A", "Lantai B", "Lantai C"][currentFloor];
  const dist = currentFloor === 0 ? 12 : currentFloor === 1 ? 28 : 45;
  
  document.getElementById('detail-slot-name').textContent = `SLOT ${slotName}`;
  document.getElementById('detail-slot-desc').textContent = `${floorName} • ${dist}m dari Gate A`;
}

// Claim selected slot
document.getElementById('app-btn-claim-slot').addEventListener('click', function() {
  const user = db.users[db.activeUser];
  
  // Set slot occupied in DB
  const slotData = db.slots[currentFloor][selectedSlot];
  if (slotData.status === "occupied") {
    alert("Slot sudah diisi!");
    return;
  }

  // Find active session for user
  const activeSession = db.sessions.find(s => user.vehicles.includes(s.plate) && s.status === "ACTIVE");

  if (activeSession) {
    // Free previously occupied slot of this session if exists
    if (activeSession.slot && activeSession.floor !== undefined) {
      const prevDefault = (activeSession.slot === "A3" && activeSession.floor === 0) || 
                          (activeSession.slot === "B2" && activeSession.floor === 1) || 
                          (activeSession.slot === "C1" && activeSession.floor === 2) 
                          ? "recommended" : "available";
      db.slots[activeSession.floor][activeSession.slot].status = prevDefault;
    }
    
    // Save to active session
    activeSession.slot = selectedSlot;
    activeSession.floor = currentFloor;
    addLog(`[API] Associated active session ${activeSession.id} with Slot ${selectedSlot} at Floor ${currentFloor}.`, "success");
  } else {
    // Pre-reserve for next entry gate scan
    user.claimed_slot = { slot: selectedSlot, floor: currentFloor };
    addLog(`[API] Pre-reserved Slot ${selectedSlot} at Floor ${currentFloor} for user "${user.name}".`, "info");
  }

  slotData.status = "occupied";
  saveDB();

  alert(`RESERVASI BERHASIL!\nAnda telah memesan slot ${selectedSlot} di Lantai ${["A", "B", "C"][currentFloor]}.\nSilakan parkir.`);

  renderSlotsGrid();
  initApp(); // Refresh dashboard card instantly!
  refreshAdminTables();
  renderNearbySlots();
});

// ── App Transaction History flows ──
function renderTransactionHistory() {
  const list = document.getElementById('app-history-list');
  list.innerHTML = "";

  const userTxs = db.transactions.filter(t => t.user_id === db.activeUser);
  
  if (userTxs.length === 0) {
    list.innerHTML = `<div style="text-align:center; padding: 20px; color: var(--on-surface-variant)">Belum ada riwayat transaksi.</div>`;
    return;
  }

  userTxs.forEach(tx => {
    const item = document.createElement("div");
    item.className = "phone-history-item";
    
    const isNegative = tx.amount < 0;
    const amountClass = isNegative ? "negative" : "positive";
    const amountPrefix = isNegative ? "" : "+";
    
    const date = new Date(tx.time);
    const dateStr = date.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });

    item.innerHTML = `
      <div class="row1">
        <span>${tx.description.toUpperCase()}</span>
        <span class="amount ${amountClass}">${amountPrefix}${formatRupiah(tx.amount)}</span>
      </div>
      <div class="row2">
        <span>ID: ${tx.id}</span>
        <span>${dateStr}</span>
      </div>
    `;
    list.appendChild(item);
  });
}

// ── App Profile & User management flows ──
function renderProfileScreen() {
  const user = db.users[db.activeUser];
  if (!user) return;

  // Header avatar text
  document.querySelector('.phone-profile-avatar').textContent = user.name.split(' ').map(n => n[0]).join('').toUpperCase();
  document.getElementById('profile-name').textContent = user.name;
  document.getElementById('profile-email').textContent = user.email;

  // Load vehicles list
  const container = document.getElementById('profile-vehicles-container');
  container.innerHTML = "";

  user.vehicles.forEach(plate => {
    const item = document.createElement("div");
    item.className = "phone-vehicle-item";
    item.innerHTML = `
      <span class="plate">${plate}</span>
      <span class="status-pill active">Terdaftar</span>
    `;
    container.appendChild(item);
  });
}

// Register new vehicle plate
document.getElementById('btn-add-vehicle').addEventListener('click', function() {
  const user = db.users[db.activeUser];
  const input = document.getElementById('input-new-plate');
  const rawPlate = input.value.trim().toUpperCase();

  if (!rawPlate) {
    alert("Masukkan plat nomor!");
    return;
  }

  // Basic regex validation for Indonesian plates
  const plateRegex = /^[A-Z]{1,2}\s\d{1,4}\s[A-Z]{1,3}$/;
  if (!plateRegex.test(rawPlate)) {
    if (!confirm("Plat nomor tidak standar (cth: B 1234 ABC). Apakah Anda yakin mendaftarkan plat ini?")) {
      return;
    }
  }

  // Check if plate already registered anywhere
  let exists = false;
  for (const uid in db.users) {
    if (db.users[uid].vehicles.includes(rawPlate)) {
      exists = true;
      break;
    }
  }

  if (exists) {
    alert("Plat nomor kendaraan ini sudah didaftarkan pada akun lain!");
    return;
  }

  user.vehicles.push(rawPlate);
  saveDB();
  input.value = "";
  
  addLog(`[API] User "${user.name}" registered vehicle: "${rawPlate}"`, "success");
  
  renderProfileScreen();
  refreshAdminTables();
  
  // Update presets options on Gate camera controls
  updateCctvPresetControls(rawPlate, user.name);
});

function updateCctvPresetControls(newPlate, ownerName) {
  // Dynamically inject custom button for testing
  const presetsContainer = document.querySelector('.car-presets');
  if (!presetsContainer) return;
  
  // Check if button for this plate already exists
  const existingBtn = presetsContainer.querySelector(`[data-plate="${newPlate}"]`);
  if (!existingBtn) {
    const newBtn = document.createElement('button');
    newBtn.className = "car-preset-btn";
    newBtn.setAttribute('data-plate', newPlate);
    newBtn.setAttribute('data-registered', 'true');
    newBtn.setAttribute('data-owner', ownerName);
    newBtn.innerHTML = `
      <span class="plate">${newPlate}</span>
      <span style="opacity:0.7">Mobil ${ownerName.split(' ')[0]} (Baru)</span>
    `;
    
    // Insert before custom plate option
    const customBtn = presetsContainer.querySelector('[data-plate="CUSTOM"]');
    presetsContainer.insertBefore(newBtn, customBtn);

    // Bind event
    newBtn.addEventListener('click', function() {
      document.querySelectorAll('.car-preset-btn').forEach(b => b.classList.remove('active'));
      this.classList.add('active');
      selectedPresetPlate = newPlate;
      document.getElementById('custom-plate-group').style.display = "none";
      
      // Update SVG Car drawing
      if (!CAR_SVGS[newPlate]) {
        CAR_SVGS[newPlate] = CAR_SVGS["B 1234 ABC"].replace("B 1234 ABC", newPlate);
      }
      updateCCTVImage(newPlate);
      document.getElementById('plate-ocr-result').textContent = newPlate;
    });
  }
}

// Log out app simulator -> switch active user
document.getElementById('btn-logout-app').addEventListener('click', function() {
  const nextUser = db.activeUser === 1 ? 2 : 1;
  db.activeUser = nextUser;
  saveDB();
  addLog(`[SYSTEM] Logged in to app as ${db.users[nextUser].name}`, "info");
  
  // Reload App layout
  initApp();
  
  // Update profile screen visual
  const profileTab = document.querySelector('.phone-nav-btn[data-target="profile"]');
  if (profileTab && profileTab.classList.contains('active')) {
    renderProfileScreen();
  }
  
  // Show home tab view
  document.querySelectorAll('.phone-nav-btn')[0].click();
});

// ═══════════════════════════════════════════════════════════════════════
// 6. ADMIN DASHBOARD & STATISTICS LOGIC
// ═══════════════════════════════════════════════════════════════════════

// Admin navigation tabs
document.querySelectorAll('.admin-tab').forEach(tab => {
  tab.addEventListener('click', function() {
    document.querySelectorAll('.admin-tab').forEach(t => t.classList.remove('active'));
    this.classList.add('active');
    
    const viewName = this.getAttribute('data-tab');
    document.getElementById('admin-tab-sessions').style.display = viewName === "sessions" ? "block" : "none";
    document.getElementById('admin-tab-vehicles').style.display = viewName === "vehicles" ? "block" : "none";
    document.getElementById('admin-tab-rates').style.display = viewName === "rates" ? "block" : "none";
  });
});

function refreshAdminTables() {
  // Update stat widgets
  let totalCap = 30;
  let activeCount = db.sessions.filter(s => s.status === "ACTIVE").length;
  
  // Calculate available slots count across all floors
  let availCount = 0;
  for (let f = 0; f < 3; f++) {
    for (const sk in db.slots[f]) {
      if (db.slots[f][sk].status !== "occupied") {
        availCount++;
      }
    }
  }

  // Calculate revenue total
  let totalRevenue = 0;
  db.sessions.forEach(s => {
    if (s.total_cost) totalRevenue += s.total_cost;
  });

  document.getElementById('stat-total-slots').textContent = totalCap;
  document.getElementById('stat-avail-slots').textContent = availCount;
  document.getElementById('stat-active-sessions').textContent = activeCount;
  document.getElementById('stat-revenue').textContent = formatRupiah(totalRevenue);

  // 1. Refresh Active Sessions Table
  const activeSessionsBody = document.getElementById('table-active-sessions-body');
  activeSessionsBody.innerHTML = "";

  const activeList = db.sessions.filter(s => s.status === "ACTIVE");
  if (activeList.length === 0) {
    activeSessionsBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--on-surface-variant);">Tidak ada sesi parkir yang aktif saat ini.</td></tr>`;
  } else {
    activeList.forEach(s => {
      const owner = db.users[s.user_id];
      const entryTime = new Date(s.entry_time);
      const elapsedMs = Date.now() - entryTime.getTime();
      const runningHrs = Math.max(1, Math.ceil(elapsedMs / 3600000));
      const runningCost = Math.min(runningHrs * PARKING_RATE_PER_HOUR, PARKING_MAX_DAILY);
      
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td class="bold mono">${s.id}</td>
        <td class="mono">${s.plate}</td>
        <td>${owner ? owner.name : "Kustom"}</td>
        <td class="mono">${s.gate_in}</td>
        <td>${entryTime.toLocaleTimeString('id-ID')}</td>
        <td class="bold text-right" style="color:var(--tertiary);">${formatRupiah(runningCost)}</td>
      `;
      activeSessionsBody.appendChild(tr);
    });
  }

  // 2. Refresh Registered Vehicles Table
  const vehiclesBody = document.getElementById('table-registered-vehicles-body');
  vehiclesBody.innerHTML = "";

  for (const uid in db.users) {
    const user = db.users[uid];
    user.vehicles.forEach(plate => {
      const tr = document.createElement("tr");
      
      // Check if vehicle is currently inside parking area
      const activeSession = db.sessions.find(s => s.plate === plate && s.status === "ACTIVE");
      const statusLabel = activeSession 
        ? `<span class="status-pill active">Di Dalam (Sesi Aktif)</span>` 
        : `<span class="status-pill completed">Di Luar</span>`;

      tr.innerHTML = `
        <td class="bold mono">${plate}</td>
        <td>${user.name}</td>
        <td>${user.email}</td>
        <td class="mono bold">${formatRupiah(user.balance)}</td>
        <td>${statusLabel}</td>
      `;
      vehiclesBody.appendChild(tr);
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 7. PRESENTATION / FLYER METRICS INTEGRATION
// ═══════════════════════════════════════════════════════════════════════
// Real-time animation simulator for nearby locations progress
function renderNearbySlots() {
  const availCount = db.sessions.filter(s => s.status === "ACTIVE").length;
  // Let's modify availability for ITS Campus location based on slots
  // We can write seed info to UI or dynamically compute
}

// Tick admin active sessions timer (for active cost live updating)
setInterval(refreshAdminTables, 5000);

// ═══════════════════════════════════════════════════════════════════════
// 8. STARTUP INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════
initApp();
refreshAdminTables();
renderNearbySlots();
addLog("[SYSTEM] IoT realtime dashboard initialized.", "success");
addLog(`[SYSTEM] App user aktif: ${db.users[db.activeUser].name}`, "info");

// ═══════════════════════════════════════════════════════════════════════
// 9. REALTIME DEVICE EVENT BRIDGE (ESP32 sensor → /device/events → dashboard)
// ═══════════════════════════════════════════════════════════════════════
function setBadgeBackend(online) {
  const b = document.getElementById('bg-backend');
  if (!b) return;
  b.textContent = online ? '● ONLINE' : '● OFFLINE';
  b.style.backgroundColor = online ? 'var(--primary-fixed)' : 'var(--error-container)';
  b.style.color = online ? 'var(--on-background)' : 'var(--on-error-container)';
}

function setSensorState(text, kind) {
  const s = document.getElementById('sensor-state');
  if (!s) return;
  s.textContent = text;
  s.style.backgroundColor = kind === 'active' ? 'var(--success)' : kind === 'deny' ? 'var(--error-container)' : 'var(--tertiary-fixed)';
  s.style.color = kind === 'active' ? '#00210b' : 'var(--on-background)';
}

async function pollBackendHealth() {
  try {
    const r = await fetch(BASE + '/health', { signal: AbortSignal.timeout(2500) });
    const h = await r.json();
    backendOnline = !!h.status;
    setBadgeBackend(true);
  } catch {
    backendOnline = false;
    setBadgeBackend(false);
  }
}

// Render one real gate event: photo + plate + status, then run the business pipeline.
function handleDeviceEvent(ev) {
  const gateId = ev.gate_id || (ev.gate_type === 'exit' ? 'GATE-A-OUT' : 'GATE-A-IN');
  const plate = (ev.plate || '').trim();

  // Real captured photo from the ESP32 (served via /captures)
  if (ev.thumb) {
    const img = document.getElementById('cctv-car-img');
    if (img) { img.src = (/^https?:/.test(ev.thumb) ? ev.thumb : BASE + ev.thumb); img.style.display = 'block'; }
    // If a live feed (webcam or ESP32-CAM stream) is active, keep showing it instead.
    if (isLiveCameraOn || isEsp32CamOn) {
      img.style.display = 'none';
    }
  }

  // Draw bounding boxes if bbox data is available from the event
  if (ev.bbox && ev.image_width && ev.image_height) {
    drawBoundingBoxes({ results: [{ bbox: ev.bbox, plate_text: plate, plate_confidence: ev.plate_confidence, access: { decision: ev.decision } }] }, ev.image_width, ev.image_height);
    updateDetectBar({ results: [{ plate_text: plate, plate_confidence: ev.plate_confidence, ocr_confidence: ev.ocr_confidence, access: { decision: ev.decision } }] });
  }

  const set = (id, v) => { const e = document.getElementById(id); if (e) e.textContent = v; };
  set('plate-ocr-result', plate || '— TAK TERBACA —');
  set('cam-gate-label', gateId);
  set('last-gate', gateId + ' (' + (ev.gate_type || '?') + ')');
  set('last-sensor', ev.sensor || '—');
  set('last-decision', ev.decision || '—');
  set('last-command', ev.command || '—');
  set('last-time', ev.ts ? new Date(ev.ts).toLocaleTimeString('id-ID') : '—');
  setSensorState('TERDETEKSI', 'active');
  // In continuous ESP32 live mode the box is refreshed every scan, so don't auto-clear it.
  setTimeout(() => { setSensorState('MENUNGGU…', 'idle'); if (!isEsp32CamOn) clearDetectionOverlay(); }, 4000);

  const conf = ev.plate_confidence ? (ev.plate_confidence * 100).toFixed(1) + '%' : '–';
  addLog(`[SENSOR] ${ev.sensor || 'trigger'} @ ${gateId} → capture diterima dari ${ev.device_id || 'device'}`, 'info');
  addLog(`[OCR] Plat: "${plate || '-'}" (conf ${conf}) · keputusan backend: ${ev.decision || '-'} / ${ev.command || '-'}`, plate ? 'success' : 'warn');

  if (!plate) {
    addLog('[GATE] Plat tidak terbaca — MANUAL_REQUIRED.', 'warn');
    return;
  }
  // Drive the Parkir Boss pipeline (sesi/billing/saldo/app/admin) with the REAL plate.
  // Deduped so continuous live auto-scan won't re-bill the same vehicle every tick.
  maybeProcessGate(plate, gateId);
}

async function pollDeviceEvents() {
  if (!backendOnline) return;
  try {
    const r = await fetch(BASE + `/device/events?since=${lastEventId}`, { signal: AbortSignal.timeout(2500) });
    if (!r.ok) return;
    const data = await r.json();
    (data.events || []).forEach(ev => { handleDeviceEvent(ev); lastEventId = Math.max(lastEventId, ev.id || 0); });
  } catch { /* retry next tick */ }
}

async function initRealtime() {
  const baseInput = document.getElementById('sp-base-input');
  if (baseInput) {
    baseInput.value = BASE;
    const saveBtn = document.getElementById('btn-save-base');
    if (saveBtn) saveBtn.addEventListener('click', async () => {
      BASE = baseInput.value.replace(/\/+$/, '');
      localStorage.setItem('sp_base', BASE);
      addLog('[SYSTEM] Backend API di-set ke ' + BASE, 'info');
      await pollBackendHealth();
    });
  }
  await pollBackendHealth();
  // Baseline: skip historical events so old triggers are not replayed into new sessions.
  try {
    const r = await fetch(BASE + '/device/events?since=0', { signal: AbortSignal.timeout(3000) });
    const data = await r.json();
    lastEventId = data.last_id || 0;
    addLog(`[SYSTEM] Realtime aktif (BASE ${BASE}). Menunggu trigger sensor… (${(data.events || []).length} event lama diabaikan)`, 'success');
  } catch {
    addLog('[SYSTEM] ⚠️ Backend belum terjangkau. Isi "Backend API" lalu klik SET.', 'warn');
  }
  // Discover ESP32-CAM cameras that announced themselves via POST /device/register.
  const cams = await discoverEsp32Cameras();
  const gates = Object.keys(cams);
  if (gates.length > 0) {
    addLog(`[ESP32] ${gates.length} kamera ESP32-CAM ter-registrasi: ${gates.join(', ')}. Klik "ESP32-CAM" untuk live.`, 'success');
  } else {
    addLog('[ESP32] Belum ada ESP32-CAM ter-registrasi. Nyalakan board-nya, atau klik "ESP32-CAM" untuk isi URL manual.', 'info');
  }

  setInterval(pollBackendHealth, 4000);
  setInterval(pollDeviceEvents, 1500);
  setInterval(discoverEsp32Cameras, 10000);  // keep camera registry fresh
}

initRealtime();
