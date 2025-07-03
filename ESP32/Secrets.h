#include <pgmspace.h>

#define SECRET

// --- Configuración de Red Móvil (para SIM7600SA con TinyGSM) ---
// Estas variables se refieren a la configuración de la red de datos móvil (celular).
// GPRS_APN: El nombre del punto de acceso (APN) de tu operador móvil.
// GPRS_USER: El nombre de usuario del APN (deja vacío "" si no es requerido).
// GPRS_PASS: La contraseña del APN (deja vacío "" si no es requerida).
//
// Es CRÍTICO que el APN, usuario y contraseña sean correctos para TU operador móvil y TU plan.
// La librería TinyGSM intentará manejar la autenticación PAP automáticamente si se proporcionan
// los valores correctos o si se dejan vacíos según lo requiera tu operador.
//
// Según la información de Entel, el APN es "bam.entelpcs.cl" y el tipo de autenticación es PAP.
// Para PAP, a menudo el usuario y la contraseña se dejan vacíos.
//
// Ejemplos de APN comunes en Chile:
// - Entel: "bam.entelpcs.cl"
// - Movistar: "movistar.cl" o "internet.movistar.cl"
// - Claro: "clarochile.cl" o "internet.claro.cl"
// - WOM: "mms.wom.cl" o "internet.wom.cl"
//
// Si no estás seguro de tu APN o credenciales, consulta la página web de tu operador o su soporte técnico.
const char GPRS_APN[]  = "bam.entelpcs.cl";       // ¡APN confirmado por Entel!
const char GPRS_USER[] = "";                      // Dejar vacío para autenticación PAP sin usuario explícito
const char GPRS_PASS[] = "";                      // Dejar vacío para autenticación PAP sin contraseña explícita

#define THINGNAME "sensor_colmena_01" // Nombre de tu Thing de AWS IoT

// --- Zona Horaria ---
// Se utiliza para la conversión de la hora local si analizas la hora de red en formato UTC.
int8_t TIME_ZONE = -4; // Para Chile, ajusta según sea necesario

// --- Endpoint de AWS IoT Core ---
const char MQTT_HOST[] = "a3n8687rz6kzhp-ats.iot.us-east-2.amazonaws.com"; // Tu endpoint de AWS IoT

// --- Certificados de AWS IoT (Para carga en SIM7600SA) ---
// IMPORTANTE: Estos certificados NO son utilizados directamente por este sketch en el ESP32.
// El módulo SIM7600SA maneja la conexión TLS internamente.
// Los certificados (CA Root, Certificado de Dispositivo, Clave Privada)
// DEBEN ser cargados previamente en el sistema de archivos interno del módulo SIM7600SA
// (ej. como "ca.crt", "client.crt", "client.key") utilizando comandos AT específicos
// (como AT+CCERTDOWN). Este sketch asume que ya están cargados y configurados con un ID de contexto SSL (ej. ID 1) en el SIM7600SA.

// Tu Certificado CA Raíz de AWS
static const char ROOT_CA[] PROGMEM = R"EOF(
-----BEGIN CERTIFICATE-----
MIIDQTCCAimgAwIBAgITBmyfz5m/jAo54vB4ikPmljZbyjANBgkqhkiG9w0BAQsF
ADA5MQswCQYDVQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6
b24gUm9vdCBDQSAxMB4XDTE1MDUyNjAwMDAwMFoXDTM4MDExNzAwMDAwMFowOTEL
MAkGA1UEBhMCVVMxDzANBgVQQUbHrQgLKm+a/sRxmPUDgH3KKHOVj4utWp+UhnMJbulHheb4mjUcAwhmahRWa6
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
-----END CERTIFICATE-----
)EOF";

// Tu Certificado de Dispositivo AWS IoT
static const char CLIENT_CERT[] PROGMEM = R"KEY(
-----BEGIN CERTIFICATE-----
MIIDWjCCAkKgAwIBAgIVAOmDR64HrnLX2LoEsUo3taRt2IOWMA0GCSqGSIb3DQEB
CwUAME0xSzBJBgNVBAsMQkFtYXpvbiBXZWIgU2VydmljZXMgTz1BbWF6b24uY29t
IEluYy4gTD1TZWF0dGxlIFNUPVdhc2hpbmd0b24gQz1VUzAeFw0yNTA0MTAwMDEx
MzRaFw00OTEyMzEyMzU5NTlaMB4xHDAaBgNVBAMME0FXUyBJb1QgQ2VydGlmaWNh
dGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC291jcA7iI4p2xW+d5
O2bIDWK9DuAS88ou+w2HSIFWOeVJ5hgS/K/DT5ziKf8DlZnYCWwYzsy91b4s8vLl
AGKzTZg1Pqem35F/zZIi5CMLcuWDdnvKFmY1uc7TjxGr+oWaqL54L88bwwrWi6wE
PEwRoESbzKQ+iKC/1Gkg3gI6frSVpr061xXEy0rhIPWd/Uc+dBTcNRw2IVKUdMWd
j2KTBZAjPeFXKrZ1A8rady4grRcYCN44VnuvE4BxbkehllOFia7bnmS40nOhK4AT
f8SiXk+sj7h+5J3EeKtLbR/CHLAkPvTxi66r/h4g+gF61kNqQ/5MfK3X2b0NwbYH
RscNAgMBAAGjYDBeMB8GA1UdIwQYMBaAFM85HtE/XjMs//zQqhRZ68XpeHV8MB0G
A1UdDgQWBBTrbI4miF7CbMcgCq7KLTLc0GIfjjAMBgNVHRMBAf8EAjAAMA4GA1Ud
DwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAQEAWaDG9rlWgyBcVABzi1WGaG6B
UrIKGjaE7NZ8Tr64RC15ChHU51v+SmQJD3hwljKHcZ2pDM0VMsVWlX7sakVmhBdK
yDPl1G4JDFzvRE2To7mTL0AVrT/VSkcrxpoNaBeOF6QVeT4V+NmeQviJ9T01oDi/
oiv6/+0wulbvAOBHTIbGfLyO1g0dGMBC8+TqXH2QjEaoY9YyhW5/DzvE0Jdk5pYp
Qi08M2Io2SUFn6if0U9tGUFDyrqzqxN5k4upatpFZMzcMN/NPy4PCLBBufRwSaXh
49VlNIB3hHUC0Ontmx4lrEwjGKYQfMJvw105NHA5ZWxpnKtnJjZV5gZiIUv8MQ==
-----END CERTIFICATE-----
)KEY";

// Tu Clave Privada de Dispositivo AWS IoT
static const char PRIVATE_KEY[] PROGMEM = R"KEY(
-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEAtvdY3AO4iOKdsVvneTtmyA1ivQ7gEvPKLvsNh0iBVjnlSeYY
Evyvw0+c4in/A5WZ2AlsGM7MvdW+LPLy5QBis02YNT6npt+Rf82SIuQjC3Llg3Z7
yhZmNbnO048Rq/qFmqi+eC/PG8MK1ousBDxMEaBEm8ykPoigv9RpIN4COn60laa9
OtcVxMtK4SD1nf1HPnQU3DUcNiFSlHTFnY9ikwWQIz3hVyq2dQPK2ncuIK0XGAje
OFZ7rxOAcW5HoZZThYmu255kuNJzoSuAE3/Eol5PrI+4fuSdxHirS20fwhywJD70
8Yuuq/4eIPoBetZDakP+THyt19m9DcG2B0bHDQIDAQABAoIBAQCIrC2hc9oVzooT
IV7AbYHycCVQqlrxbVCbVYeehaevfGHtmMZk8IJut/qt6scGq2qXOTqZMWk5aP+9
XeHY9DfGTnEjXOEpQxnRyQKfs6EF/Va6o/gGVkMVYO3BlL6To/jHNcPJzZS83S4s
Y3skUtJT3E9DvlL2L2M8yHObTJuHizjJjzlyA/H3sO7dckvY1OuOiVHzaJUmrUUv
QJpvgNRBqsqihjzQIpHUzA2sdZVYTTVuwfUvzk5N/GbrTr3SlBH9Wq09iwInhdsX
FmKLwI8lDKLuKx1IBzc9FRbXJNvG4wYBw/4YyIozhHtvGFi6/hX1VpTvOM0t3moM
+Lu50zLBAoGBAOFtcsN1W6jynAZJ+AZtmg75MS7rQUo3JmCsoWwhArS36gfrKiIw
rYAcMhGC+W6fRPVglTVysWtO9vUBUn6oI5wGI1pmp2Re/1R9vJ+TBSba2MPHRp3z
2cKKZ6663OUNRusY+X6lqD3sZDlPIsW0Wgg4a528H6lnP5Rnr8LU63txAoGBAM/H
skYEunbbom4CfCw0J2UJQCfPkNpfOniaqyH4x8rULFpopxc3BFOxGyFdikdKNsNq
vcOMGVjnj88p/EnROEAVpO6QH96v6MSH3/exbLJNGY/K4J1mc1C3jU2OBK+iezRC
//nZ1ZEzfTjMkh5tQOu9FoaiWn6mb0S/uI6LrF9dAoGBAKcVV02WK6TyhUCIDMS+
8cQNYS30gsT+UXywF0kswnOuKVFLNUR4LfDZdSbTnAspE5SHzK/73ZK6yYJZQ4rL
FvGq/wMfOQzE+JzoQSlJcDUXWjjp9+ZU+l8d9LFmoRlImPrh3PLI2AVls/diN1Sw
U1bqcqFL8W+/LjnSDEztQciRAoGBALqPd4Ze4H2wH1vfZ1bZTTXu5GfaexlXv8xi
M55BHkMD1v8mUEEL6RqsPsvqjSoNfLZhtRlLRcqdmJZOAHTXIkaIKJr7VWJBWCJ+
TZ688/f0Oitd4efyAUBMTtd/2L1Kio0WS3gvGw9Qx/Kj297uAgiosv0X8WEeV3HH
IxL6Xj8RAoGAJVQtUJRaTtp07UCaYXqFLsHURnMgN6RQF6q0VrusvCDFkiS3KDfl
jVSkBK4mheqe+1qIXygyaNBEknDLqaKKwD+dYTjJQTGGupkV12rYY6A7adUSdM3qr
rXsdxR7wQfpX2v2tnhINwvvw8bhMfmtw2YuZOe8NdKosWgMLFOmdlFA=
-----END RSA PRIVATE KEY-----
)KEY";
