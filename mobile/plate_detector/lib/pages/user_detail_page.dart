import 'package:flutter/material.dart';
import 'package:plate_detector/models/auto_model.dart';
import 'package:plate_detector/models/plate_model.dart';
import 'package:plate_detector/models/user_model.dart';
import 'package:plate_detector/pages/add_vehicle_page.dart';
import 'package:plate_detector/services/api_client.dart';

class UserDetailPage extends StatefulWidget {
  final String placaReconocida;
  final PlateData data;
  final bool mostrarCoincidencia;
  const UserDetailPage({
    super.key,
    required this.placaReconocida,
    required this.data,
    this.mostrarCoincidencia = true,
  });

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  late final Persona usuario;
  Auto? autoPrincipal;
  late Future<List<Auto>> _autosFuture;

  @override
  void initState() {
    super.initState();
    usuario = widget.data.userData;
    autoPrincipal = widget.data.autoData;
    _autosFuture = ApiClient.instance.obtenerAutosPorPersona(usuario.id);
  }

  @override
  Widget build(BuildContext context) {
    final placaReconocida = widget.placaReconocida;

    return Scaffold(
      appBar: AppBar(
        title: widget.mostrarCoincidencia
            ? const Text('Detalles de la placa / usuario')
            : const Text('Detalles del usuario'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info de placa detectada
          if (widget.mostrarCoincidencia && autoPrincipal != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Placa detectada',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      placaReconocida,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Propietario
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Propietario',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  _row('Nombre', usuario.nombre),
                  _row('Edad', '${usuario.edad} años'),
                  _row('Número de control', usuario.numeroControl),
                  _row('Correo', usuario.correo),
                  _row('Estatus', usuario.estatus),
                  _row('No. Incidencias', usuario.noIncidencias.toString()),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Autos del usuario',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),

          FutureBuilder<List<Auto>>(
            future: _autosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Error al cargar autos: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final autos = snapshot.data ?? [];

              if (autos.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Este usuario no tiene autos registrados.'),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: autos.length,
                itemBuilder: (context, index) {
                  final a = autos[index];
                  final esDetectada =
                      widget.mostrarCoincidencia &&
                      normalizarPlaca(a.placa) ==
                          normalizarPlaca(placaReconocida);

                  return Card(
                    color: esDetectada ? Colors.green.withOpacity(0.1) : null,
                    child: ListTile(
                      title: Text(a.placa),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Marca: ${a.marca}'),
                          Text('Modelo: ${a.modelo}'),
                          Text('Color: ${a.color}'),
                          if (esDetectada)
                            const Text(
                              'Coincide con placa detectada',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      trailing: widget.mostrarCoincidencia
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Eliminar auto'),
                                    content: Text(
                                      '¿Estás seguro de eliminar el auto "${a.placa}"? Esta acción no se puede deshacer.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    await ApiClient.instance.eliminarAuto(a.id);
                                    setState(() {
                                      _autosFuture = ApiClient.instance
                                          .obtenerAutosPorPersona(usuario.id);
                                    });
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Auto "${a.placa}" eliminado',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error al eliminar auto: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          // Botones de acción (
          if (widget.mostrarCoincidencia) ...[
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: () async {
                final creado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddVehiclePage(personaId: usuario.id),
                  ),
                );

                if (creado == true) {
                  setState(() {
                    _autosFuture = ApiClient.instance.obtenerAutosPorPersona(
                      usuario.id,
                    );
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Agregar auto'),
            ),
          ],
        ],
      ),
    );
  }

  String normalizarPlaca(String placa) {
    return placa.toUpperCase().replaceAll(' ', '');
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
