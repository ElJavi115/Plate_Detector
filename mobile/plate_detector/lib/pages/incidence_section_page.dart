import 'package:flutter/material.dart';
import '../models/incidence_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'incidence_detail_page.dart';

class IncidenciasSection extends StatefulWidget {
  const IncidenciasSection({super.key});

  @override
  State<IncidenciasSection> createState() => _IncidenciasSectionState();
}

class _IncidenciasSectionState extends State<IncidenciasSection> {
  final _searchController = TextEditingController();
  final _auth = AuthService.instance;

  List<IncidenciaListItem> _incidencias = [];
  String _query = '';
  bool _loading = true;
  String? _error;
  String _filtroEstatus = 'Todas';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
    _cargarIncidencias();
  }

Future<void> _cargarIncidencias() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }
    
    final data = await ApiClient.instance.obtenerIncidencias(user.id);
    
    setState(() {
      _incidencias = data;
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _loading = false;
      _error = e.toString();
    });
  }
}

  Color _getEstatusColor(String estatus) {
    switch (estatus.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'aprobada':
        return Colors.green;
      case 'rechazada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getEstatusIcon(String estatus) {
    switch (estatus.toLowerCase()) {
      case 'pendiente':
        return Icons.hourglass_empty;
      case 'aprobada':
        return Icons.check_circle;
      case 'rechazada':
        return Icons.cancel;
      default:
        return Icons.help;
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al cargar incidencias:\n$_error'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarIncidencias,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final filtered = _incidencias.where((inc) {
      final matchQuery =
          _query.isEmpty ||
          inc.descripcion.toLowerCase().contains(_query) ||
          (inc.personaAfectada?.nombre.toLowerCase().contains(_query) ==
              true) ||
          (inc.auto?.placa.toLowerCase().contains(_query) == true);

      final matchEstatus =
          _filtroEstatus == 'Todas' ||
          inc.estatus.toLowerCase() == _filtroEstatus.toLowerCase();

      return matchQuery && matchEstatus;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar incidencia',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          if (_auth.esAdmin)
            DropdownButtonFormField<String>(
              initialValue: _filtroEstatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Estatus',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                DropdownMenuItem(value: 'Pendiente', child: Text('Pendientes')),
                DropdownMenuItem(value: 'Aprobada', child: Text('Aprobadas')),
                DropdownMenuItem(value: 'Rechazada', child: Text('Rechazadas')),
              ],
              onChanged: (String? newValue) {
                if (newValue == null) return;
                setState(() {
                  _filtroEstatus = newValue;
                });
              },
            ),

          const SizedBox(height: 16),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay incidencias',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargarIncidencias,
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final inc = filtered[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getEstatusColor(
                                inc.estatus,
                              ).withOpacity(0.2),
                              child: Icon(
                                _getEstatusIcon(inc.estatus),
                                color: _getEstatusColor(inc.estatus),
                              ),
                            ),
                            title: Text(
                              inc.descripcion,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (inc.personaAfectada != null)
                                  Text(
                                    'Afectado: ${inc.personaAfectada!.nombre}',
                                  ),
                                if (inc.auto != null)
                                  Text('Vehículo: ${inc.auto!.placa}'),
                                Text('Fecha: ${inc.fecha} - ${inc.hora}'),
                                const SizedBox(height: 4),
                                Chip(
                                  label: Text(
                                    inc.estatus,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: _getEstatusColor(
                                    inc.estatus,
                                  ).withOpacity(0.2),
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => IncidenciaDetailPage(
                                    incidenciaId: inc.id,
                                  ),
                                ),
                              );
                              _cargarIncidencias();
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
