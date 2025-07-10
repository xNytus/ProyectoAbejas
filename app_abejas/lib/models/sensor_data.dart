import 'package:intl/intl.dart';

class SensorData {
  final String sensorId;
  final DateTime timestamp; 
  final double temperaturaInt;
  final double temperaturaExt;
  final double humedadInt;
  final double humedadExt;
  final double lat;
  final double lng;

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
    double getNumericValue(List<String> possibleKeys) {
      for (final key in possibleKeys) {
        if (json.containsKey(key) && json[key] != null) {
          return (json[key] as num).toDouble();
        }
      }
      return 0.0;
    }

    return SensorData(
      sensorId: json['sensorId'] ?? 'ID Desconocido',
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