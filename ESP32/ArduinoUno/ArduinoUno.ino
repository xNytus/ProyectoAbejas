#include <Wire.h>
#include "Adafruit_SHT4x.h" // Asegúrate de tener esta librería
#include "DHT.h"            // Asegúrate de tener esta librería
#include <ArduinoJson.h>    // Asegúrate de tener esta librería
#include <SoftwareSerial.h> // Para comunicación con D1 Mini

// Configuración SoftwareSerial (elige pines que no uses)
// RX del Arduino se conecta al TX del D1 Mini
// TX del Arduino se conecta al RX del D1 Mini
SoftwareSerial espSerial(10, 11); // RX, TX (Arduino pins)

#define DHTPIN A0     // Pin para el DHT22 en el Arduino (usando A0)
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

Adafruit_SHT4x sht4 = Adafruit_SHT4x();

String sensor_id_arduino = "Colmena2";

const long intervalLectura = 5000; // Lee sensores cada 5 segundos
unsigned long previousMillisLectura = 0;

void setup() {
  Serial.begin(115200);     // Para depuración del Arduino Uno
  espSerial.begin(115200);  // Para comunicación con el D1 Mini

  dht.begin();
  Wire.begin(); // Inicia I2C para el SHT4x

  if (!sht4.begin()) {
    Serial.println("Error al iniciar el SHT41. Verifica la conexión I2C.");
    // Puedes decidir si quieres detener el sketch o continuar solo con el DHT
    // while(1) delay(100); // Detiene si el SHT41 es crítico
  } else {
    Serial.println("Sensor SHT41 encontrado e iniciado correctamente.");
  }
  Serial.println("Sensor DHT22 configurado en pin A0.");
  Serial.println("Arduino Uno listo para enviar datos al D1 Mini.");
}

void loop() {
  unsigned long currentMillis = millis();

  if (currentMillis - previousMillisLectura >= intervalLectura) {
    previousMillisLectura = currentMillis;

    float h_dht = dht.readHumidity();
    float t_dht = dht.readTemperature();

    sensors_event_t humidity_sht_event, temp_sht_event; // Nombres de variable diferentes para claridad
    bool sht_ok = false;

    // Intenta leer el sensor SHT4x
    sht4.getEvent(&humidity_sht_event, &temp_sht_event);

    // Verifica si la lectura del SHT4x fue válida (no NaN)
    if (isnan(humidity_sht_event.relative_humidity) || isnan(temp_sht_event.temperature)) {
      Serial.println("Error de lectura en el SHT4x.");
      sht_ok = false;
    } else {
      sht_ok = true;
    }

    // Verifica si la lectura del DHT22 fue válida
    if (isnan(h_dht) || isnan(t_dht)) {
      Serial.println(F("Error de lectura en el DHT22 en A0"));
      // Si el DHT falla, no enviaremos datos en este ciclo.
      // Podrías optar por enviar solo los datos del SHT4x si estuvieran disponibles.
      return;
    }

    // Crear el JSON para enviar al D1 Mini
    StaticJsonDocument<256> doc;
    doc["sensorIdBase"] = sensor_id_arduino;
    doc["humExt"] = h_dht;
    doc["tempExt"] = t_dht;

    if (sht_ok) {
      doc["humInt"] = humidity_sht_event.relative_humidity;
      doc["tempInt"] = temp_sht_event.temperature;
    } else {
      // Si SHT4x falló, puedes enviar un valor nulo, un string de error, o no incluir los campos
      doc["humInt"] = nullptr; // O "error_sht" o simplemente no añadir los campos
      doc["tempInt"] = nullptr; // O "error_sht"
    }

    String outputJson;
    serializeJson(doc, outputJson);

    espSerial.println(outputJson); // Envía el JSON al D1 Mini
    Serial.print("Enviado a D1 Mini: ");
    Serial.println(outputJson);
  }

  // (Opcional) Escuchar respuestas del D1 Mini
  if (espSerial.available()) {
    String responseFromEsp = espSerial.readStringUntil('\n');
    Serial.print("Respuesta del D1 Mini: ");
    Serial.println(responseFromEsp);
  }
}