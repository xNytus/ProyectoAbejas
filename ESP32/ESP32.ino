#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include <Wire.h>
#include "Adafruit_SHT4x.h"
#include "DHT.h"

#define TIME_ZONE -4 
#define DHTPIN D5       // Digital pin connected to the DHT sensor
#define DHTTYPE DHT22   // DHT 11

const char WIFI_SSID[] = "Farias";               //TAMIM2.4G
const char WIFI_PASSWORD[] = "ssbb1997!";           //0544287380
 
#define THINGNAME "sensor_colmena_01"
 
 
const char MQTT_HOST[] = "axm2l7b2uk1lk-ats.iot.us-east-2.amazonaws.com";
 
 
static const char cacert[] PROGMEM = R"EOF(-----BEGIN CERTIFICATE-----
MIIDQTCCAimgAwIBAgITBmyfz5m/jAo54vB4ikPmljZbyjANBgkqhkiG9w0BAQsF
ADA5MQswCQYDVQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6
b24gUm9vdCBDQSAxMB4XDTE1MDUyNjAwMDAwMFoXDTM4MDExNzAwMDAwMFowOTEL
MAkGA1UEBhMCVVMxDzANBgNVBAoTBkFtYXpvbjEZMBcGA1UEAxMQQW1hem9uIFJv
b3QgQ0EgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALJ4gHHKeNXj
ca9HgFB0fW7Y14h29Jlo91ghYPl0hAEvrAIthtOgQ3pOsqTQNroBvo3bSMgHFzZM
9O6II8c+6zf1tRn4SWiw3te5djgdYZ6k/oI2peVKVuRF4fn9tBb6dNqcmzU5L/qw
IFAGbHrQgLKm+a/sRxmPUDgH3KKHOVj4utWp+UhnMJbulHheb4mjUcAwhmahRWa6
VOujw5H5SNz/0egwLX0tdHA114gk957EWW67c4cX8jJGKLhD+rcdqsq08p8kDi1L
93FcXmn/6pUCyziKrlA4b9v7LWIbxcceVOF34GfID5yHI9Y/QCB/IIDEgEw+OyQm
jgSubJrIqg0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMC
AYYwHQYDVR0OBBYEFIQYzIU07LwMlJQuCFmcx7IQTgoIMA0GCSqGSIb3DQEBCwUA
A4IBAQCY8jdaQZChGsV2USggNiMOruYou6r4lK5IpDB/G/wkjUu0yKGX9rbxenDI
U5PMCCjjmCXPI6T53iHTfIUJrU6adTrCC2qJeHZERxhlbI1Bjjt/msv0tadQ1wUs
N+gDS63pYaACbvXy8MWy7Vu33PqUXHeeE6V/Uq2V8viTO96LXFvKWlJbYK8U90vv
o/ufQJVtMVT8QtPHRh8jrdkPSHCa2XV4cdFyQzR1bldZwgJcJmApzyMZFo6IQ6XU
5MsI+yMRQ+hDKXJioaldXgjUkK642M4UwtBV8ob2xJNDd2ZhwLnoQdeXeGADbkpy
rqXRfboQnoZsG4q5WTP468SQvvG5
-----END CERTIFICATE-----)EOF";
 
 
// Copy contents from XXXXXXXX-certificate.pem.crt here ▼
static const char client_cert[] PROGMEM = R"KEY(-----BEGIN CERTIFICATE-----
MIIDWTCCAkGgAwIBAgIUFoxcQmH9tFudX2C7J6V5Rnq5+RAwDQYJKoZIhvcNAQEL
BQAwTTFLMEkGA1UECwxCQW1hem9uIFdlYiBTZXJ2aWNlcyBPPUFtYXpvbi5jb20g
SW5jLiBMPVNlYXR0bGUgU1Q9V2FzaGluZ3RvbiBDPVVTMB4XDTI1MDQwODAyMzE1
NFoXDTQ5MTIzMTIzNTk1OVowHjEcMBoGA1UEAwwTQVdTIElvVCBDZXJ0aWZpY2F0
ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL6X49TSF+6KbBwlrtvB
dYAt4wlNcrF0EK7Wl/+b4Klm2XTiyI28nv8alYQ0EPFeOS9koWYsJKBkrau9XTMD
ap84jfrHXo2z0elg6JOIb5hpaEzi0AWhxkxxCxXzySWxrIIkmDbFNkZukW1Y7sN2
rkrU+s13eGE8d/XVJt4dLciWzxVxBMSvtKouJj+89U0XkU3aXHdJiebrpnYY+w90
lOigPpmsfRUrpEyrUzGnXbhuBQbfXT23kUAeznPh7fw48ybiWo8bP+nlCyMP4Dlj
a1TNowc5PNV9K1dQUMXx00l1mGqcaduN6Ig+ez2iCNDRNiE57W51wexnASPWFo5M
2ykCAwEAAaNgMF4wHwYDVR0jBBgwFoAUAyhsgqHnQxlwni+10MHmVtJV1ykwHQYD
VR0OBBYEFAymR6pA19txPALv9+9GGMh6gukNMAwGA1UdEwEB/wQCMAAwDgYDVR0P
AQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IBAQCcPunj6KA6mP1UlUofX9l6JLAK
5UgSJuvJsetXi1uGg588AHS28bVcQXYQrSos73dpYc3qhKohmedF19jbD0j54aHl
P/Xpea/tWy+2Tqa6ixQD+KzO2tMFBiOEtvgWk4YYtzmZCWuX4qGmHMvrvIzyd9cd
rVDYxQiZ4+m3ryUPkRAagQltouc4+GDZeyrjAOGH4Wz1toNJvPPaXiY/vC1ilU4W
JWOX83L0Ak1TgQzq0+MExzweZXdJryw7P5toHQPUXZgrpFlWoqcmrRoRi9XOFbAd
ITyKgW3fEDpbSwsRO1NNfPZ0/U9fE9CnT7vgO4LmgQh3hFxJx/CO3aKtjLON
-----END CERTIFICATE-----)KEY";
 
 
// Copy contents from  XXXXXXXX-private.pem.key here ▼
static const char privkey[] PROGMEM = R"KEY(-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAvpfj1NIX7opsHCWu28F1gC3jCU1ysXQQrtaX/5vgqWbZdOLI
jbye/xqVhDQQ8V45L2ShZiwkoGStq71dMwNqnziN+sdejbPR6WDok4hvmGloTOLQ
BaHGTHELFfPJJbGsgiSYNsU2Rm6RbVjuw3auStT6zXd4YTx39dUm3h0tyJbPFXEE
xK+0qi4mP7z1TReRTdpcd0mJ5uumdhj7D3SU6KA+max9FSukTKtTMadduG4FBt9d
PbeRQB7Oc+Ht/DjzJuJajxs/6eULIw/gOWNrVM2jBzk81X0rV1BQxfHTSXWYapxp
243oiD57PaII0NE2ITntbnXB7GcBI9YWjkzbKQIDAQABAoIBAHjD2XLiZJObVgFH
x1IrdP5xFOiyEDhsqJ2AD/PAm0v7hVJQ2G8m00AlYhPQweOOpoFnK/WHhvWylXC6
njFSut6EgUIjzb/P7vQHmZbR3pQeRh5hoRnQdcu93R5dyFiACiS0d1ZNA6UBLliw
/ykPLETySrCiQL6sB/7WvrgCmR39iBM11NQZILGpH8yw2tuCAVSWgSYx8EYf9YXZ
x1NcerKU/eLBMCAoXyoBcZKYeOTV2NoSvC7jV6B2muU1GBVVA21CcMPdYiIQUIVB
YaFHlOK31q6qDpQoT9F+RX/X9l0N8eHpXlUOjM8JMWKCb/JgBWML+zH5lXPA7Jdo
co+FatkCgYEA7vH1Au8Nw5V+FFp7tSyt1Qj9qInuKs/ETwwY4bB0s+gNqSSBPOGG
WTGHdlQ2ezTpq+f+cClaCzRZzv8Kkw/3RQ5n4v5tcmiF1HtJGcZpMwwhp5tJkJjs
9I/FjOnOhXM1OUXi5sMtL47w+yGRmTm/N2235FlDb2EnjJ0Etl6AUWsCgYEAzDJw
2T7th57kQ7h+izlgDS9GIpTMgVRU828u4f3hWbPlhbbd7SD2ljc8TXvKQMpSSrIJ
BTxQ9ODPyk33SxOhcIg4+/iaupUx+PXo72RJDfEtI31j8iHD/HlPXf3pfTnJX2c8
OrFrhi2ngQxrQ/NYbFeLkJXs5dmc1m8jepjSprsCgYBOdCcsNW1hgF4LNMJVdDwH
LJKMme0XJWyhP6mTwKowv8psdM3yPWItOvPtSC0zOuZWSS/jh9BGyYOLUXYZXy6i
/93gTAWHgQYgA/K2gczcs+kA7R20WmHC0sncQJBMhM0+5tFfT0owyVAaRKVXl/xO
qLmuQhjAIzgnFQ8NCe47zQKBgQC2XW4Pd3Xno241VPYfHRS9cbTveXjTIB/mcSur
xXOXC2U28ERvXPsc2SPQB3hwOMEZ2LrZpC6hJI4vHUZ4FIYf3GkYD8UQUeKZd/Wa
pzPfcb9gbMHwI1vHhgft57C5l/xSaf6OZJmk8e0hAZhizVfxGpaYgG1cMecyU3ua
KBYptQKBgQC0EqEsaBgbwJPA48twtK3DxVygqiH3yQCsIENYBDjvENd0gFrUeDpP
bvYmRHMuvPqXr66c7mVihxVW5bL+jYwjViGUhamP1m0TWtwyXI+7CzxOt1I2L1iz
k5CQmvpJIvSozVuE+kRWeO77w/OC5ys9zdgRlZ9KNvvDRB3amNamWw==
-----END RSA PRIVATE KEY-----)KEY";

DHT dht(DHTPIN, DHTTYPE);
Adafruit_SHT4x sht4 = Adafruit_SHT4x();
 
float h ;
float t;
int sensor_id = ESP.getChipId();
unsigned long lastMillis = 0;
unsigned long previousMillis = 0;
const long interval = 1000;
 
#define AWS_IOT_PUBLISH_TOPIC   "sensores/colmena"
#define AWS_IOT_SUBSCRIBE_TOPIC "sensores/colmena"
 
WiFiClientSecure net;
 
BearSSL::X509List cert(cacert);
BearSSL::X509List client_crt(client_cert);
BearSSL::PrivateKey key(privkey);
 
PubSubClient client(net);
 
time_t now;
time_t nowish = 1510592825;
sensors_event_t humidity, temp;

 
void NTPConnect(void)
{
  Serial.print("Setting time using SNTP");
  configTime(TIME_ZONE * 3600, 0 * 3600, "pool.ntp.org", "time.nist.gov");
  now = time(nullptr);
  while (now < nowish)
  {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println("done!");
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);
  Serial.print("Current time: ");
  Serial.print(asctime(&timeinfo));
}
 
 
void messageReceived(char *topic, byte *payload, unsigned int length)
{
  Serial.print("Received [");
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
  delay(10000);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
 
  Serial.println(String("Attempting to connect to SSID: ") + String(WIFI_SSID));
 
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
 
 
  Serial.println("Connecting to AWS IOT");
 
  while (!client.connect(THINGNAME))
  {
    Serial.print(".");
    delay(1000);
  }
 
  if (!client.connected()) {
    Serial.println("AWS IoT Timeout!");
    return;
  }
  // Subscribe to a topic
  client.subscribe(AWS_IOT_SUBSCRIBE_TOPIC);
 
  Serial.println("AWS IoT Connected!");
}
 
 
void publishMessage()
{
  StaticJsonDocument<300> doc;
  doc["sensor_id"] = sensor_id; 
  doc["hum_ext"] = h;
  doc["temp_ext"] = t;
  doc["hum_int"] = humidity.relative_humidity;
  doc["temp_int"] = temp.temperature;
  doc["lat"] = -32.901757;
  doc["lng"] = -71.227288;
  
  char jsonBuffer[512];
  serializeJson(doc, jsonBuffer);

  client.publish(AWS_IOT_PUBLISH_TOPIC, jsonBuffer);
}

 
 
void setup()
{
  Serial.begin(115200);
  Wire.begin();
  connectAWS();
  dht.begin();
  if(!sht4.begin()){
    Serial.println("No se encontro el sensor SHT41");
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

  sensors_event_t humidity, temp;
  sht4.getEvent(&humidity, &temp);
 
  if (isnan(h) || isnan(t)) {
    Serial.println(F("Failed to read from DHT sensor!"));
    return;
  }

  Serial.print("Humedad Ext: ");
  Serial.print(h);
  Serial.print("%  Temperatura Ext: ");
  Serial.print(t);
  Serial.println("°C");

  Serial.print("Humedad Int: ");
  Serial.print(humidity.relative_humidity);
  Serial.print("%  Temperatura Int: ");
  Serial.print(temp.temperature);
  Serial.println("°C");

  unsigned long currentMillis = millis();
  if (currentMillis - lastMillis >= interval) {
    lastMillis = currentMillis;
    publishMessage();
  
  }
  delay(interval);
  client.loop();
}
