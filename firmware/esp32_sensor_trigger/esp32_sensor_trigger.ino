/*
  SmartPark ESP32 Sensor Trigger

  Prototype flow while Raspberry Pi 5 is not available:
  - ESP32 reads an ultrasonic sensor.
  - When a vehicle is close enough, ESP32 posts JSON to SmartPark API.
  - SmartPark API captures from the laptop/PC camera and runs ANPR + OCR.

  Board: ESP32 Dev Module
  Sensor: HC-SR04 ultrasonic
*/

#include <WiFi.h>
#include <HTTPClient.h>

const char* WIFI_SSID = "xzzx";
const char* WIFI_PASSWORD = "12345678";

// Replace IP_LAPTOP with the laptop/PC IP address on the same WiFi.
const char* API_URL = "http://10.209.254.249:8000/device/trigger";

const int TRIG_PIN = 5;
const int ECHO_PIN = 18;

const float TRIGGER_DISTANCE_CM = 30.0;
const unsigned long TRIGGER_COOLDOWN_MS = 8000;

unsigned long lastTriggerAt = 0;

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("Connected. ESP32 IP: ");
  Serial.println(WiFi.localIP());
}

float readDistanceCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  if (duration == 0) {
    return -1.0;
  }

  return duration * 0.0343 / 2.0;
}

void sendTrigger(float distanceCm) {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  HTTPClient http;
  http.begin(API_URL);
  http.addHeader("Content-Type", "application/json");

  String payload = "{";
  payload += "\"device_id\":\"esp32-gate-entry-1\",";
  payload += "\"gate_id\":\"GATE-A-IN\",";
  payload += "\"gate_type\":\"entry\",";
  payload += "\"sensor\":\"ultrasonic\",";
  payload += "\"distance_cm\":";
  payload += String(distanceCm, 1);
  payload += ",";
  payload += "\"confidence\":0.25,";
  payload += "\"nearest_only\":true";
  payload += "}";

  Serial.println("Sending trigger:");
  Serial.println(payload);

  int statusCode = http.POST(payload);
  Serial.print("HTTP status: ");
  Serial.println(statusCode);

  String response = http.getString();
  Serial.println("Response:");
  Serial.println(response);

  http.end();
}

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  connectWiFi();
}

void loop() {
  float distanceCm = readDistanceCm();

  if (distanceCm > 0) {
    Serial.print("Distance: ");
    Serial.print(distanceCm);
    Serial.println(" cm");
  }

  bool vehicleDetected = distanceCm > 0 && distanceCm <= TRIGGER_DISTANCE_CM;
  bool cooldownDone = millis() - lastTriggerAt >= TRIGGER_COOLDOWN_MS;

  if (vehicleDetected && cooldownDone) {
    sendTrigger(distanceCm);
    lastTriggerAt = millis();
  }

  delay(300);
}
