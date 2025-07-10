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

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      nombre: json['id'] as String,
      ubicacion: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      color: Colors.blueGrey,
    );
  }
  @override
  bool operator ==(Object other) => identical(this, other) || other is Sensor && runtimeType == other.runtimeType && nombre == other.nombre;

  @override
  int get hashCode => nombre.hashCode;
}