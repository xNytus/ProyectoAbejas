// ESP32_SIM7600_AWS_IoT.ino
// Este sketch controla la lectura de sensores y el envío de datos a AWS IoT a través del módulo SIM7600SA
// en una placa ESP32 DEVKIT V1.
// Utiliza la librería TinyGSM para una gestión más robusta de la red y el módulo.

#include <ArduinoJson.h>    // Librería para crear y serializar cargas útiles en formato JSON
#include <HardwareSerial.h> // Necesario para la comunicación serial de hardware con el SIM7600SA
#include <Wire.h>           // Necesario para la comunicación I2C (usado por el sensor SHT4x)
#include "Adafruit_SHT4x.h" // Librería para el sensor de temperatura y humedad SHT4x
#include "DHT.h"            // Librería para el sensor de temperatura y humedad DHT
#include <string.h>         // Utilidades para manejo de cadenas (strlen(), strcpy(), strstr(), memset())
#include <stdlib.h>         // Utilidades para funciones de conversión (atof(), dtostrf())
#include <time.h>           // Para la función time() y struct tm (para obtener la hora de red)

// --- Librerías TinyGSM y PubSubClient para gestión de red y MQTT ---
// ¡Importante! Define el tipo de módem ANTES de incluir TinyGsmClient.h
#define TINY_GSM_MODEM_SIM7600 
#include <TinyGsmClient.h>  // Para manejar el módulo SIM7600SA

// ****************************************************************************************************
// *** ATENCIÓN: SOLUCIÓN DE PROBLEMAS PARA 'TinyGsmClientSecure.h: No such file or directory' ***
// ****************************************************************************************************
// Si estás viendo este error, NO es un problema con el código en sí, sino con la configuración
// de tu entorno de Arduino IDE o la instalación de las librerías.
//
// PASOS A SEGUIR (MUY IMPORTANTE):
// 1.  INSTALA O ACTUALIZA LAS LIBRERÍAS (Gestor de Librerías: Sketch > Incluir Librería > Administrar Librerías...):
//     Asegúrate de que estas 4 librerías estén instaladas y sean las ÚLTIMAS VERSIONES ESTABLES:
//     - TinyGSM
//     - PubSubClient
//     - ArduinoBearSSL
//     - ArduinoMbedTLS
//     (TinyGsmClientSecure.h depende de ArduinoBearSSL y/o ArduinoMbedTLS para la funcionalidad SSL/TLS en ESP32).
//
// 2.  REINICIA EL IDE DE ARDUINO: Después de instalar/actualizar cualquier librería, CIERRA COMPLETAMENTE
//     el IDE de Arduino y vuelve a abrirlo. Esto fuerza al IDE a refrescar su índice de librerías.
//
// 3.  VERIFICA EL PAQUETE DE PLACAS ESP32: Ve a Herramientas > Placa > Gestor de Tarjetas...
//     Busca "ESP32 by Espressif Systems" y asegúrate de tener instalada la ÚLTIMA VERSIÓN ESTABLE.
//     Si tienes una versión muy antigua, desinstálala y vuelve a instalar la más reciente.
//     REINICIA EL IDE DE ARDUINO después de cualquier cambio en el Gestor de Tarjetas.
//
// 4.  CONFIRMA LA PLACA SELECCIONADA: En Herramientas > Placa > ESP32 Arduino, asegúrate de que
//     tu placa ESP32 DevKit V1 esté seleccionada correctamente (ej. "ESP32 Dev Module").
//
// 5.  VERIFICA LA ESTRUCTURA DE CARPETAS (AVANZADO): En tu carpeta de librerías de Arduino
//     (ej. Documentos/Arduino/libraries), asegúrate de que las librerías no estén anidadas
//     incorrectamente (ej. no debe ser "TinyGSM/TinyGSM/src", sino "TinyGSM/src").
// ****************************************************************************************************
#include <TinyGsmClientSecure.h> // Para MQTT sobre SSL/TLS
#include <PubSubClient.h>   // Para el cliente MQTT

// --- Configuración de Pines y Velocidad Serial para el Módulo SIM7600SA ---
// El ESP32 tiene múltiples UARTs de hardware. UART2 (GPIO16 RX, GPIO17 TX) es una buena opción
// para el SIM7600SA para evitar conflictos con el UART0 (USB/depuración).
// Asegúrate de que el SIM7600SA esté alimentado por una fuente externa robusta.
// El ESP32 opera a 3.3V, y la mayoría de los SIM7600SA también usan lógica de 3.3V,
// por lo que no debería ser necesario un nivelador de voltaje para las líneas de datos,
// pero siempre verifica la hoja de datos de tu SIM7600SA.
#define SIM7600_RX_PIN 16 // Pin RX de ESP32 (conecta al TX del SIM7600SA) - UART2 RX
#define SIM7600_TX_PIN 17 // Pin TX de ESP32 (conecta al RX del SIM7600SA) - UART2 TX
#define SIM7600_BAUD_RATE 115200 // Se recomienda 115200 para TinyGSM, pero ajusta si tu módulo usa 9600.

// --- Configuración del Sensor DHT (DHT22 o DHT11) ---
// Se cambió el pin del DHT22 de GPIO2 a GPIO4.
// GPIO2 tiene una función especial durante el arranque del ESP32 que puede interferir con la carga de código.
// GPIO4 es un pin de propósito general más adecuado para este sensor.
#define DHTPIN 4        // Define el pin digital al que está conectado el sensor DHT (GPIO4 en ESP32)
#define DHTTYPE DHT22   // Define el tipo de sensor DHT que estás usando (DHT11, DHT21, DHT22)

// --- Configuración del Sensor SHT41 (Temperatura y Humedad Interior - I2C) ---
// Pines I2C comunes en ESP32.
#define SHT41_SDA_PIN 21 // Pin SDA para I2C (GPIO21 en ESP32)
#define SHT41_SCL_PIN 22 // Pin SCL para I2C (GPIO22 en ESP32)

// --- Objetos Globales de los Sensores ---
DHT dht(DHTPIN, DHTTYPE);      // Crea un objeto DHT para el sensor de humedad y temperatura exterior
Adafruit_SHT4x sht4 = Adafruit_SHT4x(); // Crea un objeto Adafruit_SHT4x para el sensor de humedad y temperatura interior

// --- Variables Globales para Datos de Sensores y Red ---
float h_dht;                               // Almacena el valor de humedad leído del sensor DHT22
float t_dht;                               // Almacena el valor de temperatura leído del sensor DHT22
sensors_event_t humidity_sht, temp_sht;    // Almacena los datos de evento (humedad y temperatura) del sensor SHT4x

String sensor_id_str = "Colmena1";         // Usamos String para el ID del sensor, más fácil de manejar
char fecha[20];                            // Almacena la fecha y hora obtenidas de la red (formato "DD/MM/YYYY HH:MM:SS")
char lat[15];                              // Almacena la latitud obtenida del GPS (formato "-XX.XXXXXX")
char lng[15];                              // Almacena la longitud obtenida del GPS (formato "-XXX.XXXXXX")

// --- Configuración de Temporización para el Envío de Datos ---
const unsigned long publishInterval = 10 * 60 * 1000; // Intervalo de publicación de datos: 10 minutos (en milisegundos)
unsigned long lastPublishMillis = 0; // Almacena el valor de millis() de la última vez que se publicaron datos

// --- Temas de AWS IoT (AWS IoT Core Topics) ---
#define AWS_IOT_PUBLISH_TOPIC   "sensores_colmena/pub" // Tema MQTT al que se publicarán los datos de los sensores
#define AWS_IOT_SUBSCRIBE_TOPIC "sensores_colmena/sub" // Tema MQTT para suscribirse y recibir comandos desde AWS IoT (opcional)

// --- Archivo de Secretos (secrets.h) ---
// Este archivo contiene credenciales sensibles como el APN, el endpoint de AWS IoT y los certificados.
// Es CRÍTICO que el APN (GPRS_APN), usuario (GPRS_USER) y contraseña (GPRS_PASS) sean correctos para tu operador móvil.
// Los certificados (ROOT_CA, CLIENT_CERT, PRIVATE_KEY) NO son usados directamente por este sketch en el ESP32.
// DEBEN ser cargados previamente en el sistema de archivos del SIM7600SA usando comandos AT (ej. AT+CCERTDOWN).
#include "secrets.h"

// --- Objetos Globales para SIM7600SA y MQTT (usando TinyGSM) ---
HardwareSerial sim7600Serial(2); // Usamos UART2 del ESP32 para el SIM7600SA
TinyGsm modem(sim7600Serial); // Objeto TinyGSM para interactuar con el módem
TinyGsmClientSecure client(modem); // Cliente seguro para MQTT sobre TLS
PubSubClient mqttClient(client); // Cliente MQTT

// --- Prototipos de Funciones ---
void getGPSData();
void updateFecha();
void connectAWS();
void publishMessage();
void messageReceived(char *topic, byte *payload, unsigned int length); // Función de callback para mensajes MQTT recibidos

// --- Función para Obtener Datos GPS ---
// Utiliza TinyGSM para obtener la ubicación GPS del módulo.
void getGPSData() {
  Serial.println(F("Obteniendo datos GPS..."));
  // TinyGSM's getGsmLocation puede poblar directamente los arrays de caracteres para latitud y longitud.
  // Asegúrate de que el GPS esté habilitado en el módulo (modem.enableGPS() se llama en connectAWS()).
  if (modem.getGsmLocation(&lat[0], &lng[0])) { // TinyGSM poblará directamente las cadenas lat y lng
    Serial.print(F("Latitud: ")); Serial.println(lat);
    Serial.print(F("Longitud: ")); Serial.println(lng);
  } else {
    Serial.println(F("No se pudo obtener datos GPS o sin fix. Asegúrese de tener vista al cielo."));
    strcpy(lat, "N/A"); // Indica que los datos de latitud no están disponibles
    strcpy(lng, "N/A"); // Indica que los datos de longitud no están disponibles
  }
}

// --- Función para Sincronizar Fecha y Hora desde la Red ---
// Utiliza TinyGSM para obtener la fecha y hora de la red móvil.
void updateFecha() {
  Serial.println(F("Actualizando fecha y hora desde la red..."));
  // TinyGSM's getNetworkTime devuelve una String en formato "YY/MM/DD,HH:MM:SS+/-TZ"
  String networkTimeStr = modem.getNetworkTime();
  if (networkTimeStr.length() > 0) {
    // Parsear la cadena: "YY/MM/DD,HH:MM:SS"
    int year_yy, month, day, hour, minute, second;
    
    // Encontrar la coma para dividir fecha y hora
    int commaIndex = networkTimeStr.indexOf(',');
    if (commaIndex != -1) {
      String datePart = networkTimeStr.substring(0, commaIndex);
      String timePart = networkTimeStr.substring(commaIndex + 1);

      // Parsear fecha (YY/MM/DD)
      sscanf(datePart.c_str(), "%d/%d/%d", &year_yy, &month, &day);
      
      // Parsear hora (HH:MM:SS) - manejar posible offset de zona horaria
      // Buscar el '+' o '-' para la zona horaria
      int tzIndex = timePart.indexOf('+');
      if (tzIndex == -1) tzIndex = timePart.indexOf('-');
      
      if (tzIndex != -1) { // Si existe offset de zona horaria, parsear solo la parte HH:MM:SS
        sscanf(timePart.substring(0, tzIndex).c_str(), "%d:%d:%d", &hour, &minute, &second);
      } else { // No hay offset de zona horaria, parsear toda la parte de la hora
        sscanf(timePart.c_str(), "%d:%d:%d", &hour, &minute, &second);
      }
      
      int year = 2000 + year_yy; // Asumimos año 20xx

      sprintf(fecha, "%02d/%02d/%04d %02d:%02d:%02d", day, month, year, hour, minute, second);
      Serial.print(F("Fecha y Hora: ")); Serial.println(fecha);
    } else {
      Serial.println(F("Error: Formato de fecha/hora inesperado en la respuesta."));
      strcpy(fecha, "N/A"); // Indica que la fecha no está disponible
    }
  } else {
    Serial.println(F("No se pudo obtener fecha y hora de la red."));
    strcpy(fecha, "N/A"); // Indica que la fecha no está disponible
  }
}

// --- Función de Callback para Mensajes MQTT Recibidos ---
// Esta función es llamada por PubSubClient cuando se recibe un mensaje MQTT.
void messageReceived(char *topic, byte *payload, unsigned int length) {
  Serial.print(F("Mensaje MQTT recibido: ["));
  Serial.print(topic);
  Serial.print(F("]: "));
  for (unsigned int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
}

// --- Función para Conectar a la Red y Configurar AWS IoT para SIM7600SA ---
// Inicializa el módulo SIM7600SA, se conecta a la red móvil (APN), inicia el GPS,
// y establece la conexión MQTT con AWS IoT Core, todo usando TinyGSM.
void connectAWS() {
  Serial.println(F("Iniciando conexión con SIM7600SA y AWS IoT..."));

  // Iniciar comunicación HardwareSerial con el módulo SIM7600SA
  sim7600Serial.begin(SIM7600_BAUD_RATE, SERIAL_8N1, SIM7600_RX_PIN, SIM7600_TX_PIN);

  Serial.println(F("Iniciando módem..."));
  // TinyGSM's restart() es una forma robusta de inicializar el módem.
  if (!modem.restart()) { 
    Serial.println(F("Error al reiniciar el módem. Intentando inicio completo..."));
    if (!modem.init()) { // Si el reinicio falla, intenta una inicialización completa
      Serial.println(F("FATAL: Error al inicializar el módem. Verifique el cableado y la alimentación."));
      while (true); // Bloquea el programa si no se puede inicializar el módem
    }
  }
  Serial.println(F("Módem inicializado."));

  // --- Verificaciones de Red ---
  Serial.println(F("Comprobando SIM..."));
  if (modem.getSimStatus() != SIM_READY) {
    Serial.println(F("SIM no está lista. Verifique PIN o SIM."));
    while (true);
  }
  Serial.println(F("SIM lista."));

  Serial.println(F("Registrando en la red móvil..."));
  if (!modem.waitForNetwork(60000L)) { // Espera hasta 60 segundos por la red
    Serial.println(F("Error: No se pudo registrar en la red móvil."));
    while (true);
  }
  Serial.println(F("Registrado en la red."));

  // **DIAGNÓSTICO ADICIONAL DE RED:** Calidad de la señal y operador
  int csq = modem.getSignalQuality();
  Serial.print(F("Calidad de la señal (CSQ): ")); Serial.print(csq); Serial.println(" (0-31)");
  String operatorName = modem.getOperator();
  Serial.print(F("Operador de red: ")); Serial.println(operatorName);

  Serial.println(F("Conectando GPRS..."));
  // TinyGSM maneja la activación del contexto PDP y la autenticación automáticamente
  // con los parámetros GPRS_APN, GPRS_USER, GPRS_PASS de secrets.h.
  if (!modem.gprsConnect(GPRS_APN, GPRS_USER, GPRS_PASS)) {
    Serial.println(F("Error: Falló la conexión GPRS. Verifique APN, usuario y contraseña."));
    while (true);
  }
  Serial.println(F("GPRS conectado."));
  
  // Imprime la IP asignada
  String ip = modem.getLocalIP();
  Serial.print(F("IP local: ")); Serial.println(ip);

  // --- Configuración MQTT ---
  Serial.println(F("Configurando conexión MQTT con AWS IoT Core..."));
  client.setCACert(ROOT_CA);
  client.setCertificate(CLIENT_CERT);
  client.setPrivateKey(PRIVATE_KEY);

  mqttClient.setServer(MQTT_HOST, 8883); // Puerto seguro MQTT/TLS
  mqttClient.setCallback(messageReceived); // Establece la función de callback para mensajes entrantes

  Serial.println(F("Intentando conexión MQTT..."));
  if (!mqttClient.connect(THINGNAME)) { // Conecta usando el THINGNAME como Client ID
    Serial.print(F("Error de conexión MQTT. Código de error: "));
    Serial.println(mqttClient.state());
    while (true); // Bloquea si no puede conectar MQTT
  }
  Serial.println(F("Conectado a AWS IoT Core."));

  // Suscribirse a un tema
  mqttClient.subscribe(AWS_IOT_SUBSCRIBE_TOPIC);
  Serial.print(F("Suscrito al tema: ")); Serial.println(AWS_IOT_SUBSCRIBE_TOPIC);

  // Habilitar GPS en el módulo
  modem.enableGPS();
  Serial.println(F("GPS habilitado en el módulo."));

  updateFecha(); // Obtiene fecha/hora inicial al conectar
  getGPSData();  // Obtiene GPS inicial al conectar
}

// --- Función para Publicar Datos de Sensores en AWS IoT ---
// Lee los datos de los sensores, los formatea en JSON y los envía a AWS IoT Core.
void publishMessage() {
  // Asegurarse de que el cliente MQTT esté conectado antes de publicar
  if (!mqttClient.connected()) {
    Serial.println(F("MQTT desconectado. Reintentando reconectar..."));
    if (!mqttClient.connect(THINGNAME)) {
      Serial.print(F("Error de reconexión MQTT. Código de error: ")); Serial.println(mqttClient.state());
      return; // Sale si la reconexión falla
    }
    Serial.println(F("MQTT reconectado."));
    mqttClient.subscribe(AWS_IOT_SUBSCRIBE_TOPIC); // Volver a suscribirse después de reconectar
  }
  
  updateFecha();  // Actualiza fecha/hora antes de publicar
  getGPSData();   // Actualiza GPS antes de publicar

  // Crea la carga útil JSON (payload) para el mensaje MQTT
  StaticJsonDocument<384> doc; // Asigna memoria estáticamente para el documento JSON (384 bytes, ajustable si es necesario)
  doc["sensorId"] = sensor_id_str; // Añade el ID del sensor
  doc["fechaHora"] = fecha;    // Añade la fecha y hora
  doc["humExt"] = h_dht;       // Añade la humedad exterior
  doc["tempExt"] = t_dht;       // Añade la temperatura exterior
  doc["humInt"] = humidity_sht.relative_humidity; // Añade la humedad interior
  doc["tempInt"] = temp_sht.temperature;         // Añade la temperatura interior
  doc["lat"] = lat;             // Añade la latitud
  doc["lng"] = lng;             // Añade la longitud

  char jsonBuffer[512]; // Buffer para almacenar la cadena JSON serializada (512 bytes)
  serializeJson(doc, jsonBuffer, sizeof(jsonBuffer)); // Serializa el documento JSON al buffer

  Serial.print(F("Preparando mensaje para publicar: "));
  Serial.println(jsonBuffer); // Imprime el JSON en el Monitor Serial para depuración

  // Publica el mensaje MQTT usando el cliente PubSubClient
  if (mqttClient.publish(AWS_IOT_PUBLISH_TOPIC, jsonBuffer)) {
    // Si la publicación fue exitosa, imprime los valores de los sensores y una confirmación
    Serial.print(F("Humedad Ext: ")); Serial.print(h_dht); Serial.print(F("%  Temperatura Ext: ")); Serial.print(t_dht); Serial.println(F("°C"));
    Serial.print(F("Humedad Int: ")); Serial.print(humidity_sht.relative_humidity); Serial.print(F("%  Temperatura Int: ")); Serial.print(temp_sht.temperature); Serial.println(F("°C"));
    Serial.print(F("Latitud: ")); Serial.print(lat); Serial.print(F(" Longitud: ")); Serial.println(lng);
    Serial.println(F("Datos enviados correctamente."));
  } else {
    Serial.print(F("Error de envío MQTT. Código de error: ")); Serial.println(mqttClient.state());
  }
}

// --- Función Setup (se ejecuta una vez al inicio del Arduino) ---
void setup() {
  // Inicializa el puerto Serial para la depuración en el PC (Monitor Serial) a 115200 baudios.
  // ¡Asegúrate de configurar también el Monitor Serial del IDE a 115200 baudios!
  Serial.begin(115200); 
  while (!Serial); // Espera a que el puerto serial se conecte (útil para placas con USB nativo como ESP32)
  delay(100); // Pequeño retraso inicial
  Serial.println(F("Iniciando sistema ESP32 + Sensores + SIM7600SA para AWS IoT..."));

  // Inicializa los sensores conectados
  dht.begin(); // Inicia la comunicación con el sensor DHT
  Wire.begin(SHT41_SDA_PIN, SHT41_SCL_PIN); // Inicia la comunicación I2C en los pines específicos, necesaria para el sensor SHT4x
  if (!sht4.begin()) { // Intenta iniciar el sensor SHT4x
    Serial.println(F("Error: No se encontró el sensor SHT41. Verifique el cableado I2C."));
    while (1) delay(1); // Detiene el programa indefinidamente si el SHT4x no se detecta
  }
  Serial.println(F("Sensor SHT41 encontrado."));
  Serial.println(F("Sensor DHT22 encontrado."));
  Serial.print(F("ID del sensor: "));
  Serial.println(sensor_id_str); // Muestra el ID configurado para el sensor

  // Llama a la función para conectar a AWS IoT, que a su vez inicializa el módulo SIM7600SA y la conexión de red.
  connectAWS();
}

// --- Función Loop (se ejecuta repetidamente después del setup) ---
void loop() {
  // Procesar mensajes MQTT entrantes y mantener la conexión.
  // Es CRÍTICO llamar a mqttClient.loop() con frecuencia.
  if (!mqttClient.connected()) {
    Serial.println(F("MQTT desconectado en loop. Reintentando reconectar..."));
    connectAWS(); // Reestablece la conexión completa si se pierde
  }
  mqttClient.loop(); // Debe ser llamado frecuentemente para procesar mensajes MQTT y mantener la conexión activa

  // Lee los datos de los sensores en cada iteración del loop
  h_dht = dht.readHumidity(); // Lee la humedad del DHT22
  t_dht = dht.readTemperature(); // Lee la temperatura del DHT22
  sht4.getEvent(&humidity_sht, &temp_sht); // Obtiene los eventos de humedad y temperatura del SHT4x

  // Verifica si hay errores en la lectura del sensor DHT22 (NaN = Not a Number)
  if (isnan(h_dht) || isnan(t_dht)) {
    Serial.println(F("Error de lectura en el DHT22. Reintentando..."));
    // No se usa 'return' aquí; el loop continuará y podría obtener lecturas válidas en la siguiente iteración
  }

  // Verifica si ha pasado suficiente tiempo para la próxima publicación.
  if (millis() - lastPublishMillis > publishInterval) {
    lastPublishMillis = millis(); // Actualiza el tiempo de la última publicación
    publishMessage(); // Llama a la función para leer sensores, formatear JSON y publicar
  }

  // Pequeño retardo para no saturar el loop
  delay(100); 
}
