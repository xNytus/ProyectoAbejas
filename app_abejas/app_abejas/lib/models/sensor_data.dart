// sensor_data.dart (Modificado SIN intl)

// Elimina esta línea: import 'package:intl/intl.dart';

class SensorData {
  final String sensorId;
  final String timestamp; // <--- CAMBIO: de DateTime a String
  final double temperaturaInt;
  final double temperaturaExt;
  final double humedadInt;
  final double humedadExt;

  SensorData({
    required this.sensorId,
    required this.timestamp, // <--- CAMBIO: Acepta String
    required this.temperaturaInt,
    required this.temperaturaExt,
    required this.humedadInt,
    required this.humedadExt,
  });

  // Factory constructor simplificado
  factory SensorData.fromJson(Map<String, dynamic> json) {
    // Asigna directamente el String, con un fallback por si es nulo
    final fechaHoraString = json['fechaHora'] as String? ?? 'Fecha Desconocida';

    return SensorData(
      sensorId: json['sensorId'] ?? 'ID Desconocido',
      timestamp: fechaHoraString, // <--- CAMBIO: Asigna el String directamente
      temperaturaInt: (json['tempInt'] as num?)?.toDouble() ?? 0.0,
      temperaturaExt: (json['tempExt'] as num?)?.toDouble() ?? 0.0,
      humedadInt: (json['humInt'] as num?)?.toDouble() ?? 0.0,
      humedadExt: (json['humExt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}