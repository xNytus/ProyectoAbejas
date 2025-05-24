import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:data_table_2/data_table_2.dart'; 
import 'package:app_abejas/models/sensor.dart';
import 'package:app_abejas/models/sensor_data.dart';
import 'package:app_abejas/services/api_service.dart';
import 'package:app_abejas/services/api_config.dart';
import 'package:app_abejas/screens/map_screen.dart';
import 'package:intl/intl.dart'; // Added for date formatting


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key}); 

  @override
  State<HomeScreen> createState() => _HomeScreenState(); 
}
class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {

  GoogleMapController? mapController; 
  late TabController _tabController; 
  late ApiService _apiService; 
  List<Sensor> _listaDeSensoresUnicos = []; 
  bool _isLoadingSensores = true; 
  String? _errorLoadingSensores; 
  Sensor? _sensorSeleccionado; 
  List<SensorData> _datosDelSensorSeleccionado = []; 
  bool _isLoadingChartData = false; 
  String? _errorLoadingChartData; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); 
    final uri = Uri.parse(ApiConfig.apiUrl);
    final baseUrl = "${uri.scheme}://${uri.host}${uri.path.replaceAll('/datalist', '')}";
    _apiService = ApiService(baseUrl: baseUrl); 
    _fetchUniqueSensorList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    mapController?.dispose(); 
    super.dispose();
  }

  Future<void> _fetchUniqueSensorList() async {
    setState(() {
      _isLoadingSensores = true;
      _errorLoadingSensores = null;
      _listaDeSensoresUnicos = []; 
      _sensorSeleccionado = null; 
      _datosDelSensorSeleccionado = []; 
    });

    try {
      final uniqueSensors = await _apiService.fetchUniqueSensors();
      setState(() {
        _listaDeSensoresUnicos = uniqueSensors;
        _isLoadingSensores = false; 
      });
    } catch (e) {
      debugPrint('Error fetching unique sensor list: $e');
      setState(() {
        _errorLoadingSensores = 'Error al obtener lista de sensores: ${e.toString()}';
        _isLoadingSensores = false;
      });
    }
  }

  Future<void> _fetchChartData(String sensorId) async {
     if (_sensorSeleccionado == null || _sensorSeleccionado!.nombre != sensorId) {
        return;
     }
    setState(() {
      _isLoadingChartData = true;
      _errorLoadingChartData = null;
      _datosDelSensorSeleccionado = [];
    });

    try {
      final sensorData = await _apiService.fetchDataBySensorId(sensorId);
      setState(() {
        _datosDelSensorSeleccionado = sensorData;
        _isLoadingChartData = false;
      });
    } catch (e) {
      debugPrint('Error fetching chart data for $sensorId: $e');
      setState(() {
        _errorLoadingChartData = 'Error al cargar datos de $sensorId: ${e.toString()}';
        _isLoadingChartData = false;
      });
    }
  }

  void _handleSensorSelection(Sensor? sensor) {
     if (sensor == null || sensor == _sensorSeleccionado) return;
    setState(() {
      _sensorSeleccionado = sensor;
      _datosDelSensorSeleccionado = [];
      _isLoadingChartData = true;
      _errorLoadingChartData = null;
    });
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(sensor.ubicacion, 18),
    );
    _fetchChartData(sensor.nombre);
  }

  Set<Marker> get _crearMarcadores {
    return _listaDeSensoresUnicos.map((sensor) {
      return Marker(
        markerId: MarkerId(sensor.nombre),
        position: sensor.ubicacion,
        infoWindow: InfoWindow( 
            title: sensor.nombre,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(_colorToHue(sensor.color)),
        
        onTap: () {
            _handleSensorSelection(sensor);
        },
      );
    }).toSet();
  }

  double _colorToHue(Color color) {
    final hslColor = HSLColor.fromColor(color);
    return hslColor.hue;
  }

   Widget _buildCombinedChart({
    required String title, 
    required List<SensorData> timeSeriesData, 
    required String label1, 
    required double Function(SensorData) getValue1,
    required Color color1, 
    required String label2, 
    required double Function(SensorData) getValue2, 
    required Color color2, 
    // Parámetros para umbrales
    double? thresholdHighValue,
    Color? thresholdHighColor,
    String? thresholdHighLabel,
    double? thresholdLowValue,
    Color? thresholdLowColor,
    String? thresholdLowLabel,
  }) {    
    // Manejar estados de carga, error o datos vacíos primero.
    if (_isLoadingChartData) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (_errorLoadingChartData != null) {
      return SizedBox(height: 200, child: Center(child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(_errorLoadingChartData!, textAlign: TextAlign.center),
      )));
    }
    if (timeSeriesData.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No hay datos disponibles para graficar.')));
    }

    List<MapEntry<DateTime, SensorData>> processedData = [];
    try {
      processedData = timeSeriesData.map((data) {
        // Usar DateFormat para parsear el formato "dd/MM/yyyy HH:mm:ss"
        final dateFormat = DateFormat("dd/MM/yyyy HH:mm:ss");
        return MapEntry(dateFormat.parse(data.timestamp), data);
      }).toList();
      // Ordenar los datos por fecha/hora es crucial para la correcta visualización del gráfico.
      processedData.sort((a, b) => a.key.compareTo(b.key));
    } catch (e) {
      debugPrint('Error parsing timestamps for chart: $e');
      return SizedBox(
        height: 200, // Altura consistente con otros estados
        child: Center(child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Error al procesar fechas para el gráfico. Verifique el formato de los datos.\nDetalle: ${e.toString()}', textAlign: TextAlign.center),
        )),
      );
    }

    if (processedData.isEmpty) { // Salvaguarda adicional
        return const SizedBox(height: 200, child: Center(child: Text('No hay datos procesados para graficar.')));
    }

    final double minXEpoch = processedData.first.key.millisecondsSinceEpoch.toDouble();
    final double maxXEpoch = processedData.last.key.millisecondsSinceEpoch.toDouble();

    bool allSameDay = true;
    final firstDateTime = processedData.first.key;
    for (final entry in processedData) {
      if (entry.key.year != firstDateTime.year ||
          entry.key.month != firstDateTime.month ||
          entry.key.day != firstDateTime.day) {
        allSameDay = false;
        break;
      }
    }

    final List<FlSpot> spots1 = processedData.map((entry) => FlSpot(entry.key.millisecondsSinceEpoch.toDouble(), getValue1(entry.value))).toList();
    final List<FlSpot> spots2 = processedData.map((entry) => FlSpot(entry.key.millisecondsSinceEpoch.toDouble(), getValue2(entry.value))).toList();

    // Determinar minY y maxY basados en los datos y los umbrales
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var spot in spots1) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }
    for (var spot in spots2) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }

    if (thresholdLowValue != null) {
      minY = minY < thresholdLowValue ? minY : thresholdLowValue;
    }
    if (thresholdHighValue != null) {
      maxY = maxY > thresholdHighValue ? maxY : thresholdHighValue;
    }

    // Añadir padding si minY y maxY no son infinitos (es decir, hay datos)
    if (minY != double.infinity && maxY != double.negativeInfinity) {
      final range = maxY - minY;
      minY -= range * 0.1; // 10% padding abajo
      maxY += range * 0.1; // 10% padding arriba
      if (minY == maxY) { // Caso de un solo valor o todos los valores iguales
        minY -= 1; // Evitar que minY y maxY sean iguales
        maxY += 1;
      }
    } else {
      // Si no hay datos, o los umbrales son los únicos puntos de referencia
      minY = thresholdLowValue ?? 0;
      maxY = thresholdHighValue ?? 10; // Valores por defecto si no hay nada más
      if (minY >= maxY) maxY = minY + 10; // Asegurar que maxY > minY
    }

    const double minWidthPerDataPoint = 10.0; 
    final double chartWidth = processedData.length * minWidthPerDataPoint < MediaQuery.of(context).size.width - 50
        ? MediaQuery.of(context).size.width - 50
        : processedData.length * minWidthPerDataPoint;

    double? bottomTitlesInterval;
    if (maxXEpoch > minXEpoch) {
      bottomTitlesInterval = (maxXEpoch - minXEpoch) / 5.0; // Intentar tener ~5 intervalos (6 etiquetas)
      // Prevenir intervalos extremadamente pequeños o cero.
      if (bottomTitlesInterval < 1.0) { // Si el intervalo es menor a 1ms
          bottomTitlesInterval = null; // Dejar que FL Chart decida.
      }
    } else {
      // minXEpoch == maxXEpoch (ej. un solo punto de dato, o todos en el mismo milisegundo)
      bottomTitlesInterval = null; 
    }

    List<HorizontalLine> extraLines = [];
    if (thresholdHighValue != null) {
      extraLines.add(HorizontalLine(
        y: thresholdHighValue,
        color: thresholdHighColor ?? Colors.black.withOpacity(0.8),
        strokeWidth: 2,
        dashArray: [5, 5], // Línea discontinua
        label: HorizontalLineLabel(
          show: true,
          labelResolver: (_) => thresholdHighLabel ?? 'Alto',
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 5, top: 2),
          style: TextStyle(color: thresholdHighColor ?? Colors.black, backgroundColor: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ));
    }
    if (thresholdLowValue != null) {
      extraLines.add(HorizontalLine(
        y: thresholdLowValue,
        color: thresholdLowColor ?? Colors.black.withOpacity(0.8),
        strokeWidth: 2,
        dashArray: [5, 5], // Línea discontinua
        label: HorizontalLineLabel(
          show: true,
          labelResolver: (_) => thresholdLowLabel ?? 'Bajo',
          alignment: Alignment.bottomRight,
          padding: const EdgeInsets.only(right: 5, bottom: 2),
          style: TextStyle(color: thresholdLowColor ?? Colors.black, backgroundColor: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 10.0),
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 200, 
          child: SingleChildScrollView( // El hijo ahora es el gráfico si los datos son válidos
                          scrollDirection: Axis.horizontal, 
                          child: SizedBox( 
                            width: chartWidth, 
                            child: Padding( 
                              padding: const EdgeInsets.only(right: 16.0, left: 8.0, bottom: 10.0), 
                              child: LineChart( 
                                LineChartData(
                                  minX: minXEpoch, 
                                  maxX: maxXEpoch,
                                  minY: minY, // Usar minY calculado
                                  maxY: maxY, // Usar maxY calculado                                 
                                  gridData: FlGridData(show: true, drawVerticalLine: false), 
                                  titlesData: FlTitlesData( 
                                      show: true,
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true, 
                                          reservedSize: 50, // Aumentado para etiquetas de múltiples líneas
                                          interval: bottomTitlesInterval, // Usar el intervalo calculado
                                          getTitlesWidget: (value, meta) {
                                            // value está en millisecondsSinceEpoch
                                            final dt = DateTime.fromMillisecondsSinceEpoch(value.round());
                                            String text;
                                            if (allSameDay) {
                                              text = DateFormat('HH:mm').format(dt);
                                            } else {
                                              // Formato para múltiples días: fecha arriba, hora abajo
                                              text = DateFormat('dd/MM\nHH:mm').format(dt);
                                            }                                            
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              space: 4, 
                                              child: Text(text, style: const TextStyle(fontSize: 10)),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40))
                                  ),
                                  borderData: FlBorderData(show: true), 
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: spots1, isCurved: true, color: color1, barWidth: 2,
                                      isStrokeCapRound: true, dotData: FlDotData(show: true), belowBarData: BarAreaData(show: false),
                                    ),
                                    LineChartBarData(
                                      spots: spots2, isCurved: true, color: color2, barWidth: 2,
                                      isStrokeCapRound: true, dotData: FlDotData(show: true), belowBarData: BarAreaData(show: false),
                                    ),
                                  ],
                                  extraLinesData: ExtraLinesData(horizontalLines: extraLines), // Movido aquí dentro de LineChartData
                                ),
                              ),
                            ),
                          ),
                        ),
        ),
        const SizedBox(height: 10), 
        Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            _buildLegendDot(color1, label1),
            const SizedBox(width: 16),
            _buildLegendDot(color2, label2),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration( shape: BoxShape.circle, color: color, ),
        ),
        const SizedBox(width: 4), 
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoreo de Cajones')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingSensores) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorLoadingSensores != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorLoadingSensores!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _fetchUniqueSensorList,
                child: const Text('Reintentar'),
              )
            ],
          ),
        ),
      );
    }
    if (_listaDeSensoresUnicos.isEmpty) {
      return const Center(child: Text('No se encontraron sensores.'));
    }
    return _buildMainContent();
  }
  Widget _buildMainContent() {
    final LatLng initialMapLocation = _sensorSeleccionado?.ubicacion
        ?? (_listaDeSensoresUnicos.isNotEmpty
            ? _listaDeSensoresUnicos[0].ubicacion
            : const LatLng(0, 0));

    return Column( 
      children: [
        Stack(
          children: [
            SizedBox(
              height: 200,
              child: GoogleMap(
                mapType: MapType.hybrid,
                initialCameraPosition: CameraPosition(
                  target: initialMapLocation,
                  zoom: 15,
                ),
                markers: _crearMarcadores,
                onMapCreated: (controller) {
                  mapController = controller;
                },
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: FloatingActionButton.small(
                heroTag: 'fullscreen_map_button',
                backgroundColor: Colors.white.withOpacity(0.8),
                onPressed: _goToExpandedMap,
                child: const Icon(Icons.fullscreen, color: Colors.black),
              ),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<Sensor>(
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Seleccionar Cajón',
            ),
            isExpanded: true,
            value: _sensorSeleccionado,
            items: _listaDeSensoresUnicos.map((sensor) {
              return DropdownMenuItem(
                value: sensor,
                child: Row(
                  children: [
                    Icon(Icons.sensors, color: sensor.color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text( sensor.nombre, overflow: TextOverflow.ellipsis,)),
                  ],
                ),
              );
            }).toList(),
            onChanged: _handleSensorSelection,
          ),
        ),

        Expanded(
          child: SingleChildScrollView( 
            child: Column(
              children: [
                 
                if (_sensorSeleccionado != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Datos de: ${_sensorSeleccionado!.nombre}',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Actualizar datos del cajón',
                          onPressed: _isLoadingChartData
                              ? null // Deshabilitado si está cargando
                              : () {
                                  // _sensorSeleccionado está garantizado que no es nulo aquí
                                  // debido al if (_sensorSeleccionado != null) que envuelve este bloque.
                                  // Sin embargo, una comprobación adicional no hace daño.
                                  if (_sensorSeleccionado != null) {
                                    _fetchChartData(_sensorSeleccionado!.nombre);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    tabs: const [ Tab(text: 'Temperaturas'), Tab(text: 'Humedades'), ],
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                  ),
                  SizedBox(
                    height: 300, 
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 16, bottom: 16),
                            child: _buildCombinedChart(
                              title: 'Temperaturas (°C)',
                              timeSeriesData: _datosDelSensorSeleccionado,
                              label1: 'Externa', getValue1: (d) => d.temperaturaExt, color1: Colors.lightBlueAccent,
                              label2: 'Interna', getValue2: (d) => d.temperaturaInt, color2: Colors.redAccent,
                              // Umbrales para Temperatura
                              thresholdHighValue: 38.0,
                              thresholdHighColor: Colors.red[700],
                              thresholdHighLabel: 'Máx: 38°C',
                              thresholdLowValue: 30.0,
                              thresholdLowColor: Colors.blue[700],
                              thresholdLowLabel: 'Mín: 30°C',
                            ),
                          ),
                          SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 16, bottom: 16),
                             child: _buildCombinedChart(
                               title: 'Humedades (%)',
                               timeSeriesData: _datosDelSensorSeleccionado,
                               label1: 'Externa', getValue1: (d) => d.humedadExt, color1: Colors.cyan,
                               label2: 'Interna', getValue2: (d) => d.humedadInt, color2: Colors.orangeAccent,
                               // Umbrales para Humedad
                               thresholdHighValue: 80.0,
                               thresholdHighColor: Colors.purpleAccent[700],
                               thresholdHighLabel: 'Máx: 80%',
                               thresholdLowValue: 60.0,
                               thresholdLowColor: Colors.tealAccent[700],
                               thresholdLowLabel: 'Mín: 60%',
                             ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (!_isLoadingChartData && _datosDelSensorSeleccionado.isNotEmpty) ...[
                    const Divider(height: 20, indent: 16, endIndent: 16), 
                   
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text( 'Tabla de Datos Históricos', style: Theme.of(context).textTheme.titleMedium, ),
                    ),
                    
                    SizedBox(
                      height: 300, 
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: DataTable2(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          fixedTopRows: 1,
                          headingRowColor: MaterialStateProperty.all(Colors.blueGrey[50]),
                          border: TableBorder.all(width: 1, color: Colors.grey.shade300),
                          columns: const <DataColumn2>[
                            DataColumn2(label: Text('Fecha Hora'), size: ColumnSize.L),
                            DataColumn2(label: Text('T. Int'), numeric: true, size: ColumnSize.S),
                            DataColumn2(label: Text('T. Ext'), numeric: true, size: ColumnSize.S),
                            DataColumn2(label: Text('H. Int'), numeric: true, size: ColumnSize.S),
                            DataColumn2(label: Text('H. Ext'), numeric: true, size: ColumnSize.S),
                          ],
                          rows: _datosDelSensorSeleccionado
                              .map((data) {
                                final tempIntStr = data.temperaturaInt.toStringAsFixed(1);
                                final tempExtStr = data.temperaturaExt.toStringAsFixed(1);
                                final humIntStr = data.humedadInt.toStringAsFixed(1);
                                final humExtStr = data.humedadExt.toStringAsFixed(1);
                                return DataRow2(
                                  cells: <DataCell>[
                                    DataCell(Text(data.timestamp)),
                                    DataCell(Text(tempIntStr)),
                                    DataCell(Text(tempExtStr)),
                                    DataCell(Text(humIntStr)),
                                    DataCell(Text(humExtStr)),
                                  ],
                                );
                              })
                              .toList()
                              .reversed 
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), 
                  ],

                ] else ...[
                   SizedBox(
                     height: 300, 
                     child: Center(
                       child: Padding(
                         padding: const EdgeInsets.all(16.0),
                         child: Text(
                           'Selecciona un cajón del menú superior para ver sus datos.',
                            textAlign: TextAlign.center,
                         ),
                       ),
                     ),
                   )
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
  void _goToExpandedMap() {
    final LatLng centerLocation = _sensorSeleccionado?.ubicacion
        ?? (_listaDeSensoresUnicos.isNotEmpty
            ? _listaDeSensoresUnicos[0].ubicacion
            : const LatLng(0,0));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapaExpandidoScreen(
          ubicacionInicial: centerLocation,
          marcadores: _crearMarcadores,
        ),
      ),
    );
  }
}