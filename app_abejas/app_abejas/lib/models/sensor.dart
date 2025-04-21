import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Sensor {
  final String nombre;
  final LatLng ubicacion;
  final List<double> temperaturaExt;
  final List<double> temperaturaInt;
  final List<double> humedadExt;
  final List<double> humedadInt;
  final Color color;

  Sensor({
    required this.nombre,
    required this.ubicacion,
    required this.temperaturaExt,
    required this.temperaturaInt,
    required this.humedadExt,
    required this.humedadInt,
    required this.color,
  });
}
