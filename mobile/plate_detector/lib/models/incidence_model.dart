import 'auto_model.dart';
import 'user_model.dart';

class Incidencia {
  final int id;
  final String descripcion;
  final String fecha;
  final String hora;
  final List<String> imagenes;
  final String estatus;
  final String latitud;
  final String longitud;
  final int personaId;
  final int reportanteId;
  final int autoId;

  Incidencia({
    required this.id,
    required this.descripcion,
    required this.fecha,
    required this.hora,
    required this.imagenes,
    required this.estatus,
    required this.latitud,
    required this.longitud,
    required this.personaId,
    required this.reportanteId,
    required this.autoId,
  });

  factory Incidencia.fromJson(Map<String, dynamic> json) {
    List<String> parseImagenes(dynamic imagenesData) {
      if (imagenesData == null) return [];
      if (imagenesData is List) {
        return imagenesData.map((e) => e.toString()).toList();
      }
      if (imagenesData is String) {
        return [imagenesData];
      }
      return [];
    }

    return Incidencia(
      id: json['id'] ?? 0,
      descripcion: json['descripcion'] ?? '',
      fecha: json['fecha'] ?? '',
      hora: json['hora'] ?? '',
      imagenes: parseImagenes(json['imagenes']),
      estatus: json['estatus'] ?? 'Pendiente',
      latitud: json['latitud']?.toString() ?? '0',  
      longitud: json['longitud']?.toString() ?? '0', 
      personaId: json['personaId'] ?? 0,
      reportanteId: json['reportanteId'] ?? 0,
      autoId: json['autoId'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descripcion': descripcion,
      'fecha': fecha,
      'hora': hora,
      'imagenes': imagenes,
      'estatus': estatus,
      'latitud': latitud,
      'longitud': longitud,
      'personaId': personaId,
      'reportanteId': reportanteId,
      'autoId': autoId,
    };
  }
}

class IncidenciaDetalle {
  final Incidencia incidencia;
  final Persona? personaAfectada;
  final Persona? reportante;
  final Auto? auto;

  IncidenciaDetalle({
    required this.incidencia,
    this.personaAfectada,
    this.reportante,
    this.auto,
  });

  factory IncidenciaDetalle.fromJson(Map<String, dynamic> json) {
    final incidenciaData = json['incidencia'] as Map<String, dynamic>;
    
    return IncidenciaDetalle(
      incidencia: Incidencia(
        id: incidenciaData['id'] ?? 0,
        descripcion: incidenciaData['descripcion'] ?? '',
        fecha: incidenciaData['fecha'] ?? '',
        hora: incidenciaData['hora'] ?? '',
        imagenes: (incidenciaData['imagenes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        estatus: incidenciaData['estatus'] ?? 'Pendiente',
        latitud: incidenciaData['latitud']?.toString() ?? '0',  
        longitud: incidenciaData['longitud']?.toString() ?? '0', 
        personaId: incidenciaData['personaId'] ?? 0,
        reportanteId: incidenciaData['reportanteId'] ?? 0,
        autoId: incidenciaData['autoId'] ?? 0,
      ),
      personaAfectada: json['persona_afectada'] != null
          ? Persona.fromJson(json['persona_afectada'] as Map<String, dynamic>)
          : null,
      reportante: json['reportante'] != null
          ? Persona.fromJson(json['reportante'] as Map<String, dynamic>)
          : null,
      auto: json['auto'] != null
          ? Auto.fromJson(json['auto'] as Map<String, dynamic>)
          : null,
    );
  }
}

class IncidenciaListItem {
  final int id;
  final String descripcion;
  final String fecha;
  final String hora;
  final List<String> imagenes;
  final String estatus;
  final String latitud;
  final String longitud;
  final Persona? personaAfectada;
  final Persona? reportante;
  final Auto? auto;

  IncidenciaListItem({
    required this.id,
    required this.descripcion,
    required this.fecha,
    required this.hora,
    required this.imagenes,
    required this.estatus,
    required this.latitud,
    required this.longitud,
    this.personaAfectada,
    this.reportante,
    this.auto,
  });

  factory IncidenciaListItem.fromJson(Map<String, dynamic> json) {
    return IncidenciaListItem(
      id: json['id'] ?? 0,
      descripcion: json['descripcion'] ?? '',
      fecha: json['fecha'] ?? '',
      hora: json['hora'] ?? '',
      imagenes: (json['imagenes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      estatus: json['estatus'] ?? 'Pendiente',
      latitud: json['latitud']?.toString() ?? '0', 
      longitud: json['longitud']?.toString() ?? '0', 
      personaAfectada: json['persona_afectada'] != null
          ? Persona.fromJson(json['persona_afectada'] as Map<String, dynamic>)
          : null,
      reportante: json['reportante'] != null
          ? Persona.fromJson(json['reportante'] as Map<String, dynamic>)
          : null,
      auto: json['auto'] != null
          ? Auto.fromJson(json['auto'] as Map<String, dynamic>)
          : null,
    );
  }
}