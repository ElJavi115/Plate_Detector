import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/plate_model.dart';

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  final String _baseUrl = 'https://placas-api-k5gv.onrender.com';

  Future<PlateData?> datosPorPlaca(String placa) async {
    final uri = Uri.parse('$_baseUrl/autos/placa/$placa');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PlateData.fromJson(json);
    }

    if (response.statusCode == 404) {
      return null;
    }

    throw Exception('Error al consultar API: ${response.statusCode}');
  }

  Future<PlateData?> datosPorImagen(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/ocr-placa');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PlateData.fromJson(json);
    }

    if (response.statusCode == 404) {
      // Placa no registrada
      return null;
    }

    throw Exception('Error en OCR/consulta API: ${response.statusCode}');
  }
}

