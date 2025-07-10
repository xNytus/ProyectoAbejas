#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include <DHT.h>
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include "secrets.h"

#define TIME_ZONE -4
#define DHTPIN D5
#define DHTTYPE DHT22

String sensor_id_final = "Colmena1";
String fecha;

#define AWS_IOT_PUBLISH_TOPIC   "sensores_colmena/pub"
#define AWS_IOT_SUBSCRIBE_TOPIC "sensores_colmena/sub"

WiFiClientSecure net;
BearSSL::X509List cert(cacert);
BearSSL::X509List client_crt(client_cert);
BearSSL::PrivateKey key(privkey);
PubSubClient client(net);

time_t now;
time_t nowish = 1510592825;

DHT dht(DHTPIN, DHTTYPE);
Adafruit_SHT4x sht41 = Adafruit_SHT4x();

// Tiempo entre envíos (en milisegundos)
unsigned long intervalo = 30 * 60 * 1000UL; // 1 minuto (ajusta aquí)
unsigned long ultimoEnvio = 0;

void updateFecha() {
  time_t now_time = time(nullptr);
  struct tm timeinfo;
  localtime_r(&now_time, &timeinfo);
  char timeStr[20];
  strftime(timeStr, sizeof(timeStr), "%d/%m/%Y %H:%M:%S", &timeinfo);
  fecha = String(timeStr);
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
  updateFecha();
  Serial.print("Hora actual: ");
  Serial.println(fecha);
}

void messageReceived(char *topic, byte *payload, unsigned int length) {
  Serial.print("Recibido [");
  Serial.print(topic);
  Serial.print("]: ");
  for (int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
}

void connectAWS() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi no conectado. Intentando...");
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 30) {
      delay(500);
      Serial.print(".");
      retries++;
    }
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println(" Falló conexión WiFi. Reiniciando...");
      delay(10000);
      ESP.restart();
    }
    Serial.println(" WiFi conectado!");
    NTPConnect();
  }

  Serial.println("Conectando a AWS IOT...");
  unsigned long start = millis();
  while (!client.connect(THINGNAME)) {
    Serial.print(".");
    delay(1000);
    if (millis() - start > 30000) return;
  }

  if (client.connected()) {
    client.subscribe(AWS_IOT_SUBSCRIBE_TOPIC);
    Serial.println("Conectado a AWS IoT!");
  } else {
    Serial.println("Falló conexión a AWS IoT");
  }
}

void publishSensorData() {
  updateFecha();

  float humExt = NAN;
  float tempExt = NAN;
  float humInt = NAN;
  float tempInt = NAN;

  // Leer DHT22 con reintentos
  for (int i = 0; i < 3; i++) {
    humExt = dht.readHumidity();
    tempExt = dht.readTemperature();
    Serial.printf("Intento %d - DHT22 -> Temp: %.2f°C, Hum: %.2f%%\n", i + 1, tempExt, humExt);
    if (!isnan(humExt) && !isnan(tempExt)) break;
    delay(1000);
  }

  // Leer SHT41 con reintentos
  sensors_event_t humidity, temp;
  for (int i = 0; i < 3; i++) {
    if (sht41.getEvent(&humidity, &temp)) {
      humInt = humidity.relative_humidity;
      tempInt = temp.temperature;
      Serial.printf("Intento %d - SHT41 -> Temp: %.2f°C, Hum: %.2f%%\n", i + 1, tempInt, humInt);
      break;
    } else {
      Serial.printf("Intento %d - SHT41 fallo de lectura\n", i + 1);
    }
    delay(1000);
  }

  if (isnan(humExt) || isnan(tempExt) || isnan(humInt) || isnan(tempInt)) {
    Serial.println("Error leyendo sensores. Reiniciando...");
    delay(3000);
    ESP.restart();
    return;
  }

  StaticJsonDocument<512> doc;
  doc["sensorId"] = sensor_id_final;
  doc["humExt"] = humExt;
  doc["tempExt"] = tempExt;
  doc["humInt"] = humInt;
  doc["tempInt"] = tempInt;
  doc["fechaHora"] = fecha;
  doc["lat"] = -32.901757;
  doc["lng"] = -71.227288;

  char jsonBuffer[512];
  size_t n = serializeJson(doc, jsonBuffer);

  Serial.print("Publicando: ");
  Serial.println(jsonBuffer);

  if (client.publish(AWS_IOT_PUBLISH_TOPIC, jsonBuffer, n)) {
    Serial.println("✅ Publicación exitosa.");
  } else {
    Serial.println("❌ Fallo al publicar. Reintentando en próximo ciclo.");
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("Iniciando ESP8266...");

  dht.begin();

  Serial.print("Detectando SHT41...");
  bool sht_ok = false;
  for (int i = 0; i < 5; i++) {
    if (sht41.begin()) {
      sht_ok = true;
      Serial.println(" SHT41 detectado correctamente.");
      break;
    } else {
      Serial.print(".");
      delay(1000);
    }
  }

  if (!sht_ok) {
    Serial.println("\nADVERTENCIA: No se pudo detectar el sensor SHT41 tras múltiples intentos.");
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println(" WiFi conectado!");

  NTPConnect();

  net.setTrustAnchors(&cert);
  net.setClientRSACert(&client_crt, &key);
  client.setServer(MQTT_HOST, 8883);
  client.setCallback(messageReceived);

  connectAWS();
  ultimoEnvio = millis(); // inicializar temporizador
}

void loop() {
  client.loop();

  if (!client.connected()) {
    connectAWS();
  }

  if (millis() - ultimoEnvio >= intervalo) {
    publishSensorData();
    ultimoEnvio = millis();
  }
}
