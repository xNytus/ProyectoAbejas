#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <time.h>
// Wire.h y Adafruit_SHT4x.h NO son necesarios aquí
// DHT.h NO es necesario aquí
#include "secrets.h" // Mantén tus credenciales aquí

#define TIME_ZONE -4 // Define tu zona horaria

// Los pines de sensores ya no se definen aquí

String sensor_id_final = "Colmena2"; // ID que se enviará a AWS, puede ser el mismo o modificado
String fecha;
unsigned long lastPublishMillis = 0;
// const long interval = 5000; // El intervalo de envío del Arduino ahora dicta la frecuencia de datos
const long delayEnvioAWS = 10 * 60 * 1000; // 10 minutos para enviar a AWS

#define AWS_IOT_PUBLISH_TOPIC   "sensores_colmena/pub"
#define AWS_IOT_SUBSCRIBE_TOPIC "sensores_colmena/sub"

WiFiClientSecure net;

BearSSL::X509List cert(cacert);
BearSSL::X509List client_crt(client_cert);
BearSSL::PrivateKey key(privkey);

PubSubClient client(net);

time_t now;
time_t nowish = 1510592825; // Referencia para saber si NTP se sincronizó

// Buffer para almacenar los datos recibidos del Arduino
String receivedDataFromArduino = "";
bool newDataReceived = false;

void updateFecha() {
  time_t now_time = time(nullptr); // Renombrado para evitar conflicto con variable global 'now'
  struct tm timeinfo;
  localtime_r(&now_time, &timeinfo);

  char timeStr[20];
  strftime(timeStr, sizeof(timeStr), "%d/%m/%Y %H:%M:%S", &timeinfo);
  fecha = String(timeStr);
}

void NTPConnect(void) {
  Serial.print("Configurando tiempo por SNTP");
  configTime(TIME_ZONE * 3600, 0 * 3600, "pool.ntp.org", "time.nist.gov");
  now = time(nullptr);
  while (now < nowish) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println(" Terminado");
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo); // Usa gmtime_r para UTC o localtime_r para local con zona horaria
  updateFecha(); // Actualiza la variable global 'fecha'
  Serial.print("Hora actual (después de NTP y updateFecha): ");
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
  // WiFi.mode(WIFI_STA) y WiFi.begin ya no se hacen aquí si se hacen en setup
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi no conectado. Intentando conectar WiFi...");
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    Serial.print(String("Intentando conectar al SSID: ") + String(WIFI_SSID));
    int wifi_retries = 0;
    while (WiFi.status() != WL_CONNECTED && wifi_retries < 30) { // Intentar por ~15 segundos
      Serial.print(".");
      delay(500);
      wifi_retries++;
    }
    if(WiFi.status() != WL_CONNECTED){
        Serial.println(" Falló la conexión WiFi. Reiniciando ESP en 10s...");
        delay(10000);
        ESP.restart();
    }
    Serial.println(" WiFi conectado!");
    NTPConnect(); // Sincronizar NTP después de conectar WiFi
  }


  // Configurar certificados SSL/TLS solo una vez o si es necesario
  // Estas líneas pueden moverse a setup si no cambian.
  // net.setTrustAnchors(&cert);
  // net.setClientRSACert(&client_crt, &key);
  // client.setServer(MQTT_HOST, 8883);
  // client.setCallback(messageReceived);


  Serial.println("Conectando a AWS IOT");
  unsigned long connectAttemptStart = millis();
  while (!client.connect(THINGNAME)) {
    Serial.print(".");
    delay(1000);
    if (millis() - connectAttemptStart > 30000) { // Timeout de 30 segundos
        Serial.println("Timeout conectando a AWS IoT!");
        // Aquí podrías reiniciar el ESP o intentar reconectar WiFi
        return; // Salir para reintentar en el próximo ciclo del loop
    }
  }

  if (!client.connected()) {
    Serial.println("AWS IoT Timeout! (después del bucle de conexión)");
    return;
  }
  client.subscribe(AWS_IOT_SUBSCRIBE_TOPIC);
  Serial.println("AWS IoT Conectado!");
}

void publishMessage(String jsonDataFromArduino) {
  if (jsonDataFromArduino.length() == 0) {
    Serial.println("No hay datos de Arduino para publicar.");
    return;
  }

  StaticJsonDocument<300> arduinoDoc; // Para parsear el JSON del Arduino
  DeserializationError error = deserializeJson(arduinoDoc, jsonDataFromArduino);

  if (error) {
    Serial.print(F("deserializeJson() falló con el código "));
    Serial.println(error.f_str());
    // (Opcional) Enviar error de vuelta al Arduino
    // Serial.println("ERROR: JSON_PARSE_FAILED");
    return;
  }

  updateFecha(); // Asegúrate que la fecha esté actualizada antes de enviar

  StaticJsonDocument<512> finalDoc; // Documento final para AWS
  // Copia los campos del JSON del Arduino
  finalDoc["sensorId"] = arduinoDoc.containsKey("sensorIdBase") ? arduinoDoc["sensorIdBase"].as<String>() : sensor_id_final;
  finalDoc["humExt"] = arduinoDoc["humExt"];
  finalDoc["tempExt"] = arduinoDoc["tempExt"];
  finalDoc["humInt"] = arduinoDoc["humInt"];
  finalDoc["tempInt"] = arduinoDoc["tempInt"];

  // Añade campos específicos del ESP8266
  finalDoc["fechaHora"] = fecha;
  finalDoc["lat"] = -32.901757; // O obtén de alguna manera si es dinámico
  finalDoc["lng"] = -71.227288;

  char jsonBuffer[512];
  size_t n = serializeJson(finalDoc, jsonBuffer);

  Serial.print("Publicando a AWS: ");
  Serial.println(jsonBuffer);

  if (client.publish(AWS_IOT_PUBLISH_TOPIC, jsonBuffer, n)) {
    Serial.println("Datos enviados correctamente a AWS.");
    // (Opcional) Enviar confirmación al Arduino
    // Serial.println("OK: AWS_PUBLISHED");
  } else {
    Serial.println("Error de envío a AWS.");
    // (Opcional) Enviar error de vuelta al Arduino
    // Serial.println("ERROR: AWS_PUBLISH_FAILED");
  }
}

void setup() {
  Serial.begin(115200); // Para comunicación con Arduino y depuración del ESP
  delay(1000); // Un pequeño delay para estabilizar

  Serial.println("D1 Mini iniciando...");

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print(String("Intentando conectar al SSID: ") + String(WIFI_SSID));
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(1000);
  }
  Serial.println(" WiFi conectado!");

  NTPConnect(); // Sincronizar NTP

  net.setTrustAnchors(&cert);
  net.setClientRSACert(&client_crt, &key);
  client.setServer(MQTT_HOST, 8883);
  client.setCallback(messageReceived);

  connectAWS(); // Intenta conectar a AWS en el setup

  Serial.println("D1 Mini listo para recibir datos del Arduino.");
}

void loop() {
  if (Serial.available() > 0) {
    receivedDataFromArduino = Serial.readStringUntil('\n');
    newDataReceived = true;
    Serial.print("Recibido de Arduino: ");
    Serial.println(receivedDataFromArduino);
  }

  if (!client.connected()) {
    Serial.println("Desconectado de AWS. Intentando reconectar...");
    connectAWS(); // Intentará reconectar WiFi si es necesario y luego AWS
  } else {
    client.loop(); // Mantener la conexión MQTT activa
  }

  unsigned long currentMillis = millis();
  // Publicar a AWS si hay nuevos datos Y ha pasado el intervalo 'delayEnvioAWS'
  // O si solo quieres enviar cada vez que llegan datos (más simple, pero puede ser muy frecuente):
  // if (newDataReceived && client.connected()) {
  //   publishMessage(receivedDataFromArduino);
  //   newDataReceived = false; // Resetea la bandera
  //   lastPublishMillis = currentMillis; // Actualiza el tiempo del último envío
  // }

  // Publicar con el intervalo 'delayEnvioAWS' usando los últimos datos recibidos
  if (newDataReceived && (currentMillis - lastPublishMillis > delayEnvioAWS) && client.connected()) {
     Serial.println("Intervalo de envío a AWS cumplido Y hay datos nuevos.");
     publishMessage(receivedDataFromArduino); // Publica los últimos datos recibidos
     newDataReceived = false; // Considera si resetear aquí o permitir que se reenvíen los mismos datos
                              // si no llegan nuevos datos del Arduino antes del próximo intervalo.
                              // Para este caso, es mejor que el Arduino envíe con más frecuencia
                              // y el ESP decida cuándo publicar el último set recibido.
     lastPublishMillis = currentMillis;
  } else if (!newDataReceived && (currentMillis - lastPublishMillis > delayEnvioAWS) && client.connected() && receivedDataFromArduino.length() > 0) {
    // Si no hay datos NUEVOS, pero ha pasado el tiempo y tenemos datos ANTERIORES, los reenviamos.
    // Esto asegura que se envíe algo periódicamente incluso si el Arduino no manda nuevos datos por un rato.
    Serial.println("Intervalo de envío a AWS cumplido. Reenviando últimos datos conocidos.");
    publishMessage(receivedDataFromArduino); // Publica los últimos datos recibidos
    lastPublishMillis = currentMillis;
  }
}