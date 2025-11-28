import 'package:flutter/material.dart';
import 'package:plate_detector/services/api_client.dart';


class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _numeroControlCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();

  bool _enviando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _edadCtrl.dispose();
    _numeroControlCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarPersona() async {
    final form = _formKey.currentState;
    if (form == null) return;

    if (!form.validate()) return;

    setState(() {
      _enviando = true;
    });

    try {
      final api = ApiClient.instance;

      final nombre = _nombreCtrl.text.trim();
      final edad = int.parse(_edadCtrl.text.trim());
      final numeroControl = _numeroControlCtrl.text.trim();
      final correo = _correoCtrl.text.trim();

      final nuevaPersona =
          await api.agregarPersona(
            nombre, 
            edad, 
            numeroControl,
            correo);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario "${nuevaPersona.nombre}" creado correctamente'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar usuario: $e')),
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
        title: const Text('Agregar usuario'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nombre
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Número de control
              TextFormField(
                controller: _numeroControlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número de control',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un número de control';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Edad
              TextFormField(
                controller: _edadCtrl,
                decoration: const InputDecoration(
                  labelText: 'Edad',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa la edad';
                  }
                  final n = int.tryParse(value);
                  if (n == null || n <= 0) {
                    return 'Edad inválida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Correo
              TextFormField(
                controller: _correoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un correo';
                  }
                  if (!value.contains('@')) {
                    return 'Correo inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _guardarPersona,
                  icon: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_enviando ? 'Guardando...' : 'Guardar usuario'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
