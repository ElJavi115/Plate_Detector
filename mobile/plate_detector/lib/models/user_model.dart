class Persona {
  final int id;
  final String nombre;
  final int edad;
  final String numeroControl;
  final String correo;
  final String estatus;
  final int noIncidencias;
  final int? perfilId;

  Persona({
    required this.id,
    required this.nombre,
    required this.edad,
    required this.numeroControl,
    required this.correo,
    required this.estatus,
    required this.noIncidencias,
    this.perfilId,
  });

  bool get esAdmin => perfilId == 2;
  bool get esUsuario => perfilId == 1;

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      edad: json['edad'] ?? 0,
      numeroControl: json['numeroControl'] ?? '',
      correo: json['correo'] ?? '',
      estatus: json['estatus'] ?? 'Autorizado',
      noIncidencias: json['noIncidencias'] ?? 0, 
      perfilId: json['perfil_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'edad': edad,
      'numeroControl': numeroControl,
      'correo': correo,
      'estatus': estatus,
      'noIncidencias': noIncidencias,
      'perfil_id': perfilId,
    };
  }
}
