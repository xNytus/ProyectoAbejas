import 'package:intl/intl.dart';

class SensorData {
  final String sensorId;
  final DateTime timestamp; // Changed to DateTime
  final double temperaturaInt;
  final double temperaturaExt;
  final double humedadInt;
  final double humedadExt;
  final double lat; // Añadir latitud
  final double lng; // Añadir longitud

  SensorData({
    required this.sensorId,
    required this.timestamp,
    required this.temperaturaInt,
    required this.temperaturaExt,
    required this.humedadInt,
    required this.humedadExt,
    required this.lat,
    required this.lng,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    final dateFormat = DateFormat("dd/MM/yyyy HH:mm:ss");

    // Función auxiliar para obtener un valor numérico de forma segura,
    // probando con varios nombres de clave posibles.
    double getNumericValue(List<String> possibleKeys) {
      for (final key in possibleKeys) {
        if (json.containsKey(key) && json[key] != null) {
          // Si la clave existe y no es nula, la convierte y la devuelve.
          return (json[key] as num).toDouble();
        }
      }
      // Si no se encuentra ninguna clave válida, devuelve 0.0.
      return 0.0;
    }

    return SensorData(
      sensorId: json['sensorId'] ?? 'ID Desconocido',
      // Safely parse the timestamp. If 'fechaHora' is null, use a default date.
      timestamp: json['fechaHora'] != null
          ? dateFormat.parse(json['fechaHora'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      temperaturaInt: getNumericValue(['tempInt', 'temperatura_int']),
      temperaturaExt: getNumericValue(['tempExt', 'temperatura_ext']),
      humedadInt: getNumericValue(['humInt', 'humedad_int']),
      humedadExt: getNumericValue(['humExt', 'humedad_ext']),
      lat: getNumericValue(['lat', 'latitud']),
      lng: getNumericValue(['lng', 'longitud']),
    );
  }
}