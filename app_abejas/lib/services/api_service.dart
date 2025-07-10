import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io'; 
import 'package:http/http.dart' as http;
import 'package:app_abejas/models/sensor_data.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});
  Future<List<SensorData>> fetchAllData() async {
    final uri = Uri.parse('$baseUrl/datalist');
    debugPrint('Fetching all data from: $uri');

    try {
      final response = await http.get(uri); 

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => SensorData.fromJson(item)).toList();
      } else {
        throw Exception('Falló al cargar los datos. Código de estado: ${response.statusCode}. Cuerpo de respuesta: ${response.body}');
      }
    } on SocketException {
      throw Exception('Error de conexión a internet. Por favor, verifica tu conexión.');
    } on FormatException catch (e) {
      throw Exception('Error al decodificar la respuesta JSON: $e');
    } catch (e) {
      throw Exception('Ocurrió un error inesperado al cargar los datos: $e');
    }
  }
}
