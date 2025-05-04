// api_service.dart (Revisado con ordenamiento por DateTime)
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart'; // Importación existente
import '../models/sensor.dart';
import 'package:flutter/foundation.dart';


class ApiService {
  final String baseUrl; // e.g., "https://xyz.execute-api.region.amazonaws.com/stage"

  ApiService({required this.baseUrl});

  // --- METHOD TO GET UNIQUE SENSOR LIST (from /datalist) ---
  Future<List<Sensor>> fetchUniqueSensors() async {
     // Use the specific endpoint for the list
    final Uri uri = Uri.parse('$baseUrl/datalist'); // Asume que /datalist devuelve todos los datos o identificadores
    debugPrint('Llamando a API (fetchUniqueSensors): $uri');

    try {
      final response = await http.get(uri /*, headers: ... si necesitas auth */);
      debugPrint('Código de Estado fetchUniqueSensors: ${response.statusCode}');
      // debugPrint('Cuerpo Respuesta REAL (/datalist): ${response.body}'); // Puedes mantenerlo para debug si quieres

      if (response.statusCode == 200) {
        // Decodificar la respuesta JSON (espera una lista)
         dynamic decodedResponse = jsonDecode(response.body);
         if (decodedResponse is List) {
            List<dynamic> body = decodedResponse;
            // Usa un Map para extraer sensores únicos
            final Map<String, Sensor> uniqueSensorsMap = {};
            for (var item in body) {
              if (item is Map<String, dynamic>) {
                final sensorId = item['sensorId'] as String?;
                if (sensorId != null && !uniqueSensorsMap.containsKey(sensorId)) {
                  uniqueSensorsMap[sensorId] = Sensor.fromJsonIdentificador(item);
                }
              } else {
                 debugPrint('Item inesperado en la lista /datalist: $item');
              }
            }
            return uniqueSensorsMap.values.toList();
         } else {
            debugPrint('Respuesta inesperada desde /datalist (no es una lista): ${response.body}');
            throw Exception('Formato de respuesta inesperado para la lista de sensores.');
         }
      } else {
        debugPrint('Error API (fetchUniqueSensors): ${response.statusCode}');
        debugPrint('Cuerpo del error: ${response.body}');
        throw Exception('Fallo al cargar la lista de sensores (Código: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error al llamar/procesar API (fetchUniqueSensors): $e');
      throw Exception('Fallo al conectar/procesar la API (fetchUniqueSensors): $e');
    }
  }


  // --- METHOD to get time series data by sensorId ---
  // Llama a /datalist?sensorId=...
  Future<List<SensorData>> fetchDataBySensorId(String sensorId) async {
    final Uri uri = Uri.parse('$baseUrl/datalist').replace( // Llama a /datalist
      queryParameters: {'sensorId': sensorId},             // Añade sensorId como parámetro
    );
    debugPrint('Llamando a API (fetchDataBySensorId -> /datalist?sensorId=...): $uri');

    try {
      final response = await http.get(uri /*, headers: ... si necesitas auth */);
      debugPrint('Código de Estado fetchDataBySensorId: ${response.statusCode}');
      // debugPrint('Cuerpo Respuesta REAL (/datalist?sensorId=...): ${response.body}');

      if (response.statusCode == 200) {
         dynamic decodedResponse = jsonDecode(response.body);
         if (decodedResponse is List) {
            List<dynamic> body = decodedResponse;
            List<SensorData> sensorDataList = body
                .map((dynamic item) => SensorData.fromJson(item as Map<String, dynamic>))
                .toList();

            // --- RE-ACTIVAR ORDENAMIENTO POR DateTime ---
            sensorDataList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            // --- FIN ORDENAMIENTO ---

            return sensorDataList;
         } else {
             debugPrint('Respuesta inesperada desde /datalist?sensorId=...: ${response.body}');
             throw Exception('Formato de respuesta inesperado para datos del sensor.');
         }
      } else {
        debugPrint('Error de API (fetchDataBySensorId -> /datalist?sensorId=...): ${response.statusCode}');
        debugPrint('Cuerpo del error: ${response.body}');
        throw Exception('Fallo al cargar datos para $sensorId (Código: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error al llamar/procesar API (fetchDataBySensorId -> /datalist?sensorId=...): $e');
      throw Exception('Fallo al conectar/procesar la API para datos del sensor: $e');
    }
  }
}

