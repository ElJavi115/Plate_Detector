import 'package:flutter/material.dart';
import 'package:plate_detector/pages/user_detail_page.dart';

import '../../models/user_model.dart';
import '../../services/api_client.dart';

class UsuariosSection extends StatefulWidget {
  const UsuariosSection({super.key});

  @override
  State<UsuariosSection> createState() => _UsuariosSectionState();
}

class _UsuariosSectionState extends State<UsuariosSection> {
  final TextEditingController _searchController = TextEditingController();

  List<Persona> _usuarios = [];
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    try {
      final api = ApiClient.instance;
      final data = await api.obtenerUsuarios();
      setState(() {
        _usuarios = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error al cargar usuarios:\n$_error'),
        ),
      );
    }

    final filtered = _usuarios.where((u) {
      final q = _query;
      if (q.isEmpty) return true;

      final nombre = u.nombre.toLowerCase();
      final numeroControl = u.numeroControl.toLowerCase();
      final correo = u.correo.toLowerCase();
      final estatus = u.estatus.toLowerCase();
      final noIncidencias = u.noIncidencias.toString().toLowerCase();

      return nombre.contains(q) ||
          numeroControl.contains(q) ||
          correo.contains(q) ||
          estatus.contains(q) ||
          noIncidencias.contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar usuario',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No se encontraron usuarios'),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(user.nombre),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No. Control: ${user.numeroControl}'),
                              Text('Correo: ${user.correo}'),
                              Text('Estatus: ${user.estatus}'),
                              Text('Incidencias: ${user.noIncidencias}'),
                            ],
                          ),
                          onTap: () async {
                            try {
                              final api = ApiClient.instance;
                              final plateData = await api
                                  .obtenerDetallePersona(user.id);

                              final placa = plateData.autoData.placa;

                              if (!mounted) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserDetailPage(
                                    placaReconocida: placa,
                                    data: plateData,
                                    mostrarCoincidencia: false,
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error al cargar detalle: $e',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
