#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include <Wire.h>
#include "Adafruit_SHT4x.h"
#include "secrets.h"
#include "DHT.h"
#define TIME_ZONE -4
 
#define DHTPIN D5       
#define DHTTYPE DHT22  
 
DHT dht(DHTPIN, DHTTYPE);
Adafruit_SHT4x sht4 = Adafruit_SHT4x();
 
float h ;
float t;
String sensor_id = "Sensor1" ;
sensors_event_t humidityInt, tempInt;
String fecha; 
unsigned long lastMillis = 0;
unsigned long previousMillis = 0;
const long interval = 5000;
const long delayEnvio = 10*60* 1000;
 
#define AWS_IOT_PUBLISH_TOPIC   "sensores_colmena/pub"
#define AWS_IOT_SUBSCRIBE_TOPIC "sensores_colmena/sub"
 
WiFiClientSecure net;
 
BearSSL::X509List cert(cacert);
BearSSL::X509List client_crt(client_cert);
BearSSL::PrivateKey key(privkey);
 
PubSubClient client(net);
 
time_t now;
time_t nowish = 1510592825;



void updateFecha() {
  time_t now = time(nullptr);
  struct tm timeinfo;
  localtime_r(&now, &timeinfo);

  char timeStr[20];
  strftime(timeStr, sizeof(timeStr), "%d/%m/%Y %H:%M:%S", &timeinfo);

  fecha = String(timeStr);
}



 
void NTPConnect(void)
{
  Serial.print("Configurando tiempo por SNTP");
  configTime(TIME_ZONE * 3600, 0 * 3600, "pool.ntp.org", "time.nist.gov");
  now = time(nullptr);
  while (now < nowish)
  {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println("Terminado");
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);
  char timeStr[20];
  strftime(timeStr, sizeof(timeStr), "%d/%m/%Y %H:%M:%S", &timeinfo);
  Serial.print("Current time: ");
  Serial.print(asctime(&timeinfo));
  fecha = String(timeStr);
}
 
 
void messageReceived(char *topic, byte *payload, unsigned int length)
{
  Serial.print("Recibido [");
  Serial.print(topic);
  Serial.print("]: ");
  for (int i = 0; i < length; i++)
  {
    Serial.print((char)payload[i]);
  }
  Serial.println();
}
 
 
void connectAWS()
{
  delay(3000);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
 
  Serial.println(String("Intentando conectar al SSID: ") + String(WIFI_SSID));
 
  while (WiFi.status() != WL_CONNECTED)
  {
    Serial.print(".");
    delay(1000);
  }
 
  NTPConnect();
 
  net.setTrustAnchors(&cert);
  net.setClientRSACert(&client_crt, &key);
 
  client.setServer(MQTT_HOST, 8883);
  client.setCallback(messageReceived);
 
 
  Serial.println("Conectando a AWS IOT");
 
  while (!client.connect(THINGNAME))
  {
    Serial.print(".");
    delay(1000);
  }
 
  if (!client.connected()) {
    Serial.println("AWS IoT Timeout!");
    return;
  }
  client.subscribe(AWS_IOT_SUBSCRIBE_TOPIC);
 
  Serial.println("AWS IoT Conectado");
}
 
 
void publishMessage()
{
  updateFecha();
  StaticJsonDocument<300> doc;
  doc["sensorId"] = sensor_id;
  doc["fechaHora"] = fecha;  
  doc["humExt"] = h;
  doc["tempExt"] = t;
  doc["humInt"] = humidityInt.relative_humidity;
  doc["tempInt"] = tempInt.temperature;
  doc["lat"] = -32.901757;
  doc["lng"] = -71.227288;

  char jsonBuffer[512];
  serializeJson(doc, jsonBuffer); 
 
  if(client.publish(AWS_IOT_PUBLISH_TOPIC, jsonBuffer)){    
    Serial.print("Humedad Ext: ");
    Serial.print(h);
    Serial.print("%  Temperatura Ext: ");
    Serial.print(t);
    Serial.println("°C");
    Serial.print("Humedad Int: ");
    Serial.print(humidityInt.relative_humidity);
    Serial.print("%  Temperatura Int: ");
    Serial.print(tempInt.temperature);
    Serial.println("°C"); 
    Serial.println("Datos enviados correctamente: ");
    Serial.println(jsonBuffer);
  }else{
    Serial.println("Error de envio");
  }

}
 
 
void setup()
{
  Serial.begin(115200);
  connectAWS();
  dht.begin(); 
  Wire.begin();
  if(!sht4.begin()){
    Serial.println("Error de lectura en el SHT41");
    while(1) delay(1);
  }  
  Serial.println("Sensor SHT41 encontrado");
  Serial.println("Sensor DHT22 encontrado");
  Serial.println(sensor_id);
}
 
 
void loop()
{
  h = dht.readHumidity();
  t = dht.readTemperature();
 
  sht4.getEvent(&humidityInt, &tempInt);
  if (isnan(h) || isnan(t) )  
  {
    Serial.println(F("Error de lectura en el DHT22"));
    return;
  }
 
 
  now = time(nullptr);
 
  if (!client.connected())
  {
    connectAWS();
  }
  else
  {
    client.loop();
    if (millis() - lastMillis > delayEnvio)
    {
      lastMillis = millis();
      publishMessage();
    }
  }
}