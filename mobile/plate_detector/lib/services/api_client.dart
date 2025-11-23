import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:plate_detector/models/auto_model.dart';
import 'package:plate_detector/models/plate_model.dart';
import 'package:plate_detector/models/ocr_result_model.dart';
import 'package:plate_detector/models/user_model.dart';

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  final String _baseUrl = 'https://placas-api-k5gv.onrender.com';

  Future<OcrResult> ocrPlacaFromImage(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/ocr/placa');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Error OCR API: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final ocr = data['ocr'] as Map<String, dynamic>?;
    final matchBd = data['match_bd'];

    if (ocr == null) {
      throw Exception('Respuesta OCR inválida (sin campo "ocr")');
    }

    final textoCrudo = (ocr['texto_crudo'] ?? '') as String;
    final placaNormalizada = (ocr['placa_normalizada'] ?? '') as String;
    final score = (ocr['score'] as num?)?.toDouble();

    PlateData? match;
    if (matchBd != null) {
      match = PlateData.fromJson(matchBd as Map<String, dynamic>);
    }

    return OcrResult(
      textoCrudo: textoCrudo,
      placaNormalizada: placaNormalizada,
      score: score,
      match: match,
    );
  }

   Future<PlateData> obtenerDetallePersona(String personaId) async {
    final uri = Uri.parse('$_baseUrl/personas/$personaId/detalle');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al obtener detalle de persona: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return PlateData.fromJson(json);
  }

  Future<List<Persona>> obtenerUsuarios() async {
    final uri = Uri.parse('$_baseUrl/personas');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error al obtener usuarios: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Persona.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Auto>> obtenerAutos() async {
    final uri = Uri.parse('$_baseUrl/autos');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error al obtener autos: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Auto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Auto>> obtenerAutosPorPersona(String personaId) async {
    final uri = Uri.parse('$_baseUrl/personas/$personaId/autos');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al obtener autos de la persona: ${response.statusCode}',
      );
    }

    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista
        .map((e) => Auto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
