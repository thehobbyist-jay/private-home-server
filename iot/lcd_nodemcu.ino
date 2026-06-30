#include <ESP8266WiFi.h>
#include <LiquidCrystal_I2C.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>

// CPU [████░░░] 50%
// RAM [████░░░] 50%
// HARDCODED CONFIGURATIONS
const char* ssid = "Your Wifi Name";          // Replace with your WiFi Name
const char* password = "Your Wifi Password";       // Replace with your WiFi Password
const char* glances_server = "glances.home.local";   // Your hardcoded Glances host IP

// Initialize the 16x2 LCD (0x27 or 0x3F)
LiquidCrystal_I2C lcd(0x27, 16, 2);

// Custom sub-pixel character arrays for a smooth progression bar (5 vertical lines max per block)
byte bar0[8] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }; // Empty block (not used, we use ' ')
byte bar1[8] = { 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10 }; // 1 pixel wide
byte bar2[8] = { 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18 }; // 2 pixels wide
byte bar3[8] = { 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C }; // 3 pixels wide
byte bar4[8] = { 0x1E, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E }; // 4 pixels wide
byte bar5[8] = { 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F }; // 5 pixels wide (Full block)

void setup() {
  Serial.begin(115200, SERIAL_8N1);
  Serial.setRxBufferSize(512);

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Connecting WiFi");
  WiFi.begin(ssid, password);

  int timeout = 0;
  while (WiFi.status() != WL_CONNECTED && timeout < 20) {
    delay(500);
    lcd.setCursor(timeout % 16, 1);
    lcd.print(".");
    timeout++;
  }

  // Register custom characters into the LCD hardware memory (CGRAM slots 1 to 5)
  lcd.createChar(1, bar1);
  lcd.createChar(2, bar2);
  lcd.createChar(3, bar3);
  lcd.createChar(4, bar4);
  lcd.createChar(5, bar5);

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Connected! IP:");
  lcd.setCursor(0, 1);
  lcd.print(WiFi.localIP());
  delay(3000);
  lcd.clear();

  // Print persistent labels once to completely remove interface lag
  lcd.setCursor(0, 0); lcd.print("CPU ");
  lcd.setCursor(0, 1); lcd.print("RAM ");
}

// Universal API Fetcher
String fetchGlancesData(String endpoint) {
  WiFiClient client;
  HTTPClient http;

  String url = "http://" + String(glances_server) + ":61208/api/4/" + endpoint;
  http.begin(client, url);
  int httpCode = http.GET();

  String payload = "";
  if (httpCode > 0) {
    payload = http.getString();
  } else {
    Serial.print("HTTP GET failed for ");
    Serial.print(endpoint);
    Serial.print(": ");
    Serial.println(http.errorToString(httpCode));
  }
  http.end();
  return payload;
}

// Parses target field out of server json payload
float parseJsonValue(String payload, String fieldName) {
  if (payload.length() == 0) return -1.0;

  JsonDocument filter;
  filter[fieldName] = true;

  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, payload, DeserializationOption::Filter(filter));

  if (error) {
    Serial.print("JSON Deserialization failed: ");
    Serial.println(error.c_str());
    return -1.0;
  }

  return doc[fieldName].as<float>();
}

// Renders the sub-pixel graph and numerical text value
void drawRowMetrics(int row, float percentage) {
  // If API error occurs, notify visually on screen
  if (percentage < 0) {
    lcd.setCursor(4, row);
    lcd.print("[API ERROR]  ");
    return;
  }

  // --- STEP 1: RENDER CUSTOM PROGRESS BAR ---
  // The progress bar span is 7 characters wide.
  // Each character has 5 vertical pixel lines. Total pixels = 7 * 5 = 35 pixels.
  int totalPixels = (int)((percentage / 100.0) * 35.0);
  
  // Constrain limits to stay cleanly within layout bounds
  if (totalPixels > 35) totalPixels = 35;
  if (totalPixels < 0)  totalPixels = 0;

  int fullBlocks = totalPixels / 5;
  int remainderPixels = totalPixels % 5;

  lcd.setCursor(4, row);
  
  // Print the full 5-pixel solid blocks
  for (int i = 0; i < fullBlocks; i++) {
    lcd.write(5); 
  }

  // Print the partial fractional step block if one exists
  if (fullBlocks < 7) {
    if (remainderPixels > 0) {
      lcd.write(remainderPixels); // Custom character mapping index (1 to 4)
      fullBlocks++;
    }
  }

  // Fill up any remaining empty layout space with standard whitespace characters
  for (int i = fullBlocks; i < 7; i++) {
    lcd.print(" ");
  }

  // --- STEP 2: RENDER PERCENTAGE VALUE ---
  lcd.setCursor(11, row);
  
  char numBuffer[6];
  // Formats to 1 decimal place with a minimum width of 4 characters
  dtostrf(percentage, 4, 1, numBuffer);
  lcd.print(numBuffer);
  lcd.print("%");
}

void loop() {
  // 1. Fetch raw API metrics strings
  String cpuPayload = fetchGlancesData("cpu");
  String memPayload = fetchGlancesData("mem");

  // 2. Filter variables
  float cpuUsage = parseJsonValue(cpuPayload, "total");
  float memUsage = parseJsonValue(memPayload, "percent");

  // 3. Render complete bars and numbers down to the local hardware panel
  drawRowMetrics(0, cpuUsage); // Render CPU on Row 0
  drawRowMetrics(1, (memUsage - 18.8)); // Render RAM on Row 1

  delay(3000); // Poll metrics every 3 seconds
}
