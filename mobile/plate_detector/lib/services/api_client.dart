import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:plate_detector/models/auto_model.dart';
import 'package:plate_detector/models/incidence_model.dart';
import 'package:plate_detector/models/plate_model.dart';
import 'package:plate_detector/models/ocr_result_model.dart';
import 'package:plate_detector/models/user_model.dart';

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  //final String _baseUrl = 'https://placas-api-k5gv.onrender.com';
  final String _baseUrl = 'http://{{TU IP}}:8000';

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

  // ======= Rutas de Personas =======
  Future<PlateData> obtenerDetallePersona(int personaId) async {
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

  Future<Persona> agregarPersona(
    String nombre,
    int edad,
    String numeroControl,
    String correo,
  ) async {
    final uri = Uri.parse('$_baseUrl/personas/agregar');
    final body = jsonEncode({
      'nombre': nombre,
      'edad': edad,
      'numeroControl': numeroControl,
      'correo': correo,
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 201) {
      throw Exception('Error al añadir persona: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Persona.fromJson(data);
  }

  Future<void> eliminarPersona(int personaId) async {
    final uri = Uri.parse('$_baseUrl/personas/$personaId');

    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al eliminar persona: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<List<Persona>> obtenerPersonasConIncidencias() async {
    final uri = Uri.parse('$_baseUrl/personas/incidencias');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al obtener personas con incidencias: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Persona.fromJson(item as Map<String, dynamic>))
        .toList();
  }


Future<Persona?> login(String numeroControl) async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/personas/$numeroControl'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Persona.fromJson(data); 
    } else {
      throw Exception('Usuario no encontrado');
    }
  } catch (e) {
    return null;
  }
}


  // ======= Rutas de Autos =======

  Future<Auto> agregarAuto(
    String marca,
    String modelo,
    String color,
    String placa,
    int personaId,
  ) async {
    final uri = Uri.parse('$_baseUrl/personas/$personaId/autos');
    final body = jsonEncode({
      'marca': marca,
      'modelo': modelo,
      'color': color,
      'placa': placa,
      'personaId': personaId,
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 201) {
      throw Exception('Error al añadir auto: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Auto.fromJson(data);
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

  Future<void> eliminarAuto(int autoId) async {
    final uri = Uri.parse('$_baseUrl/autos/$autoId');

    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al eliminar auto: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<List<Auto>> obtenerAutosPorPersona(int personaId) async {
    final uri = Uri.parse('$_baseUrl/personas/$personaId/autos');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al obtener autos de la persona: ${response.statusCode}',
      );
    }

    final lista = jsonDecode(response.body) as List<dynamic>;
    return lista.map((e) => Auto.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ======= Rutas de Incidencias =======

  Future<List<IncidenciaListItem>> obtenerIncidencias(int personaId) async {
  final uri = Uri.parse('$_baseUrl/incidencias?personaId=$personaId');
  
  final response = await http.get(uri);

  if (response.statusCode != 200) {
    throw Exception('Error al obtener incidencias: ${response.statusCode}');
  }

  try {
    final data = jsonDecode(response.body) as List<dynamic>;
    
    final items = data.map((item) {
      return IncidenciaListItem.fromJson(item as Map<String, dynamic>);
    }).toList();
    
    return items;
  } catch (e) {
    rethrow;
  }
}

  Future<IncidenciaDetalle> obtenerDetalleIncidencia(int incidenciaId) async {
    final uri = Uri.parse('$_baseUrl/incidencias/$incidenciaId/detalle');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al obtener detalle de incidencia: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return IncidenciaDetalle.fromJson(json);
  }

  Future<Incidencia> crearIncidencia({
    required String descripcion,
    required String fecha,
    required String hora,
    required List<String> imagenes,
    required String latitud,
    required String longitud,
    required int personaId,
    required int reportanteId,
    required int autoId,
  }) async {
    final uri = Uri.parse('$_baseUrl/incidencias/agregar');
    final body = jsonEncode({
      'descripcion': descripcion,
      'fecha': fecha,
      'hora': hora,
      'imagenes': imagenes,
      'latitud': latitud,
      'longitud': longitud,
      'personaId': personaId,
      'reportanteId': reportanteId,
      'autoId': autoId,
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 201) {
      throw Exception('Error al crear incidencia: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Incidencia.fromJson(data);
  }

  Future<void> actualizarEstatusIncidencia(
    int incidenciaId,
    String estatus,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/incidencias/$incidenciaId/estatus?estatus=$estatus',
    );
    final response = await http.patch(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al actualizar estatus: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> eliminarIncidencia(int incidenciaId) async {
    final uri = Uri.parse('$_baseUrl/incidencias/$incidenciaId');
    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al eliminar incidencia: ${response.statusCode} ${response.body}',
      );
    }
  }


}
