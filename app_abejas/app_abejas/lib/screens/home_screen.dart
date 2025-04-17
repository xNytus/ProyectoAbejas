import 'package:app_abejas/screens/detalles_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late GoogleMapController mapController;
  Sensor? sensorSeleccionado;

  final List<Sensor> sensores = [
    Sensor(
      nombre: 'Sensor 1',
      ubicacion: LatLng(-32.901757, -71.227288),
      temperaturaExt: [25, 26, 27, 28],
      temperaturaInt: [35, 36, 37, 38],
      humedadExt: [50, 55, 54, 57],
      humedadInt: [70, 70, 74, 75],
      color: Colors.red,
    ),
    Sensor(
      nombre: 'Sensor 2',
      ubicacion: LatLng(-32.901640, -71.226836),
      temperaturaExt: [30, 28, 29, 31],
      temperaturaInt: [35, 36, 37, 38],
      humedadExt: [50, 55, 54, 57],
      humedadInt: [70, 70, 74, 75],
      color: Colors.green,
    ),
    Sensor(
      nombre: 'Sensor 3',
      ubicacion: LatLng(-32.902047, -71.227144),
      temperaturaExt: [25, 26, 24, 27],
      temperaturaInt: [30, 32, 33, 31],
      humedadExt: [50, 55, 54, 57],
      humedadInt: [70, 70, 74, 75],
      color: Colors.blue,
    ),
  ];

  Set<Marker> get _crearMarcadores {
    return sensores.map((sensor) {
      return Marker(
        markerId: MarkerId(sensor.nombre),
        position: sensor.ubicacion,
        infoWindow: InfoWindow(title: sensor.nombre),
        icon: BitmapDescriptor.defaultMarkerWithHue(_colorToHue(sensor.color)),
      );
    }).toSet();
  }

  double _colorToHue(Color color) {
    if (color == Colors.red) return BitmapDescriptor.hueRed;
    if (color == Colors.green) return BitmapDescriptor.hueGreen;
    if (color == Colors.blue) return BitmapDescriptor.hueBlue;
    return BitmapDescriptor.hueAzure;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa Sensores')),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: GoogleMap(
              mapType: MapType.satellite,
              initialCameraPosition: CameraPosition(
                target: sensores[0].ubicacion,
                zoom: 16,
              ),
              markers: _crearMarcadores,
              onMapCreated: (controller) {
                mapController = controller;
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: sensores.length,
                    itemBuilder: (context, index) {
                      final sensor = sensores[index];
                      return ListTile(
                        leading: Icon(Icons.location_on, color: sensor.color),
                        title: Text(sensor.nombre),
                        trailing: IconButton(
                          icon: Icon(Icons.arrow_forward),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => detalles_screen(sensor: sensor),
                              ),
                            );
                          },
                        ),
                        onTap: () {
                          setState(() {
                            sensorSeleccionado = sensor;
                          });
                          mapController.animateCamera(
                            CameraUpdate.newLatLngZoom(sensor.ubicacion, 19),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (sensorSeleccionado != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('temperaturaExt de ${sensorSeleccionado!.nombre}'),
                  ),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: true),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: sensorSeleccionado!.temperaturaExt
                                .asMap()
                                .map((index, value) {
                                  return MapEntry(index, FlSpot(index.toDouble(), value));
                                })
                                .values
                                .toList()
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
