/*
  SmartPark — ESP32-CAM Entry Gate Controller (HYBRID: stream + trigger)
  ======================================================================

  Hardware: ESP32-CAM AI-Thinker  •  Sensor kamera: OV3660 (atau OV2640)
  Role    : Kamera + controller untuk gate MASUK

  Komponen:
  • OV3660/OV2640 Camera (built-in) → live stream + capture foto kendaraan
  • Flash LED (GPIO 4)              → pencahayaan plat saat capture
  • HC-SR04 Ultrasonic              → deteksi kendaraan mendekat
  • IR Obstacle Sensor              → deteksi kendaraan sudah lewat → auto-close
  • Servo SG90                      → palang gate barrier
  • LED Onboard (GPIO 33)           → indikator status

  Mode HYBRID (3 jalur sekaligus):
  1. LIVE STREAM  — http://<ip>:81/stream (MJPEG) tampil di dashboard,
                    http://<ip>/capture (1 JPEG) ditarik backend untuk ANPR live.
  2. AUTO-REGISTER— saat boot kirim POST /device/register supaya dashboard
                    menemukan kamera ini otomatis.
  3. GATE TRIGGER — HC-SR04 deteksi kendaraan → capture → POST /device/process-image
                    → jika OPEN_GATE: servo buka → IR sensor → servo tutup.

  Libraries:
  - esp_camera.h / esp_http_server.h  (ESP32 board package)
  - WiFi.h / WiFiClient.h             (built-in)
  - ESP32Servo                        (Kevin Harrington)
  - ArduinoJson                       (Benoit Blanchon, v7)

  Board Settings di Arduino IDE:
  - Board: AI Thinker ESP32-CAM
  - Partition Scheme: Huge APP (3MB No OTA / 1MB SPIFFS)
  - PSRAM: Enabled
*/

#include "esp_camera.h"
#include "esp_http_server.h"
#include <WiFi.h>
#include <WiFiClient.h>
#include <ESP32Servo.h>
#include <ArduinoJson.h>

// ─────────────────── CONFIGURATION ───────────────────

// WiFi credentials — ganti dengan WiFi kamu (WAJIB 2.4GHz)
const char* WIFI_SSID     = "xzzx";
const char* WIFI_PASSWORD = "12345678";

// SmartPark API — IP laptop/Raspberry Pi pada WiFi yang sama (TANPA "http://").
// Cari IP laptop: macOS `ipconfig getifaddr en0` · Windows `ipconfig` · Linux `hostname -I`.
// Jalankan backend dengan: uvicorn api.main:app --host 0.0.0.0 --port 8000
const char* API_HOST = "10.209.121.249";
const int   API_PORT = 8000;
const char* API_PATH = "/device/process-image";

// Device identity (entry gate)
const char* DEVICE_ID = "esp32cam-gate-entry-1";
const char* GATE_ID   = "GATE-A-IN";
const char* GATE_TYPE = "entry";

// API options
const char* API_CONFIDENCE   = "0.25";
const char* API_NEAREST_ONLY = "true";
const bool  USE_FLASH_LED     = false;

// Streaming / capture HTTP servers on the ESP32-CAM
const int   CONTROL_PORT = 80;   // /  /capture  /status
const int   STREAM_PORT  = 81;   // /stream (MJPEG)
const bool  ENABLE_STREAM_SERVER = true;
const unsigned long REGISTER_INTERVAL_MS = 30000;  // re-announce to backend

// ─────────────────── PIN DEFINITIONS ───────────────────
// ESP32-CAM AI-Thinker — GPIO terbatas, hati-hati pin assignment!

const int PIN_FLASH_LED     = 4;   // Built-in flash LED
const int PIN_HC_TRIG       = 14;  // HC-SR04 Trigger
const int PIN_HC_ECHO       = 15;  // HC-SR04 Echo
const int PIN_SERVO         = 13;  // Servo SG90 PWM
const int PIN_IR_OBSTACLE   = 2;   // IR Obstacle sensor (auto-close)
const int PIN_LED_ONBOARD   = 33;  // Onboard red LED (active LOW)

// ─────────────────── CAMERA PIN CONFIG (AI-Thinker) ───────────────────
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// ─────────────────── THRESHOLDS ───────────────────
const float  TRIGGER_DISTANCE_CM  = 30.0;   // Trigger saat objek < 30cm
const unsigned long COOLDOWN_MS   = 10000;  // Min waktu antar trigger
const int    GATE_OPEN_DEGREES    = 90;     // Sudut servo saat buka
const int    GATE_CLOSED_DEGREES  = 0;      // Sudut servo saat tutup
const unsigned long GATE_TIMEOUT_MS = 30000; // Fallback timeout jika IR sensor gagal
const unsigned long IR_DEBOUNCE_MS  = 500;   // Debounce IR sensor
const unsigned long API_TIMEOUT_MS   = 30000; // Timeout upload + response API

// ─────────────────── GLOBAL STATE ───────────────────
Servo gateServo;

unsigned long lastTriggerAt = 0;
bool gateIsOpen = false;
unsigned long gateOpenedAt = 0;
bool vehiclePassingIR = false;
unsigned long irFirstDetectAt = 0;
unsigned long lastRegisterAt = 0;

httpd_handle_t stream_httpd  = NULL;
httpd_handle_t control_httpd = NULL;

// ═══════════════════ SETUP ═══════════════════

void setup() {
  Serial.begin(115200);
  Serial.println("\n========================================");
  Serial.println("  SmartPark — Entry Gate Controller");
  Serial.println("  ESP32-CAM AI-Thinker (HYBRID stream)");
  Serial.println("========================================\n");

  pinMode(PIN_FLASH_LED, OUTPUT);
  pinMode(PIN_HC_TRIG, OUTPUT);
  pinMode(PIN_HC_ECHO, INPUT);
  pinMode(PIN_IR_OBSTACLE, INPUT_PULLUP);
  pinMode(PIN_LED_ONBOARD, OUTPUT);

  digitalWrite(PIN_FLASH_LED, LOW);
  digitalWrite(PIN_LED_ONBOARD, HIGH);  // OFF (active LOW)

  if (!initCamera()) {
    Serial.println("FATAL: Camera init failed!");
    blinkError(10);
    ESP.restart();
  }

  gateServo.attach(PIN_SERVO);
  gateServo.write(GATE_CLOSED_DEGREES);
  Serial.println("Gate servo initialized (closed)");

  connectWiFi();
  checkApiHealth();

  if (ENABLE_STREAM_SERVER) {
    startCameraServers();
    Serial.printf("Live stream : http://%s:%d/stream\n", WiFi.localIP().toString().c_str(), STREAM_PORT);
    Serial.printf("Snapshot    : http://%s:%d/capture\n", WiFi.localIP().toString().c_str(), CONTROL_PORT);
  }
  registerWithBackend();

  Serial.println("\nWaiting for vehicles...\n");
  blinkOK();
}

// ═══════════════════ MAIN LOOP ═══════════════════

void loop() {
  if (gateIsOpen) {
    handleGateAutoClose();
  }

  float distanceCm = readDistanceCm();
  if (distanceCm > 0 && distanceCm <= 50) {
    static unsigned long lastPrint = 0;
    if (millis() - lastPrint > 1000) {
      Serial.printf("Distance: %.1f cm\n", distanceCm);
      lastPrint = millis();
    }
  }

  bool vehicleDetected = distanceCm > 0 && distanceCm <= TRIGGER_DISTANCE_CM;
  bool cooldownDone    = millis() - lastTriggerAt >= COOLDOWN_MS;
  bool notAlreadyOpen  = !gateIsOpen;

  if (vehicleDetected && cooldownDone && notAlreadyOpen) {
    Serial.println("\n>>> Vehicle detected! Processing...");
    processVehicle("ultrasonic");
  }

  // Periodically re-announce to the backend (covers backend restarts / DHCP changes).
  if (millis() - lastRegisterAt >= REGISTER_INTERVAL_MS) {
    registerWithBackend();
  }

  handleSerialCommands();
  delay(200);
}

// ═══════════════════ CAMERA ═══════════════════

bool initCamera() {
  Serial.println("Initializing camera...");

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = Y2_GPIO_NUM;
  config.pin_d1       = Y3_GPIO_NUM;
  config.pin_d2       = Y4_GPIO_NUM;
  config.pin_d3       = Y5_GPIO_NUM;
  config.pin_d4       = Y6_GPIO_NUM;
  config.pin_d5       = Y7_GPIO_NUM;
  config.pin_d6       = Y8_GPIO_NUM;
  config.pin_d7       = Y9_GPIO_NUM;
  config.pin_xclk     = XCLK_GPIO_NUM;
  config.pin_pclk     = PCLK_GPIO_NUM;
  config.pin_vsync    = VSYNC_GPIO_NUM;
  config.pin_href     = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn     = PWDN_GPIO_NUM;
  config.pin_reset    = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.grab_mode    = CAMERA_GRAB_LATEST;   // newest frame for stream + capture

  // HYBRID needs 2 frame buffers (stream + capture/gate share the camera).
  if (psramFound()) {
    config.frame_size   = FRAMESIZE_UXGA;     // 800x600 — balance stream vs plate detail
    config.jpeg_quality = 8;                 // 0-63, lower = better quality
    config.fb_count     = 2;
    config.fb_location  = CAMERA_FB_IN_PSRAM;
    Serial.println("PSRAM found — SVGA 800x600, fb_count=2 (hybrid)");
  } else {
    config.frame_size   = FRAMESIZE_VGA;      // 640x480
    config.jpeg_quality = 15;
    config.fb_count     = 1;
    config.fb_location  = CAMERA_FB_IN_DRAM;
    Serial.println("No PSRAM — VGA 640x480, fb_count=1 (stream may stutter)");
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    return false;
  }

  // Tune sensor for license-plate capture, with OV3660-specific fixes.
  sensor_t* s = esp_camera_sensor_get();
  if (s) {
    if (s->id.PID == OV3660_PID) {
      Serial.println("Sensor: OV3660 detected");
      s->set_vflip(s, 1);          // OV3660 is mounted upside-down on most boards
      s->set_brightness(s, 1);
      s->set_saturation(s, -2);
    } else {
      Serial.printf("Sensor PID: 0x%x (OV2640 or other)\n", s->id.PID);
      s->set_vflip(s, 1);
    }
    s->set_framesize(s, psramFound() ? FRAMESIZE_SVGA : FRAMESIZE_VGA);
    s->set_contrast(s, 1);
    s->set_sharpness(s, 1);
    s->set_whitebal(s, 1);
    s->set_awb_gain(s, 1);
    s->set_exposure_ctrl(s, 1);
    s->set_gain_ctrl(s, 1);
    s->set_vflip(s, 1);
  }

  Serial.println("Camera OK — ready for stream + capture");
  return true;
}

camera_fb_t* captureWithFlash() {
  if (USE_FLASH_LED) {
    Serial.println("Flash LED ON — capturing image...");
    digitalWrite(PIN_FLASH_LED, HIGH);
    delay(180);
  } else {
    Serial.println("Capturing image...");
    delay(80);
  }

  // Discard first frame (may have stale exposure), then grab the real one.
  camera_fb_t* fb = esp_camera_fb_get();
  if (fb) esp_camera_fb_return(fb);
  fb = esp_camera_fb_get();

  digitalWrite(PIN_FLASH_LED, LOW);
  if (USE_FLASH_LED) Serial.println("Flash LED OFF");
  return fb;
}

// ═══════════════════ MJPEG STREAM + CAPTURE SERVER ═══════════════════

static esp_err_t stream_handler(httpd_req_t* req) {
  static const char* BOUNDARY = "\r\n--frame\r\n";
  static const char* PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";
  char part_buf[64];

  esp_err_t res = httpd_resp_set_type(req, "multipart/x-mixed-replace;boundary=frame");
  if (res != ESP_OK) return res;
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");

  while (true) {
    camera_fb_t* fb = esp_camera_fb_get();
    if (!fb) { res = ESP_FAIL; break; }

    res = httpd_resp_send_chunk(req, BOUNDARY, strlen(BOUNDARY));
    if (res == ESP_OK) {
      size_t hlen = snprintf(part_buf, sizeof(part_buf), PART, fb->len);
      res = httpd_resp_send_chunk(req, part_buf, hlen);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, (const char*)fb->buf, fb->len);
    }
    esp_camera_fb_return(fb);

    if (res != ESP_OK) break;  // client disconnected
    delay(10);                 // ~20-25 fps cap, keeps AI-Thinker responsive
  }
  return res;
}

static esp_err_t capture_handler(httpd_req_t* req) {
  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    httpd_resp_send_500(req);
    return ESP_FAIL;
  }
  httpd_resp_set_type(req, "image/jpeg");
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
  httpd_resp_set_hdr(req, "Content-Disposition", "inline; filename=capture.jpg");
  esp_err_t res = httpd_resp_send(req, (const char*)fb->buf, fb->len);
  esp_camera_fb_return(fb);
  return res;
}

static esp_err_t status_handler(httpd_req_t* req) {
  char json[200];
  snprintf(json, sizeof(json),
           "{\"device_id\":\"%s\",\"gate_id\":\"%s\",\"gate_type\":\"%s\",\"ip\":\"%s\",\"gate_open\":%s}",
           DEVICE_ID, GATE_ID, GATE_TYPE, WiFi.localIP().toString().c_str(),
           gateIsOpen ? "true" : "false");
  httpd_resp_set_type(req, "application/json");
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
  return httpd_resp_send(req, json, strlen(json));
}

static esp_err_t index_handler(httpd_req_t* req) {
  char html[256];
  snprintf(html, sizeof(html),
           "<html><body style='font-family:monospace;background:#111;color:#0f0'>"
           "<h3>SmartPark ESP32-CAM %s (%s)</h3>"
           "<img src='http://%s:%d/stream' style='width:100%%;max-width:640px'/>"
           "</body></html>",
           GATE_ID, GATE_TYPE, WiFi.localIP().toString().c_str(), STREAM_PORT);
  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, html, strlen(html));
}

void startCameraServers() {
  // Control server (port 80): index, capture, status
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = CONTROL_PORT;
  config.ctrl_port   = 32768;

  httpd_uri_t index_uri   = { .uri = "/",        .method = HTTP_GET, .handler = index_handler,   .user_ctx = NULL };
  httpd_uri_t capture_uri = { .uri = "/capture", .method = HTTP_GET, .handler = capture_handler, .user_ctx = NULL };
  httpd_uri_t status_uri  = { .uri = "/status",  .method = HTTP_GET, .handler = status_handler,  .user_ctx = NULL };

  if (httpd_start(&control_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(control_httpd, &index_uri);
    httpd_register_uri_handler(control_httpd, &capture_uri);
    httpd_register_uri_handler(control_httpd, &status_uri);
    Serial.printf("Control server started on port %d\n", CONTROL_PORT);
  } else {
    Serial.println("WARNING: control server failed to start");
  }

  // Stream server (port 81): MJPEG only, separate httpd so streaming never blocks /capture
  config.server_port = STREAM_PORT;
  config.ctrl_port   = 32769;
  httpd_uri_t stream_uri = { .uri = "/stream", .method = HTTP_GET, .handler = stream_handler, .user_ctx = NULL };

  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &stream_uri);
    Serial.printf("Stream server started on port %d\n", STREAM_PORT);
  } else {
    Serial.println("WARNING: stream server failed to start");
  }
}

// ═══════════════════ BACKEND REGISTRATION ═══════════════════

void registerWithBackend() {
  lastRegisterAt = millis();
  ensureWiFi();
  if (WiFi.status() != WL_CONNECTED) return;

  String ip = WiFi.localIP().toString();
  String body = "{";
  body += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  body += "\"gate_id\":\"" + String(GATE_ID) + "\",";
  body += "\"gate_type\":\"" + String(GATE_TYPE) + "\",";
  body += "\"ip\":\"" + ip + "\",";
  body += "\"stream_url\":\"http://" + ip + ":" + String(STREAM_PORT) + "/stream\",";
  body += "\"capture_url\":\"http://" + ip + ":" + String(CONTROL_PORT) + "/capture\"";
  body += "}";

  WiFiClient client;
  client.setTimeout(5000);
  if (!client.connect(API_HOST, API_PORT)) {
    Serial.println("Register: cannot reach API");
    return;
  }

  client.printf("POST /device/register HTTP/1.1\r\n");
  client.printf("Host: %s:%d\r\n", API_HOST, API_PORT);
  client.println("Content-Type: application/json");
  client.printf("Content-Length: %u\r\n", body.length());
  client.println("Connection: close");
  client.println();
  client.print(body);

  unsigned long t0 = millis();
  while (client.connected() && client.available() == 0 && millis() - t0 < 5000) delay(10);
  if (client.available()) {
    String line = client.readStringUntil('\n');
    Serial.printf("Register: %s\n", line.c_str());
  }
  client.stop();
}

// ═══════════════════ PROCESSING FLOW ═══════════════════

void processVehicle(const char* sensorName) {
  lastTriggerAt = millis();
  ledOn();

  camera_fb_t* fb = captureWithFlash();
  if (!fb) {
    Serial.println("Camera capture failed!");
    ledOff();
    return;
  }

  Serial.printf("Image captured: %dx%d JPEG (%d bytes)\n", fb->width, fb->height, fb->len);

  String action = uploadAndProcess(fb, sensorName);
  esp_camera_fb_return(fb);

  handleAction(action);
  ledOff();
}

void handleSerialCommands() {
  while (Serial.available()) {
    char command = Serial.read();
    if (command == '\n' || command == '\r' || command == ' ') continue;

    if (command == 't' || command == 'T') {
      Serial.println("\n[Serial] Manual capture + upload test");
      if (!gateIsOpen) processVehicle("serial-test");
      else Serial.println("Gate is still open; close it before manual capture.");
    } else if (command == 'o' || command == 'O') {
      Serial.println("\n[Serial] Open gate test");
      if (!gateIsOpen) openGate();
    } else if (command == 'c' || command == 'C') {
      Serial.println("\n[Serial] Close gate test");
      if (gateIsOpen) closeGate();
      else gateServo.write(GATE_CLOSED_DEGREES);
    } else if (command == 'd' || command == 'D') {
      float distanceCm = readDistanceCm();
      Serial.printf("\n[Serial] Distance: %.1f cm\n", distanceCm);
    } else if (command == 'r' || command == 'R') {
      Serial.println("\n[Serial] Re-register with backend");
      registerWithBackend();
    } else if (command == 'h' || command == 'H' || command == '?') {
      Serial.println("\nSerial commands:");
      Serial.println("  t = capture + upload test");
      Serial.println("  o = open gate servo");
      Serial.println("  c = close gate servo");
      Serial.println("  d = read ultrasonic distance");
      Serial.println("  r = re-register camera to backend");
      Serial.println("  h/? = help");
    }
  }
}

// ═══════════════════ ULTRASONIC SENSOR ═══════════════════

float readDistanceCm() {
  digitalWrite(PIN_HC_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_HC_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_HC_TRIG, LOW);

  long duration = pulseIn(PIN_HC_ECHO, HIGH, 30000);
  if (duration == 0) return -1.0;
  return duration * 0.0343 / 2.0;
}

// ═══════════════════ WIFI ═══════════════════

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting to WiFi");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\nConnected! IP: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("\nWiFi FAILED — will retry");
  }
}

void ensureWiFi() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost — reconnecting...");
    connectWiFi();
  }
}

void checkApiHealth() {
  ensureWiFi();
  if (WiFi.status() != WL_CONNECTED) return;

  Serial.printf("API target: http://%s:%d/health\n", API_HOST, API_PORT);

  WiFiClient client;
  if (client.connect(API_HOST, API_PORT)) {
    client.println("GET /health HTTP/1.1");
    client.printf("Host: %s:%d\r\n", API_HOST, API_PORT);
    client.println("Connection: close");
    client.println();

    unsigned long timeout = millis();
    while (client.available() == 0 && millis() - timeout < 5000) delay(10);
    if (client.available()) {
      String line = client.readStringUntil('\n');
      Serial.printf("API check: %s\n", line.c_str());
    }
    client.stop();
    Serial.println("API connection OK");
  } else {
    Serial.println("WARNING: Cannot reach API");
  }
}

// ═══════════════════ API UPLOAD ═══════════════════

String uploadAndProcess(camera_fb_t* fb, const char* sensorName) {
  ensureWiFi();
  if (WiFi.status() != WL_CONNECTED) return "WIFI_ERROR";

  WiFiClient client;
  client.setTimeout(API_TIMEOUT_MS);
  if (!client.connect(API_HOST, API_PORT)) {
    Serial.println("Connection to API failed");
    return "CONNECTION_ERROR";
  }

  Serial.printf("Uploading to %s:%d%s ...\n", API_HOST, API_PORT, API_PATH);
  unsigned long startMs = millis();

  String boundary = "----SmartParkBoundary";
  String head = "--" + boundary + "\r\n"
              + "Content-Disposition: form-data; name=\"file\"; filename=\"capture.jpg\"\r\n"
              + "Content-Type: image/jpeg\r\n\r\n";

  String tail = "\r\n--" + boundary + "\r\n"
              + "Content-Disposition: form-data; name=\"device_id\"\r\n\r\n" + String(DEVICE_ID)
              + "\r\n--" + boundary + "\r\n"
              + "Content-Disposition: form-data; name=\"gate_id\"\r\n\r\n" + String(GATE_ID)
              + "\r\n--" + boundary + "\r\n"
              + "Content-Disposition: form-data; name=\"gate_type\"\r\n\r\n" + String(GATE_TYPE)
              + "\r\n--" + boundary + "\r\n"
              + "Content-Disposition: form-data; name=\"sensor\"\r\n\r\n" + String(sensorName)
              + "\r\n--" + boundary + "\r\n"
              + "Content-Disposition: form-data; name=\"confidence\"\r\n\r\n" + String(API_CONFIDENCE)
              + "\r\n--" + boundary + "\r\n"
              + "Content-Disposition: form-data; name=\"nearest_only\"\r\n\r\n" + String(API_NEAREST_ONLY)
              + "\r\n--" + boundary + "--\r\n";

  uint32_t totalLen = head.length() + fb->len + tail.length();

  client.printf("POST %s HTTP/1.1\r\n", API_PATH);
  client.printf("Host: %s:%d\r\n", API_HOST, API_PORT);
  client.printf("Content-Type: multipart/form-data; boundary=%s\r\n", boundary.c_str());
  client.printf("Content-Length: %u\r\n", totalLen);
  client.println("Connection: close");
  client.println();

  client.print(head);

  const size_t CHUNK = 1024;
  for (size_t i = 0; i < fb->len; i += CHUNK) {
    size_t len = min(CHUNK, fb->len - i);
    client.write(fb->buf + i, len);
    delay(0);
  }

  client.print(tail);

  String response = readHttpResponse(client);
  client.stop();

  Serial.printf("Response received in %lums\n", millis() - startMs);

  if (response.length() == 0) {
    Serial.println("API response timeout/empty");
    return "TIMEOUT";
  }

  int statusCode = parseHttpStatus(response);
  Serial.printf("HTTP status: %d\n", statusCode);
  if (statusCode < 200 || statusCode >= 300) {
    Serial.println("API returned non-2xx response:");
    Serial.println(response.substring(0, 700));
    return "HTTP_ERROR";
  }

  int bodyStart = response.indexOf("\r\n\r\n");
  if (bodyStart < 0) {
    Serial.println("Invalid HTTP response; body not found");
    return "HTTP_PARSE_ERROR";
  }

  return parseResponse(response.substring(bodyStart + 4));
}

String readHttpResponse(WiFiClient& client) {
  String response = "";
  unsigned long lastDataAt = millis();
  while (client.connected() || client.available()) {
    while (client.available()) {
      response += (char)client.read();
      lastDataAt = millis();
    }
    if (millis() - lastDataAt > API_TIMEOUT_MS) break;
    delay(1);
  }
  return response;
}

int parseHttpStatus(const String& response) {
  if (!response.startsWith("HTTP/")) return 0;
  int firstSpace = response.indexOf(' ');
  if (firstSpace < 0 || response.length() < firstSpace + 4) return 0;
  return response.substring(firstSpace + 1, firstSpace + 4).toInt();
}

String parseResponse(const String& body) {
  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, body);
  if (err) {
    Serial.printf("JSON parse error: %s\n", err.c_str());
    Serial.println(body.substring(0, 500));
    return "PARSE_ERROR";
  }

  String action = doc["command"]["action"] | "UNKNOWN";
  String reason = doc["command"]["reason"] | "";

  JsonArray results = doc["pipeline"]["results"].as<JsonArray>();
  if (results.size() > 0) {
    String plate = results[0]["plate_text"] | "";
    String normalized = results[0]["plate"]["normalized_plate"] | plate;
    String prefix = results[0]["plate"]["prefix_letters"] | "";
    String number = results[0]["plate"]["middle_numbers"] | "";
    String suffix = results[0]["plate"]["suffix_letters"] | "";
    float conf = results[0]["plate_confidence"] | 0.0;
    String decision = results[0]["access"]["decision"] | "";

    Serial.printf("Action     : %s\n", action.c_str());
    Serial.printf("Plate      : %s\n", normalized.c_str());
    Serial.printf("Components : %s / %s / %s\n", prefix.c_str(), number.c_str(), suffix.c_str());
    Serial.printf("Confidence : %.1f%%\n", conf * 100.0);
    Serial.printf("Decision   : %s\n", decision.c_str());
  } else {
    Serial.printf("Action: %s | Reason: %s\n", action.c_str(), reason.c_str());
  }

  return action;
}

// ═══════════════════ ACTION HANDLER ═══════════════════

void handleAction(const String& action) {
  if (action == "OPEN_GATE") {
    openGate();
  } else if (action == "MANUAL_REQUIRED") {
    Serial.println("=== MANUAL REQUIRED ===");
    blinkStatus(3, 200);
  } else {
    Serial.printf("=== DENIED/ERROR: %s ===\n", action.c_str());
    blinkStatus(5, 100);
  }
}

// ═══════════════════ GATE CONTROL ═══════════════════

void openGate() {
  Serial.println("=== GATE OPENING ===");
  for (int angle = GATE_CLOSED_DEGREES; angle <= GATE_OPEN_DEGREES; angle += 2) {
    gateServo.write(angle);
    delay(15);
  }
  gateIsOpen = true;
  gateOpenedAt = millis();
  vehiclePassingIR = false;
  irFirstDetectAt = 0;
  Serial.println("Gate open — waiting for vehicle to pass (IR sensor)...");
}

void closeGate() {
  Serial.println("=== GATE CLOSING ===");
  for (int angle = GATE_OPEN_DEGREES; angle >= GATE_CLOSED_DEGREES; angle -= 2) {
    gateServo.write(angle);
    delay(15);
  }
  gateIsOpen = false;
  vehiclePassingIR = false;
  Serial.println("Gate closed. Waiting for next vehicle...\n");
}

void handleGateAutoClose() {
  bool irDetected = digitalRead(PIN_IR_OBSTACLE) == LOW;

  if (irDetected && !vehiclePassingIR) {
    vehiclePassingIR = true;
    irFirstDetectAt = millis();
    Serial.println("IR: Vehicle entering gate...");
  }

  if (vehiclePassingIR && !irDetected) {
    if (millis() - irFirstDetectAt > IR_DEBOUNCE_MS) {
      Serial.println("IR: Vehicle passed through gate!");
      delay(500);
      closeGate();
      return;
    }
  }

  if (millis() - gateOpenedAt >= GATE_TIMEOUT_MS) {
    Serial.println("TIMEOUT: Gate open too long — closing (IR fallback)");
    closeGate();
  }
}

// ═══════════════════ LED HELPERS ═══════════════════

void ledOn()  { digitalWrite(PIN_LED_ONBOARD, LOW); }   // Active LOW
void ledOff() { digitalWrite(PIN_LED_ONBOARD, HIGH); }

void blinkOK() {
  for (int i = 0; i < 2; i++) { ledOn(); delay(150); ledOff(); delay(150); }
}
void blinkError(int count) {
  for (int i = 0; i < count; i++) { ledOn(); delay(80); ledOff(); delay(80); }
}
void blinkStatus(int count, int delayMs) {
  for (int i = 0; i < count; i++) { ledOn(); delay(delayMs); ledOff(); delay(delayMs); }
}
