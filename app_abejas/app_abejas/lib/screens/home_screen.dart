import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:data_table_2/data_table_2.dart'; // Importar data_table_2

// Models - Asegúrate que las rutas sean correctas para tu proyecto
import 'package:app_abejas/models/sensor.dart';
import 'package:app_abejas/models/sensor_data.dart';

// Services and Config - Asegúrate que las rutas sean correctas para tu proyecto
import 'package:app_abejas/services/api_service.dart';
import 'package:app_abejas/services/api_config.dart';

// Screens - Asegúrate que la ruta sea correcta para tu proyecto
import 'package:app_abejas/screens/map_screen.dart';


// --- Widget Principal de la Pantalla de Inicio ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key}); // Constructor estándar para StatefulWidget

  @override
  State<HomeScreen> createState() => _HomeScreenState(); // Crea el estado mutable
}

// --- Estado Mutable de la Pantalla de Inicio ---
class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // --- Variables de Estado ---

  // Controladores
  GoogleMapController? mapController; // Controlador para interactuar con el mapa (puede ser nulo inicialmente)
  late TabController _tabController; // Controlador para manejar las pestañas (Tabs)

  // Servicio API
  late ApiService _apiService; // Instancia del servicio para hacer llamadas a la API

  // Estado de la lista de sensores
  List<Sensor> _listaDeSensoresUnicos = []; // Lista para guardar los sensores únicos obtenidos de la API
  bool _isLoadingSensores = true; // Bandera para indicar si la lista de sensores se está cargando
  String? _errorLoadingSensores; // Variable para almacenar mensajes de error al cargar la lista de sensores

  // Estado del sensor seleccionado y sus datos
  Sensor? _sensorSeleccionado; // El sensor actualmente elegido en el Dropdown
  List<SensorData> _datosDelSensorSeleccionado = []; // Lista para guardar los datos (temp/hum) del sensor seleccionado
  bool _isLoadingChartData = false; // Bandera para indicar si se están cargando los datos para gráficos/tabla
  String? _errorLoadingChartData; // Variable para almacenar mensajes de error al cargar los datos del sensor


  // --- Método initState: Se ejecuta una vez cuando se crea el estado ---
  @override
  void initState() {
    super.initState();
    // Inicializa el TabController con 2 pestañas (Temperaturas, Humedades)
    _tabController = TabController(length: 2, vsync: this); // 'vsync: this' requiere SingleTickerProviderStateMixin

    // --- Inicializa ApiService ---
    // Extrae la URL base de la configuración. Es CRÍTICO que sea la URL base correcta.
    final uri = Uri.parse(ApiConfig.apiUrl);
    final baseUrl = "${uri.scheme}://${uri.host}${uri.path.replaceAll('/datalist', '')}";

    _apiService = ApiService(baseUrl: baseUrl); // Crea la instancia del servicio con la URL base
    // --- Fin Inicialización ApiService ---

    // Llama a la función para obtener la lista inicial de sensores al iniciar la pantalla
    _fetchUniqueSensorList();
  }

  // --- Método dispose: Se ejecuta cuando el estado se destruye ---
  @override
  void dispose() {
    // Libera los recursos de los controladores para evitar fugas de memoria
    _tabController.dispose();
    mapController?.dispose(); // Llama a dispose() solo si mapController no es nulo
    super.dispose();
  }


  // --- Obtiene la lista de sensores ÚNICOS desde la API (/datalist) ---
  Future<void> _fetchUniqueSensorList() async {
    // Actualiza el estado para indicar carga y limpiar datos/errores previos
    setState(() {
      _isLoadingSensores = true;
      _errorLoadingSensores = null;
      _listaDeSensoresUnicos = []; // Limpia lista anterior
      _sensorSeleccionado = null; // Deselecciona cualquier sensor previo
      _datosDelSensorSeleccionado = []; // Limpia datos de gráficos/tabla
    });

    try {
      // Llama al método del servicio API que obtiene los sensores únicos
      final uniqueSensors = await _apiService.fetchUniqueSensors();
      // Actualiza el estado con la lista de sensores obtenida
      setState(() {
        _listaDeSensoresUnicos = uniqueSensors;
        _isLoadingSensores = false; // Termina la carga
      });
    } catch (e) {
      // Si ocurre un error durante la llamada o procesamiento
      debugPrint('Error fetching unique sensor list: $e'); // Imprime el error en consola de debug
      // Actualiza el estado para mostrar el mensaje de error al usuario
      setState(() {
        _errorLoadingSensores = 'Error al obtener lista de sensores: ${e.toString()}';
        _isLoadingSensores = false; // Termina la carga (con error)
      });
    }
  }

  // --- Obtiene los datos de SERIE TEMPORAL para un sensor específico ---
  // Llama a la API (/datalist?sensorId=...)
  Future<void> _fetchChartData(String sensorId) async {
     // Comprobación para evitar llamadas duplicadas si el sensor no ha cambiado
     if (_sensorSeleccionado == null || _sensorSeleccionado!.nombre != sensorId) {
        return;
     }
    // Actualiza el estado para indicar carga de datos de gráficos/tabla
    setState(() {
      _isLoadingChartData = true;
      _errorLoadingChartData = null; // Limpia error previo
      _datosDelSensorSeleccionado = []; // Limpia datos previos
    });

    try {
      // Llama al método del servicio API que obtiene los datos por ID
      final sensorData = await _apiService.fetchDataBySensorId(sensorId);
      // Actualiza el estado con los datos de serie temporal obtenidos
      setState(() {
        _datosDelSensorSeleccionado = sensorData;
        _isLoadingChartData = false; // Termina la carga de datos
      });
    } catch (e) {
      // Si ocurre un error
      debugPrint('Error fetching chart data for $sensorId: $e'); // Imprime error en debug
      // Actualiza el estado para mostrar el error en la UI (en el área de gráficos/tabla)
      setState(() {
        _errorLoadingChartData = 'Error al cargar datos de $sensorId: ${e.toString()}';
        _isLoadingChartData = false; // Termina la carga (con error)
      });
    }
  }

  // --- Maneja el cambio de selección en el Dropdown de sensores ---
  void _handleSensorSelection(Sensor? sensor) {
     // Si no se selecciona nada (null) o se vuelve a seleccionar el mismo, no hacer nada
     if (sensor == null || sensor == _sensorSeleccionado) return;

    // Actualiza el estado: guarda el nuevo sensor, limpia datos, activa carga
    setState(() {
      _sensorSeleccionado = sensor;
      _datosDelSensorSeleccionado = []; // Limpia datos anteriores inmediatamente
      _isLoadingChartData = true; // Muestra indicador de carga para gráficos/tabla
      _errorLoadingChartData = null; // Limpia errores anteriores
    });

    // Anima la cámara del mapa para centrarse en la ubicación del sensor seleccionado
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(sensor.ubicacion, 18), // Zoom 18 (puedes ajustarlo)
    );

    // Llama a la función para obtener los datos (temperatura, humedad) de este sensor
    _fetchChartData(sensor.nombre); // Usa el nombre del sensor como ID para la API
  }


  // --- Construye el conjunto (Set) de marcadores para mostrar en el mapa ---
  Set<Marker> get _crearMarcadores {
    // Mapea cada objeto Sensor en la lista de únicos a un objeto Marker
    return _listaDeSensoresUnicos.map((sensor) {
      return Marker(
        markerId: MarkerId(sensor.nombre), // ID único basado en el nombre/ID del sensor
        position: sensor.ubicacion, // Coordenadas LatLng del sensor
        infoWindow: InfoWindow( // Información que aparece al tocar el marcador
            title: sensor.nombre,
        ),
        // Asigna un color al icono del marcador basado en el nombre del sensor
        icon: BitmapDescriptor.defaultMarkerWithHue(_colorToHue(sensor.color)),
        // Acción al tocar el marcador en el mapa
        onTap: () {
            // Llama a la función que maneja la selección del sensor
            _handleSensorSelection(sensor);
        },
      );
    }).toSet(); // Convierte el resultado del map (Iterable) en un Set<Marker>
  }

  // --- Convierte un Color Flutter a un valor Hue (0-360) para Google Maps ---
  double _colorToHue(Color color) {
    // Usa la clase HSLColor para convertir RGB a HSL (Hue, Saturation, Lightness)
    final hslColor = HSLColor.fromColor(color);
    // Devuelve el componente Hue
    return hslColor.hue;
  }


  // --- Construye el widget del gráfico de líneas combinado ---
   Widget _buildCombinedChart({
    required String title, // Título principal del gráfico
    required List<SensorData> timeSeriesData, // Lista de datos (objetos SensorData)
    required String label1, // Etiqueta para la leyenda de la línea 1
    required double Function(SensorData) getValue1, // Función para obtener el valor Y de la línea 1
    required Color color1, // Color de la línea 1
    required String label2, // Etiqueta para la leyenda de la línea 2
    required double Function(SensorData) getValue2, // Función para obtener el valor Y de la línea 2
    required Color color2, // Color de la línea 2
  }) {
    // Mapea los SensorData a puntos FlSpot (X, Y) para la librería fl_chart
    final List<FlSpot> spots1 = timeSeriesData.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), getValue1(entry.value));
    }).toList();
    final List<FlSpot> spots2 = timeSeriesData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), getValue2(entry.value));
    }).toList();

    // Calcula el valor máximo para el eje X basado en la cantidad de datos
    final double maxX = timeSeriesData.isNotEmpty ? (timeSeriesData.length - 1).toDouble() : 0;
    // Define un ancho mínimo por punto de dato para calcular el ancho total del gráfico
    const double minWidthPerDataPoint = 10.0; // Ajusta este valor según sea necesario
    // Calcula el ancho necesario para el gráfico. Si es menor que el ancho de la pantalla (menos márgenes), usa el ancho de la pantalla.
    final double chartWidth = maxX * minWidthPerDataPoint < MediaQuery.of(context).size.width - 50
        ? MediaQuery.of(context).size.width - 50
        : maxX * minWidthPerDataPoint;

    // Construye la UI del gráfico
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Alinea el título a la izquierda
      children: [
        // Título
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 10.0),
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        // Contenedor del gráfico o estado de carga/error
        SizedBox(
          height: 200, // Altura fija para el gráfico
          child: _isLoadingChartData // Muestra indicador si está cargando
              ? const Center(child: CircularProgressIndicator())
              : _errorLoadingChartData != null // Muestra error si ocurrió
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(_errorLoadingChartData!, textAlign: TextAlign.center),
                    ))
                  : timeSeriesData.isEmpty // Muestra mensaje si no hay datos
                      ? const Center(child: Text('No hay datos disponibles para graficar.'))
                      // --- Widget para Scroll Horizontal ---
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal, // Habilita scroll horizontal
                          child: SizedBox( // Contenedor para darle ancho al gráfico
                            width: chartWidth, // Ancho calculado o mínimo
                            child: Padding( // Padding para que el gráfico no toque los bordes
                              padding: const EdgeInsets.only(right: 16.0, left: 8.0, bottom: 10.0), // Añade padding inferior
                              child: LineChart( // El widget del gráfico de líneas
                                LineChartData(
                                  minX: 0, // Eje X empieza en 0
                                  maxX: maxX, // Eje X termina en el último índice
                                  // Configuración de la apariencia
                                  gridData: FlGridData(show: true, drawVerticalLine: false), // Rejilla horizontal
                                  titlesData: FlTitlesData( // Ejes y títulos
                                      show: true,
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      // Configuración del eje X (inferior)
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true, // Mostrar títulos inferiores
                                          reservedSize: 30, // Espacio reservado
                                          // Muestra una etiqueta cada cierto intervalo para evitar solapamiento
                                          interval: maxX > 10 ? (maxX / 5).floorToDouble() : 1,
                                          // Función para generar el widget de cada etiqueta del eje X
                                          getTitlesWidget: (value, meta) {
                                            // Muestra el índice del punto como etiqueta
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              space: 4, // Espacio sobre la etiqueta
                                              child: Text(value.toInt().toString()),
                                            );
                                          },
                                        ),
                                      ),
                                      // Configuración del eje Y (izquierdo)
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40))
                                  ),
                                  borderData: FlBorderData(show: true), // Borde alrededor del gráfico
                                  // Definición de las líneas
                                  lineBarsData: [
                                    // Línea 1
                                    LineChartBarData(
                                      spots: spots1, isCurved: true, color: color1, barWidth: 2,
                                      isStrokeCapRound: true, dotData: FlDotData(show: false), belowBarData: BarAreaData(show: false),
                                    ),
                                    // Línea 2
                                    LineChartBarData(
                                      spots: spots2, isCurved: true, color: color2, barWidth: 2,
                                      isStrokeCapRound: true, dotData: FlDotData(show: false), belowBarData: BarAreaData(show: false),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      // --- Fin Scroll Horizontal ---
        ),
        const SizedBox(height: 10), // Espacio
        // Leyenda del gráfico
        Row(
          mainAxisAlignment: MainAxisAlignment.center, // Centrar leyenda
          children: [
            _buildLegendDot(color1, label1), // Punto y etiqueta para línea 1
            const SizedBox(width: 16), // Espacio entre leyendas
            _buildLegendDot(color2, label2), // Punto y etiqueta para línea 2
          ],
        ),
        const SizedBox(height: 10), // Espacio final
      ],
    );
  }

  // --- Construye un elemento de la leyenda (punto de color + texto) ---
  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Para que ocupe el mínimo espacio horizontal
      children: [
        Container( // El punto de color
          width: 10, height: 10,
          decoration: BoxDecoration( shape: BoxShape.circle, color: color, ),
        ),
        const SizedBox(width: 4), // Espacio entre punto y texto
        Text(label, style: const TextStyle(fontSize: 12)), // Texto de la etiqueta
      ],
    );
  }

  // --- Método build principal de la pantalla ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoreo de Cajones')),
      // El cuerpo se construye dinámicamente según el estado de carga
      body: _buildBody(),
    );
  }

  // --- Construye el cuerpo según el estado de carga inicial ---
  Widget _buildBody() {
    if (_isLoadingSensores) {
      // Muestra indicador de progreso si se están cargando los sensores
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorLoadingSensores != null) {
      // Muestra error si falló la carga de sensores
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorLoadingSensores!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _fetchUniqueSensorList, // Botón para reintentar
                child: const Text('Reintentar'),
              )
            ],
          ),
        ),
      );
    }
    if (_listaDeSensoresUnicos.isEmpty) {
      // Muestra mensaje si no se encontraron sensores
      return const Center(child: Text('No se encontraron sensores.'));
    }
    // Si todo está bien, construye el contenido principal
    return _buildMainContent();
  }


  // --- Construye la UI principal con Mapa, Dropdown y Contenido Inferior ---
  Widget _buildMainContent() {
    // Determina la ubicación inicial del mapa
    final LatLng initialMapLocation = _sensorSeleccionado?.ubicacion
        ?? (_listaDeSensoresUnicos.isNotEmpty
            ? _listaDeSensoresUnicos[0].ubicacion
            : const LatLng(0, 0));

    return Column( // Organiza los elementos verticalmente
      children: [
        // --- Sección del Mapa --- (Sin cambios)
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

        // --- Sección del Dropdown --- (Sin cambios)
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

        // --- Sección Inferior (Pestañas, Gráficos, Tabla) ---
        Expanded( // Ocupa el espacio restante
          child: SingleChildScrollView( // Permite scroll vertical de todo el contenido inferior
            child: Column(
              children: [
                 // Mostrar contenido solo si hay un sensor seleccionado
                if (_sensorSeleccionado != null) ...[
                  const Divider(height: 1), // Línea divisoria
                  // Título con el nombre del sensor
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Datos de: ${_sensorSeleccionado!.nombre}',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Barra de pestañas
                  TabBar(
                    controller: _tabController,
                    tabs: const [ Tab(text: 'Temperaturas'), Tab(text: 'Humedades'), ],
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                  ),
                  // Contenedor para las vistas de las pestañas (Gráficos)
                  SizedBox(
                    height: 300, // Altura fija para los gráficos
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Gráfico de Temperaturas
                          SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 16, bottom: 16),
                            child: _buildCombinedChart(
                                title: 'Temperaturas (°C)', timeSeriesData: _datosDelSensorSeleccionado,
                                label1: 'Externa', getValue1: (d) => d.temperaturaExt, color1: Colors.lightBlueAccent,
                                label2: 'Interna', getValue2: (d) => d.temperaturaInt, color2: Colors.redAccent,
                              ),
                          ),
                          // Gráfico de Humedades
                          SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 16, bottom: 16),
                             child: _buildCombinedChart(
                                title: 'Humedades (%)', timeSeriesData: _datosDelSensorSeleccionado,
                                label1: 'Externa', getValue1: (d) => d.humedadExt, color1: Colors.cyan,
                                label2: 'Interna', getValue2: (d) => d.humedadInt, color2: Colors.orangeAccent,
                             ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- INICIO: Sección de la Tabla de Datos (Modificada para Wrap) ---
                  // Mostrar solo si no está cargando y hay datos
                  if (!_isLoadingChartData && _datosDelSensorSeleccionado.isNotEmpty) ...[
                    const Divider(height: 20, indent: 16, endIndent: 16), // Divisor
                    // Título de la tabla
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text( 'Tabla de Datos Históricos', style: Theme.of(context).textTheme.titleMedium, ),
                    ),
                    // Contenedor con altura fija para DataTable2
                    SizedBox(
                      height: 300, // Altura deseada para la tabla (ajustable)
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        // Usar DataTable2
                        child: DataTable2(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          // minWidth: 600, // Eliminado para permitir ajuste
                          fixedTopRows: 1, // Fija la fila de encabezado
                          headingRowColor: MaterialStateProperty.all(Colors.blueGrey[50]),
                          border: TableBorder.all(width: 1, color: Colors.grey.shade300),
                          // Definición de Columnas (usando DataColumn2)
                          columns: const <DataColumn2>[
                            DataColumn2(label: Text('Fecha Hora'), size: ColumnSize.L), // Más espacio para fecha
                            DataColumn2(label: Text('T. Int'), numeric: true, size: ColumnSize.S),
                            DataColumn2(label: Text('T. Ext'), numeric: true, size: ColumnSize.S),
                            DataColumn2(label: Text('H. Int'), numeric: true, size: ColumnSize.S),
                            DataColumn2(label: Text('H. Ext'), numeric: true, size: ColumnSize.S),
                          ],
                          // Generación de Filas (usando DataRow2)
                          rows: _datosDelSensorSeleccionado
                              .map((data) {
                                final tempIntStr = data.temperaturaInt.toStringAsFixed(1);
                                final tempExtStr = data.temperaturaExt.toStringAsFixed(1);
                                final humIntStr = data.humedadInt.toStringAsFixed(1);
                                final humExtStr = data.humedadExt.toStringAsFixed(1);
                                return DataRow2(
                                  cells: <DataCell>[
                                    // CAMBIO: Usar Text directamente para permitir wrap
                                    DataCell(Text(data.timestamp)),
                                    DataCell(Text(tempIntStr)),
                                    DataCell(Text(tempExtStr)),
                                    DataCell(Text(humIntStr)),
                                    DataCell(Text(humExtStr)),
                                  ],
                                );
                              })
                              .toList()
                              .reversed // Muestra los más recientes primero
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Espacio al final
                  ],
                  // --- FIN Sección Tabla ---

                ] else ...[
                   // Mensaje si no hay sensor seleccionado
                   SizedBox(
                     height: 300, // Espacio reservado
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

  // --- Navega a la pantalla del mapa expandido --- (Sin cambios)
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