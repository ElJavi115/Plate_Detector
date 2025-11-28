import 'package:flutter/material.dart';
import 'package:plate_detector/services/api_client.dart';
import 'package:plate_detector/models/auto_model.dart';

class AddVehiclePage extends StatefulWidget {
  final int personaId;

  const AddVehiclePage({
    super.key,
    required this.personaId,
  });

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();

  final _placaCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  bool _enviando = false;

  @override
  void dispose() {
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarAuto() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    setState(() {
      _enviando = true;
    });

    try {
      final api = ApiClient.instance;

      final placa = _placaCtrl.text.trim();
      final marca = _marcaCtrl.text.trim();
      final modelo = _modeloCtrl.text.trim();
      final color = _colorCtrl.text.trim();

      final Auto nuevoAuto = await api.agregarAuto(
        marca,
        modelo,
        color,
        placa,
        widget.personaId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto "${nuevoAuto.placa}" creado correctamente'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar auto: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar auto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Placa
              TextFormField(
                controller: _placaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Placa',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa la placa';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Marca
              TextFormField(
                controller: _marcaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa la marca';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Modelo
              TextFormField(
                controller: _modeloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el modelo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Color
              TextFormField(
                controller: _colorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el color';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _guardarAuto,
                  icon: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.directions_car),
                  label: Text(
                    _enviando ? 'Guardando...' : 'Guardar auto',
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
