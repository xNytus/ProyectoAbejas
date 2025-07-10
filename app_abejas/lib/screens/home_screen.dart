import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:app_abejas/models/sensor.dart';
import 'package:app_abejas/models/sensor_data.dart';
import 'package:app_abejas/services/api_service.dart';
import 'package:app_abejas/services/api_config.dart';
import 'package:app_abejas/services/database_helper.dart'; // Importa el gestor de la base de datos
import 'package:app_abejas/screens/map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Importa para guardar la fecha
import 'package:intl/intl.dart'; // Added for date formatting
import 'package:intl/date_symbol_data_local.dart'; // Added for locale data initialization

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  late TabController _tabController;
  late ApiService _apiService;
  late DatabaseHelper _dbHelper; 
  List<Sensor> _listaDeSensoresUnicos = []; 
  bool _isLoading = true; 
  String? _errorMessage; 
  Sensor? _sensorSeleccionado;
  DateTime? _lastSyncTime; 
  List<SensorData> _allSensorDataForSelectedSensor = []; // Almacena todos los datos del sensor seleccionado
  List<SensorData> _filteredSensorData = []; // Datos filtrados por mes para los gráficos y tabla

  DateTime? _selectedMonth; // Nuevo: Variable para el mes seleccionado

  int? _sortColumnIndex;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    // Initialize locale data for date formatting
    Intl.defaultLocale = 'es'; // Set default locale to Spanish
    initializeDateFormatting('es'); // Initialize data for the 'es' locale

    _tabController = TabController(length: 2, vsync: this);
    _sortColumnIndex = 0;
    _apiService = ApiService(baseUrl: ApiConfig.baseUrl);
    _dbHelper = DatabaseHelper(); 
    _loadLastSyncTime();
    _loadDataAndSync();
  }

  @override
  void dispose() {
    _tabController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('lastSyncTimestamp');
    if (timestamp != null && mounted) {
      setState(() {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      });
    }
  }

  Future<void> _loadDataAndSync() async {
    await _loadSensorsFromDb();
    await _syncDataFromApi();
  }

  Future<void> _loadSensorsFromDb() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final localSensors = await _dbHelper.getUniqueSensors();
      if (mounted) {
        setState(() {
          _listaDeSensoresUnicos = localSensors;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos locales: $e';
          _isLoading = false; 
        });
      }
    }
  }

  Future<void> _syncDataFromApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allData = await _apiService.fetchAllData();
      await _dbHelper.insertSensorData(allData);

      final uniqueSensorsMap = <String, Sensor>{};
      for (final dataPoint in allData) {
        if (!uniqueSensorsMap.containsKey(dataPoint.sensorId)) {
          uniqueSensorsMap[dataPoint.sensorId] = Sensor(
            nombre: dataPoint.sensorId,
            ubicacion: LatLng(dataPoint.lat, dataPoint.lng),
            color: Colors.blueGrey, 
          );
        }
      }
      final uniqueSensors = uniqueSensorsMap.values.toList();
      await _dbHelper.insertSensors(uniqueSensors);

      final updatedSensors = await _dbHelper.getUniqueSensors();
      if (mounted) {
        final now = DateTime.now();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lastSyncTimestamp', now.millisecondsSinceEpoch);

        setState(() {
          _listaDeSensoresUnicos = updatedSensors;
          _lastSyncTime = now; 
        });

        // Si hay un sensor seleccionado, recargar sus datos para aplicar filtros
        if (_sensorSeleccionado != null) {
          await _fetchChartData(_sensorSeleccionado!.nombre);
        }
      }
    } catch (e) {
      debugPrint('Error al sincronizar datos desde la API: $e');
      if (mounted) _errorMessage = 'Error al sincronizar: ${e.toString()}';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchChartData(String sensorId) async {
    try {
      final localData = await _dbHelper.getSensorData(sensorId);
      if (mounted) {
        setState(() {
          _allSensorDataForSelectedSensor = localData; // Almacena todos los datos
          _applyMonthFilter(); // Aplica el filtro de mes
          _sortSensorData();
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos del sensor desde la BD: $e');
      if (mounted) setState(() => _errorMessage = 'Error al cargar datos de $sensorId: $e');
    }
  }

  // Nuevo: Aplica el filtro de mes a los datos
  void _applyMonthFilter() {
    if (_selectedMonth == null) {
      _filteredSensorData = List.from(_allSensorDataForSelectedSensor);
    } else {
      _filteredSensorData = _allSensorDataForSelectedSensor.where((data) {
        return data.timestamp.year == _selectedMonth!.year &&
               data.timestamp.month == _selectedMonth!.month;
      }).toList();
    }
    _sortSensorData(); // Re-ordenar después de filtrar
  }

  // Nuevo: Obtiene la lista de meses únicos con datos
  List<DateTime> _getAvailableMonths() {
    final Set<DateTime> uniqueMonths = {};
    for (final data in _allSensorDataForSelectedSensor) {
      uniqueMonths.add(DateTime(data.timestamp.year, data.timestamp.month));
    }
    final sortedMonths = uniqueMonths.toList()
      ..sort((a, b) => a.compareTo(b));
    return sortedMonths;
  }

  void _handleSensorSelection(Sensor? sensor) {
    if (sensor == null || sensor == _sensorSeleccionado) return;

    setState(() {
      _sensorSeleccionado = sensor;
      _allSensorDataForSelectedSensor = []; // Limpiar datos completos
      _filteredSensorData = []; // Limpiar datos filtrados
      _errorMessage = null;
      _sortColumnIndex = 0; 
      _sortAscending = false; 
      _selectedMonth = null; // Reiniciar el mes seleccionado al cambiar de sensor
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
      }
    });
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(sensor.ubicacion, 18),
    );
    _fetchChartData(sensor.nombre); // Esto cargará los datos y aplicará el filtro inicial
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortSensorData();
    });
  }

  void _sortSensorData() {
    if (_sortColumnIndex == null) return;

    _filteredSensorData.sort((a, b) { // Ordenar _filteredSensorData
      int comparisonResult;
      switch (_sortColumnIndex) {
        case 0: 
          final dateTimeA = a.timestamp; 
          final dateTimeB = b.timestamp; 
          comparisonResult = dateTimeA.compareTo(dateTimeB);
          break;
        case 1: 
          comparisonResult = a.temperaturaInt.compareTo(b.temperaturaInt);
          break;
        case 2: 
          comparisonResult = a.temperaturaExt.compareTo(b.temperaturaExt);
          break;
        case 3: 
          comparisonResult = a.humedadInt.compareTo(b.humedadInt);
          break;
        case 4: 
          comparisonResult = a.humedadExt.compareTo(b.humedadExt);
          break;
        default:
          return 0;
      }
      return _sortAscending ? comparisonResult : -comparisonResult;
    });
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
    required List<SensorData> timeSeriesData, // Ahora se espera que ya estén filtrados
    required String label1,
    required double Function(SensorData) getValue1,
    required Color color1,
    required String label2,
    required double Function(SensorData) getValue2,
    required Color color2,
    double? thresholdHighValue,
    Color? thresholdHighColor,
    String? thresholdHighLabel,
    double? thresholdLowValue,
    Color? thresholdLowColor,
    String? thresholdLowLabel,
  }) {
    if (_isLoading && timeSeriesData.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null && timeSeriesData.isEmpty) {
      return SizedBox(
          height: 200,
          child: Center(
              child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_errorMessage!, textAlign: TextAlign.center),
          )));
    }
    if (timeSeriesData.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No hay datos disponibles para graficar en el mes seleccionado.')));
    }

    List<MapEntry<DateTime, SensorData>> processedData = [];
    try {
      processedData = timeSeriesData.map((data) => MapEntry(data.timestamp, data)).toList();
      processedData.sort((a, b) => a.key.compareTo(b.key));
    } catch (e) {
      debugPrint('Error parsing timestamps for chart: $e');
      return SizedBox(
        height: 200, 
        child: Center(
            child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Error al procesar fechas para el gráfico. Verifique el formato de los datos.\nDetalle: ${e.toString()}', textAlign: TextAlign.center),
        )),
      );
    }

    if (processedData.isEmpty) {
      // Salvaguarda adicional
      return const SizedBox(height: 200, child: Center(child: Text('No hay datos procesados para graficar.')));
    }

    final double minXEpoch = processedData.first.key.millisecondsSinceEpoch.toDouble();
    final double maxXEpoch = processedData.last.key.millisecondsSinceEpoch.toDouble();

    bool allSameDay = true;
    final firstDateTime = processedData.first.key;
    for (final entry in processedData) {
      if (entry.key.year != firstDateTime.year || entry.key.month != firstDateTime.month || entry.key.day != firstDateTime.day) {
        allSameDay = false;
        break;
      }
    }

    final List<FlSpot> spots1 = processedData.map((entry) => FlSpot(entry.key.millisecondsSinceEpoch.toDouble(), getValue1(entry.value))).toList();
    final List<FlSpot> spots2 = processedData.map((entry) => FlSpot(entry.key.millisecondsSinceEpoch.toDouble(), getValue2(entry.value))).toList();

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

    if (minY != double.infinity && maxY != double.negativeInfinity) {
      final range = maxY - minY;
      minY -= range * 0.1; 
      maxY += range * 0.1; 
      if (minY == maxY) {
        minY -= 1; 
        maxY += 1;
      }
    } else {
      minY = thresholdLowValue ?? 0;
      maxY = thresholdHighValue ?? 10; 
      if (minY >= maxY) maxY = minY + 10;
    }

    const double minWidthPerDataPoint = 10.0;
    final double chartWidth = processedData.length * minWidthPerDataPoint < MediaQuery.of(context).size.width - 50 ? MediaQuery.of(context).size.width - 50 : processedData.length * minWidthPerDataPoint;

    double? bottomTitlesInterval;
    if (maxXEpoch > minXEpoch) {
      bottomTitlesInterval = (maxXEpoch - minXEpoch) / 5.0; 
      if (bottomTitlesInterval < 1.0) {
        bottomTitlesInterval = null; 
      }
    } else {
      bottomTitlesInterval = null;
    }

    List<HorizontalLine> extraLines = [];
    if (thresholdHighValue != null) {
      extraLines.add(HorizontalLine(
        y: thresholdHighValue,
        color: thresholdHighColor ?? Colors.black.withOpacity(0.8),
        strokeWidth: 2,
        dashArray: [5, 5], 
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
        dashArray: [5, 5], 
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0, left: 8.0, bottom: 10.0),
                child: LineChart(
                  LineChartData(
                    minX: minXEpoch,
                    maxX: maxXEpoch,
                    minY: minY, 
                    maxY: maxY, 
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50, 
                          interval: bottomTitlesInterval,
                          getTitlesWidget: (value, meta) {
                            final dt = DateTime.fromMillisecondsSinceEpoch(value.round());
                            String text;
                            if (allSameDay) {
                              text = DateFormat('HH:mm').format(dt);
                            } else {
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
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots1, isCurved: false, color: color1, barWidth: 2,
                        isStrokeCapRound: true, dotData: FlDotData(show: true), belowBarData: BarAreaData(show: false),
                      ),
                      LineChartBarData(
                        spots: spots2, isCurved: false, color: color2, barWidth: 2,
                        isStrokeCapRound: true, dotData: FlDotData(show: true), belowBarData: BarAreaData(show: false),
                      ),
                    ],
                    extraLinesData: ExtraLinesData(horizontalLines: extraLines), 
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo de Cajones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sincronizar con la API',
            onPressed: _isLoading ? null : _syncDataFromApi,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _listaDeSensoresUnicos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _listaDeSensoresUnicos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _syncDataFromApi,
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
    final LatLng initialMapLocation = _sensorSeleccionado?.ubicacion ?? (_listaDeSensoresUnicos.isNotEmpty ? _listaDeSensoresUnicos[0].ubicacion : const LatLng(0, 0));
    final List<DateTime> availableMonths = _getAvailableMonths(); // Obtener meses disponibles

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
              top: 8,
              right: 8,
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
                    Expanded(
                        child: Text(
                      sensor.nombre,
                      overflow: TextOverflow.ellipsis,
                    )),
                  ],
                ),
              );
            }).toList(),
            onChanged: _handleSensorSelection,
          ),
        ),
        // Nuevo: Selector de Mes
        if (_sensorSeleccionado != null && availableMonths.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<DateTime>(
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Seleccionar Mes',
              ),
              isExpanded: true,
              value: _selectedMonth,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos los meses'),
                ),
                ...availableMonths.map((month) {
                  return DropdownMenuItem(
                    value: month,
                    child: Text(DateFormat('MMMM y', 'es').format(month)), // Changed format to include year
                  );
                }).toList(),
              ],
              onChanged: (DateTime? newMonth) {
                setState(() {
                  _selectedMonth = newMonth;
                  _applyMonthFilter(); // Aplicar el nuevo filtro de mes
                });
              },
            ),
          ),
        if (_lastSyncTime != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 16.0, bottom: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Última sincronización: ${DateFormat('dd/MM/yyyy HH:mm').format(_lastSyncTime!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
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
                          onPressed: _isLoading ? null : _syncDataFromApi,
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Temperaturas'),
                      Tab(text: 'Humedades'),
                    ],
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
                              timeSeriesData: _filteredSensorData, // Usar datos filtrados
                              label1: 'Externa', getValue1: (d) => d.temperaturaExt, color1: Colors.lightBlueAccent,
                              label2: 'Interna', getValue2: (d) => d.temperaturaInt, color2: Colors.redAccent,
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
                              timeSeriesData: _filteredSensorData, // Usar datos filtrados
                              label1: 'Externa', getValue1: (d) => d.humedadExt, color1: Colors.cyan,
                              label2: 'Interna', getValue2: (d) => d.humedadInt, color2: Colors.orangeAccent,
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
                  if (!_isLoading && _filteredSensorData.isNotEmpty) ...[ // Usar _filteredSensorData
                    const Divider(height: 20, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        'Tabla de Datos Históricos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    SizedBox(
                      height: 300,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: DataTable2(
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          fixedTopRows: 1,
                          headingRowColor: WidgetStateProperty.all(Colors.blueGrey[50]),
                          border: TableBorder.all(width: 1, color: Colors.grey.shade300),
                          columns: <DataColumn2>[
                            DataColumn2(label: const Text('Fecha Hora'), size: ColumnSize.L, onSort: _onSort),
                            DataColumn2(
                                label: const Text('T. Int'), numeric: true, size: ColumnSize.S, onSort: _onSort),
                            DataColumn2(
                                label: const Text('T. Ext'), numeric: true, size: ColumnSize.S, onSort: _onSort),
                            DataColumn2(
                                label: const Text('H. Int'), numeric: true, size: ColumnSize.S, onSort: _onSort),
                            DataColumn2(
                                label: const Text('H. Ext'), numeric: true, size: ColumnSize.S, onSort: _onSort),
                          ],
                          rows: _filteredSensorData.map((data) { // Usar _filteredSensorData
                            final tempIntStr = data.temperaturaInt.toStringAsFixed(1);
                            final tempExtStr = data.temperaturaExt.toStringAsFixed(1);
                            final humIntStr = data.humedadInt.toStringAsFixed(1);
                            final humExtStr = data.humedadExt.toStringAsFixed(1);
                            return DataRow2(
                              cells: <DataCell>[
                                DataCell(Text(DateFormat("dd/MM/yyyy HH:mm:ss").format(data.timestamp))), 
                                DataCell(Text(tempIntStr)),
                                DataCell(Text(tempExtStr)),
                                DataCell(Text(humIntStr)),
                                DataCell(Text(humExtStr)),
                              ],
                            );
                          }).toList(),
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
    final LatLng centerLocation = _sensorSeleccionado?.ubicacion ?? (_listaDeSensoresUnicos.isNotEmpty ? _listaDeSensoresUnicos[0].ubicacion : const LatLng(0, 0));

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
