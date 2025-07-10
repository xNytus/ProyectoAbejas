import 'package:flutter/material.dart';

class MedicionCard extends StatelessWidget {
  final String fecha;
  final double temperatura;
  final double humedad;

  const MedicionCard({super.key, required this.fecha, required this.temperatura, required this.humedad});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Fecha: $fecha'),
        subtitle: Text('Temp: $temperatura°C - Humedad: $humedad%'),
      ),
    );
  }
}
