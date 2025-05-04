// sensor.dart (CONTENIDO COMPLETO Y CORREGIDO)
import 'package:flutter/material.dart';
// --- ¡ASEGÚRATE DE QUE ESTA LÍNEA SEA LA CORRECTA! ---
import 'package:google_maps_flutter/google_maps_flutter.dart';
// --- FIN DE LA LÍNEA IMPORTANTE ---

class Sensor {
  final String nombre; // Corresponds to sensorId
  final LatLng ubicacion; // Ahora LatLng debería ser reconocido
  final Color color;

  Sensor({
    required this.nombre,
    required this.ubicacion,
  }) : color = _generateColorFromName(nombre); // Genera color en initializer list

  // Factory constructor para parsear JSON para identidad (si lo necesitas)
  factory Sensor.fromJsonIdentificador(Map<String, dynamic> json) {
    return Sensor(
      nombre: json['sensorId'] ?? 'ID Desconocido',
      ubicacion: LatLng( // LatLng usado aquí
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lng'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }

  // Función estática para generar color
  static Color _generateColorFromName(String name) {
    final hash = name.hashCode;
    if (Colors.primaries.isEmpty) return Colors.grey; // Prevención
    return Colors.primaries[hash % Colors.primaries.length];
  }

  // Override equality and hashCode para Sets/Maps
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sensor &&
          runtimeType == other.runtimeType &&
          nombre == other.nombre;

  @override
  int get hashCode => nombre.hashCode;
}