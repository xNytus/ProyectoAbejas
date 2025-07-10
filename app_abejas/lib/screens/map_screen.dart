import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaExpandidoScreen extends StatelessWidget {
  final LatLng ubicacionInicial;
  final Set<Marker> marcadores;

  const MapaExpandidoScreen({super.key,
    required this.ubicacionInicial,
    required this.marcadores,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa completo')),
      body: GoogleMap(
        mapType: MapType.satellite,
        initialCameraPosition: CameraPosition(
          target: ubicacionInicial,
          zoom: 18,
        ),
        markers: marcadores,
      ),
    );
  }
}
