import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:app_abejas/models/sensor.dart';
import 'package:app_abejas/screens/map_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late GoogleMapController mapController;
  Sensor? sensorSeleccionado;
  late TabController _tabController;

  final List<Sensor> sensores = [
    Sensor(
      nombre: 'Cajon 1',
      ubicacion: LatLng(-32.901757, -71.227288),
      temperaturaExt: [25, 26, 27, 28],
      temperaturaInt: [35, 36, 37, 38],
      humedadExt: [50, 55, 54, 57],
      humedadInt: [70, 70, 74, 75],
      color: Colors.red,
    ),
    Sensor(
      nombre: 'Cajon 2',
      ubicacion: LatLng(-32.901640, -71.226836),
      temperaturaExt: [30, 28, 29, 31],
      temperaturaInt: [35, 36, 37, 38],
      humedadExt: [50, 55, 54, 57],
      humedadInt: [70, 70, 74, 75],
      color: Colors.green,
    ),
    Sensor(
      nombre: 'Cajon 3',
      ubicacion: LatLng(-32.902047, -71.227144),
      temperaturaExt: [25, 26, 24, 27],
      temperaturaInt: [30, 32, 33, 31],
      humedadExt: [50, 55, 54, 57],
      humedadInt: [70, 70, 74, 75],
      color: Colors.blue,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

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

  Widget _buildCombinedChart({
    required String label,
    required List<double> data1,
    required List<double> data2,
    required String label1,
    required String label2,
    required Color color1,
    required Color color2,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: true),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  isCurved: false,
                  color: color1,
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                  spots: data1.asMap().entries.map(
                        (e) => FlSpot(e.key.toDouble(), e.value),
                      ).toList(),
                ),
                LineChartBarData(
                  isCurved: true,
                  color: color2,
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                  spots: data2.asMap().entries.map(
                        (e) => FlSpot(e.key.toDouble(), e.value),
                      ).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendDot(color1, label1),
            const SizedBox(width: 16),
            _buildLegendDot(color2, label2),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de cajones')),
      body: Column(
        children: [
          // Mapa
          Stack(
  children: [
    SizedBox(
      height: 200,
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
    Positioned(
      top: 8,
      right: 8,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MapaExpandidoScreen(
                ubicacionInicial: sensorSeleccionado?.ubicacion ?? sensores[0].ubicacion,
                marcadores: _crearMarcadores,
              ),
            ),
          );
        },
        child: const Icon(Icons.fullscreen, color: Colors.black),
      ),
    ),
  ],
),


          // Dropdown de sensores
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButton<Sensor>(
              hint: const Text('Seleccionar Cajón'),
              isExpanded: true,
              value: sensorSeleccionado,
              items: sensores.map((sensor) {
                return DropdownMenuItem(
                  value: sensor,
                  child: Row(
                    children: [
                      Icon(Icons.sensors, color: sensor.color),
                      const SizedBox(width: 8),
                      Text(sensor.nombre),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (sensor) {
                setState(() {
                  sensorSeleccionado = sensor;
                });
                if (sensor != null) {
                  mapController.animateCamera(
                    CameraUpdate.newLatLngZoom(sensor.ubicacion, 18),
                  );
                }
              },
            ),
          ),

          // Pestañas y datos
          if (sensorSeleccionado != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Datos de ${sensorSeleccionado!.nombre}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Temperaturas'),
                Tab(text: 'Humedades'),
              ],
              labelColor: Colors.black,
            ),
            SizedBox(
              height: 300,
              child: TabBarView(
                controller: _tabController,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      _buildCombinedChart(
                        label: 'Temperaturas (°C)',
                        data1: sensorSeleccionado!.temperaturaExt,
                        data2: sensorSeleccionado!.temperaturaInt,
                        label1: 'Temp. Externa',
                        label2: 'Temp. Interna',
                        color1: Colors.blue,
                        color2: Colors.red,
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      _buildCombinedChart(
                        label: 'Humedades (%)',
                        data1: sensorSeleccionado!.humedadExt,
                        data2: sensorSeleccionado!.humedadInt,
                        label1: 'Hum. Externa',
                        label2: 'Hum. Interna',
                        color1: Colors.blue,
                        color2: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                mapController.animateCamera(
                  CameraUpdate.newLatLngZoom(sensorSeleccionado!.ubicacion, 19),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text('Ver en el mapa'),
            ),
          ],
        ],
      ),
    );
  }
}
