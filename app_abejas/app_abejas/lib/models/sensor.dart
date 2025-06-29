import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Sensor {
  final String nombre;
  final LatLng ubicacion;
  final Color color;

  Sensor({
    required this.nombre,
    required this.ubicacion,
    required this.color,
  });

  /// Crea una instancia de Sensor desde un mapa JSON.
  /// Asume que la API devuelve 'id', 'latitud', y 'longitud'.
  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      // Usa 'id' o 'sensorId' según lo que devuelva tu API para la lista de sensores.
      nombre: json['id'] as String,
      ubicacion: LatLng(
        // Se añade `?` para manejar nulos y `??` para dar un valor por defecto.
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      // Puedes asignar un color por defecto o basarlo en alguna lógica.
      color: Colors.blueGrey,
    );
  }

  // Es una buena práctica sobreescribir '==' y 'hashCode' para comparar objetos.
  // Esto es especialmente útil para el DropdownButton y para la lógica de selección.
  @override
  bool operator ==(Object other) => identical(this, other) || other is Sensor && runtimeType == other.runtimeType && nombre == other.nombre;

  @override
  int get hashCode => nombre.hashCode;
}