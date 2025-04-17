import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'home_screen.dart';

class detalles_screen extends StatefulWidget {
  final Sensor sensor;

  const detalles_screen({Key? key, required this.sensor}) : super(key: key);

  @override
  _detalles_screenState createState() => _detalles_screenState();
}

class _detalles_screenState extends State<detalles_screen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle de ${widget.sensor.nombre}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Temp. Ext'),
            Tab(text: 'Temp. Int'),
            Tab(text: 'Humedad Ext'),
            Tab(text: 'Humedad Int'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChartAndTable(widget.sensor.temperaturaExt, 'Temperatura Externa'),
          _buildChartAndTable(widget.sensor.temperaturaInt, 'Temperatura Interna'),
          _buildChartAndTable(widget.sensor.humedadExt, 'Humedad Externa'),
          _buildChartAndTable(widget.sensor.humedadInt, 'Humedad Interna'),
        ],
      ),
    );
  }

  Widget _buildChartAndTable(List<double> data, String label) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          // Gráfico
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map(
                      (e) => FlSpot(e.key.toDouble(), e.value),
                    ).toList(),
                    isCurved: true,
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Título de la variable
          Text(label, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          // Tabla de mediciones
          Expanded(
            child: ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Text('#${index + 1}'),
                  title: Text('${data[index]}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
