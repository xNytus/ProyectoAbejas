#include <Wire.h>
#include "Adafruit_SHT4x.h"
#include "DHT.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include "secrets.h"

// Pines sensores
#define DHTPIN 4
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);
Adafruit_SHT4x sht4 = Adafruit_SHT4x();

// SIM7600 serial (solo para GPS)
#include <HardwareSerial.h>
HardwareSerial SerialAT(2);
#define MODEM_RX 16
#define MODEM_TX 17
#define MODEM_BAUD 9600

// Configuración AWS IoT
const char* AWS_IOT_ENDPOINT = MQTT_HOST;
const char* AWS_IOT_TOPIC = "sensores_colmena/pub";
const char* AWS_IOT_CLIENT_ID = THINGNAME;
const char* Colmena = "Colmena2";

// Variables tiempo
time_t now;
time_t nowish = 1510592825;

String lat = "";
String lng = "";
String formattedDateTime = "";

// Tiempo de deep sleep
#define uS_TO_S_FACTOR 1000000ULL
#define TIEMPO_SLEEP_MINUTOS 30
const long delayEnvioAWS = TIEMPO_SLEEP_MINUTOS * 60 * 1000; // 30 minutos

WiFiClientSecure espClient;
PubSubClient client(espClient);

String enviarAT(String cmd, int delayTime = 1000) {
  Serial.println(">> Enviando comando AT: " + cmd);
  SerialAT.println(cmd);
  delay(100);
  String response = "";
  unsigned long startTime = millis();
  while (millis() - startTime < delayTime) {
    while (SerialAT.available()) {
      response += (char)SerialAT.read();
      startTime = millis();
    }
    delay(10);
  }
  response.trim();
  if (response.length() > 0) {
    Serial.println("<< Respuesta: " + response);
  } else {
    Serial.println("<< Respuesta: (vacía)");
  }
  return response;
}

void setup_wifi() {
  delay(10);
  Serial.println("\nConectando a WiFi: " + String(WIFI_SSID));
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int retries = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    retries++;
    if (retries > 20) {
      Serial.println("\nNo se pudo conectar. Reintentando...");
      WiFi.disconnect();
      delay(1000);
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      retries = 0;
    }
  }

  Serial.println("\nWiFi conectado. IP: " + WiFi.localIP().toString());
}

void updateFormattedDateTime() {
  time_t now_time = time(nullptr);
  struct tm timeinfo;
  localtime_r(&now_time, &timeinfo);
  char timeStr[20];
  strftime(timeStr, sizeof(timeStr), "%d/%m/%Y %H:%M:%S", &timeinfo);
  formattedDateTime = String(timeStr);
}

void NTPConnect() {
  Serial.print("Configurando tiempo por SNTP");
  configTime(TIME_ZONE * 3600, 0, "pool.ntp.org", "time.nist.gov");
  now = time(nullptr);
  while (now < nowish) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println(" Terminado");
  updateFormattedDateTime();
  Serial.println("Hora actual: " + formattedDateTime);
}

void messageReceived(char *topic, byte *payload, unsigned int length) {
  Serial.print("Recibido [" + String(topic) + "]: ");
  for (int i = 0; i < length; i++) Serial.print((char)payload[i]);
  Serial.println();
}

void connectAWS() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi no conectado. Reintentando...");
    setup_wifi();
    NTPConnect();
  }

  Serial.println("Conectando a AWS IOT...");
  unsigned long start = millis();
  while (!client.connected()) {
    String clientId = AWS_IOT_CLIENT_ID + String(random(0xffff), HEX);
    if (client.connect(clientId.c_str())) {
      Serial.println("Conectado a AWS IoT.");
      client.subscribe(AWS_IOT_TOPIC);
    } else {
      Serial.print("Error MQTT rc=");
      Serial.print(client.state());
      Serial.println(" Reintentando en 5s...");
      delay(5000);
      if (millis() - start > 60000) {
        Serial.println("Timeout MQTT. Reiniciando...");
        ESP.restart();
      }
    }
  }
}

bool obtenerCoordenadasGPS() {
  Serial.println("🛰 Obteniendo coordenadas GPS...");
  String gpsInfo = "";
  for (int i = 0; i < 10; i++) {
    gpsInfo = enviarAT("AT+CGPSINFO", 1500);
    if (gpsInfo.indexOf("+CGPSINFO:") >= 0 && gpsInfo.indexOf(",,,,,,,,") == -1) {
      break;
    }
    delay(500);
  }

  if (gpsInfo.indexOf("+CGPSINFO:") >= 0) {
    int start = gpsInfo.indexOf(":") + 1;
    String datos = gpsInfo.substring(start);
    datos.trim();
    Serial.println(">> [GPSINFO]: " + datos);

    int i1 = datos.indexOf(",");
    int i2 = datos.indexOf(",", i1 + 1);
    int i3 = datos.indexOf(",", i2 + 1);
    int i4 = datos.indexOf(",", i3 + 1);

    String rawLat = datos.substring(0, i1);
    String latDir = datos.substring(i1 + 1, i2);
    String rawLon = datos.substring(i2 + 1, i3);
    String lonDir = datos.substring(i3 + 1, i4);

    if (rawLat.length() > 0 && rawLon.length() > 0) {
      float flat = rawLat.substring(0, 2).toFloat() + rawLat.substring(2).toFloat() / 60.0;
      float flon = rawLon.substring(0, 3).toFloat() + rawLon.substring(3).toFloat() / 60.0;
      if (latDir == "S") flat *= -1;
      if (lonDir == "W") flon *= -1;
      lat = String(flat, 6);
      lng = String(flon, 6);
      Serial.println(">> Lat: " + lat + ", Lng: " + lng);
      return true;
    }
  }
  Serial.println("No se pudieron obtener coordenadas GPS.");
  return false;
}

void publishMessage(float humExt, float tempExt, float humInt, float tempInt) {
  if (humInt < 0 || humInt > 100) humInt = 0;
  if (tempInt < -40 || tempInt > 125) tempInt = 0;

  StaticJsonDocument<512> doc;
  doc["sensorId"] = Colmena;
  doc["fechaHora"] = formattedDateTime;
  doc["humExt"] = humExt;
  doc["tempExt"] = tempExt;
  doc["humInt"] = humInt;
  doc["tempInt"] = tempInt;
  doc["lat"] = lat;
  doc["lng"] = lng;

  char jsonBuffer[512];
  size_t n = serializeJson(doc, jsonBuffer);

  Serial.println("Publicando: " + String(jsonBuffer));

  if (client.connected() && client.publish(AWS_IOT_TOPIC, jsonBuffer, n)) {
    Serial.println("Publicación en buffer exitosa. Esperando transmisión...");

    // Ejecutar client.loop por un corto tiempo para asegurar transmisión
    unsigned long waitStart = millis();
    while (millis() - waitStart < 2000) {  // Espera 2 segundos
      client.loop();
      delay(10);
    }

    if (client.connected()) {
      Serial.println("Transmisión confirmada. Entrando en deep sleep...");
      esp_sleep_enable_timer_wakeup(TIEMPO_SLEEP_MINUTOS * 60 * uS_TO_S_FACTOR);
      esp_deep_sleep_start();
    } else {
      Serial.println("Se perdió conexión antes del sleep. Reintentando...");
    }

  } else {
    Serial.println("Error al publicar MQTT. Estado: " + String(client.state()));
  }
}


void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("Iniciando sistema...");

  dht.begin();
  Wire.begin();

  if (!sht4.begin()) {
    Serial.println("SHT4x no detectado. Verifica conexión I2C.");
    while (true) delay(1);
  }

  sht4.setPrecision(SHT4X_HIGH_PRECISION);
  sht4.setHeater(SHT4X_NO_HEATER);

  SerialAT.begin(MODEM_BAUD, SERIAL_8N1, MODEM_RX, MODEM_TX);
  delay(100);
  enviarAT("AT+CGPS=1,1", 1000);  // Encender GPS

  espClient.setCACert(cacert);
  espClient.setCertificate(client_cert);
  espClient.setPrivateKey(privkey);

  client.setServer(AWS_IOT_ENDPOINT, 8883);
  client.setCallback(messageReceived);

  setup_wifi();
  NTPConnect();
  connectAWS();

  obtenerCoordenadasGPS();
  Serial.println("Sistema listo.");
}

void loop() {
  // Solo se ejecuta una vez antes del deep sleep

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi perdido. Reintentando...");
    setup_wifi();
    NTPConnect();
  }

  if (!client.connected()) {
    connectAWS();
  }

  client.loop();
  updateFormattedDateTime();
  obtenerCoordenadasGPS();

  float h_dht = dht.readHumidity();
  float t_dht = dht.readTemperature();

  sensors_event_t hum, temp;
  bool shtSuccess = false;
  for (int i = 0; i < 3; i++) {
    if (sht4.getEvent(&hum, &temp)) {
      shtSuccess = true;
      break;
    }
    Serial.println("Fallo al leer SHT41. Reintentando...");
    delay(100);
  }

  float h_sht = shtSuccess ? hum.relative_humidity : -1;
  float t_sht = shtSuccess ? temp.temperature : -100;

  Serial.printf("Lectura DHT22 - Temp: %.2f°C, Hum: %.2f%%\n", t_dht, h_dht);
  Serial.printf("Lectura SHT41 - Temp: %.2f°C, Hum: %.2f%%\n", t_sht, h_sht);
  publishMessage(h_dht, t_dht, h_sht, t_sht);

  // En caso de error de publicación, espera 5 segundos y reinicia (prevención de bloqueo)
  delay(5000);
  ESP.restart();
}
