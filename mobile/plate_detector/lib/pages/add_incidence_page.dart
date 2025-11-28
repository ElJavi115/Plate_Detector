import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../models/plate_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'camera_page.dart';

class AddIncidenciaPage extends StatefulWidget {
  const AddIncidenciaPage({super.key});

  @override
  State<AddIncidenciaPage> createState() => _AddIncidenciaPageState();
}

class _AddIncidenciaPageState extends State<AddIncidenciaPage> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _numeroControlCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _auth = AuthService.instance;

  PlateData? _datosPlaca;
  final List<File> _imagenesCapturadas = [];
  bool _enviando = false;
  final int _maxImagenes = 5;
  String? _latitud;
  String? _longitud;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }
Future<void> _obtenerUbicacion() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Servicio de ubicación deshabilitado');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Permisos de ubicación denegados');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Permisos de ubicación denegados permanentemente');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa los permisos de ubicación en ajustes'),
          ),
        );
      }
      return;
    }
    
    final position = await Geolocator.getCurrentPosition(
      // ignore: deprecated_member_use
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _latitud = position.latitude.toString();
      _longitud = position.longitude.toString();
    });

    debugPrint('Ubicación obtenida: $_latitud, $_longitud');
  } catch (e) {
    debugPrint('Error obteniendo ubicación: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener ubicación: $e')),
      );
    }
  }
}

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _placaCtrl.dispose();
    _nombreCtrl.dispose();
    _numeroControlCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirCamara() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraPage(paraIncidencia: true),
      ),
    );

    if (resultado != null && mounted) {
      final imagen = resultado['imagen'] as File?;
      final placa = resultado['placa'] as String?;
      final datos = resultado['datos'] as PlateData?;

      if (imagen != null && _imagenesCapturadas.length < _maxImagenes) {
        setState(() {
          _imagenesCapturadas.add(imagen);
        });
      }

      if (placa != null) {
        _placaCtrl.text = placa;
      }

      if (datos != null) {
        setState(() {
          _datosPlaca = datos;
          _nombreCtrl.text = datos.userData.nombre;
          _numeroControlCtrl.text = datos.userData.numeroControl;
          _marcaCtrl.text = datos.autoData?.marca ?? '';
          _modeloCtrl.text = datos.autoData?.modelo ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos autocompletados'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _agregarImagen() async {
    if (_imagenesCapturadas.length >= _maxImagenes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Máximo $_maxImagenes imágenes')),
      );
      return;
    }

    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (xfile != null) {
      setState(() {
        _imagenesCapturadas.add(File(xfile.path));
      });
    }
  }

  void _eliminarImagen(int index) {
    setState(() {
      _imagenesCapturadas.removeAt(index);
    });
  }

  Future<void> _buscarPorPlaca() async {
    final placa = _placaCtrl.text.trim();
    if (placa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una placa')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final api = ApiClient.instance;
      final personas = await api.obtenerUsuarios();

      PlateData? encontrado;
      for (final persona in personas) {
        final autos = await api.obtenerAutosPorPersona(persona.id);
        final auto = autos
            .where((a) =>
                a.placa.toUpperCase().replaceAll(' ', '').replaceAll('-', '') ==
                placa.toUpperCase().replaceAll(' ', '').replaceAll('-', ''))
            .firstOrNull;

        if (auto != null) {
          encontrado = PlateData(autoData: auto, userData: persona);
          break;
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (encontrado != null) {
        setState(() {
          _datosPlaca = encontrado;
          _nombreCtrl.text = encontrado?.userData.nombre ?? '';
          _numeroControlCtrl.text = encontrado?.userData.numeroControl ?? '';
          _marcaCtrl.text = encontrado?.autoData?.marca ?? '';
          _modeloCtrl.text = encontrado?.autoData?.modelo ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehículo encontrado'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Placa no encontrada en el sistema'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _crearIncidencia() async {
  if (!_formKey.currentState!.validate()) return;

  if (_datosPlaca == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debes escanear o buscar una placa válida'),
      ),
    );
    return;
  }

  final user = _auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuario no autenticado')),
    );
    return;
  }

  setState(() => _enviando = true);

  try {
    final api = ApiClient.instance;
    final descripcion = _descripcionCtrl.text.trim();
    final fecha = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final hora = DateFormat('HH:mm:ss').format(DateTime.now());
    final imagenes = _imagenesCapturadas.map((img) => img.path).toList();

    await api.crearIncidencia(
      descripcion: descripcion,
      fecha: fecha,
      hora: hora,
      imagenes: imagenes,
      personaId: _datosPlaca!.userData.id,
      reportanteId: user.id,
      autoId: _datosPlaca!.autoData!.id,
      latitud: _latitud ?? '0',  
      longitud: _longitud ?? '0',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incidencia creada exitosamente')),
    );

    Navigator.pop(context, true);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al crear incidencia: $e')),
    );
    setState(() => _enviando = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Incidencia')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📍 Ubicación',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _latitud != null && _longitud != null
                            ? 'Lat: $_latitud, Lon: $_longitud'
                            : 'Obteniendo ubicación...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _abrirCamara,
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text(
                    'ESCANEAR PLACA',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(thickness: 2),
              const SizedBox(height: 16),
              
              Text(
                'Información del Vehículo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _placaCtrl,
                decoration: InputDecoration(
                  labelText: 'Placa',
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa la placa';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _buscarPorPlaca,
                  icon: const Icon(Icons.search),
                  label: const Text(
                    'Buscar por Placa',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _marcaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _modeloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Propietario',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _numeroControlCtrl,
                decoration: const InputDecoration(
                  labelText: 'No. Control',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Requerido';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              const Divider(thickness: 2),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Evidencia (${_imagenesCapturadas.length}/$_maxImagenes)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_imagenesCapturadas.length < _maxImagenes)
                    ElevatedButton.icon(
                      onPressed: _agregarImagen,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Agregar'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (_imagenesCapturadas.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagenesCapturadas.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _imagenesCapturadas[index],
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 12,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                onPressed: () => _eliminarImagen(index),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción de la incidencia',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Estacionado en lugar prohibido',
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa una descripción';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _crearIncidencia,
                  icon: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _enviando ? 'Creando...' : 'Crear Incidencia',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}