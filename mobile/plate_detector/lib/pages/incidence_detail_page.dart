import 'dart:io';
import 'package:flutter/material.dart';
import '../models/incidence_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class IncidenciaDetailPage extends StatefulWidget {
  final int incidenciaId;

  const IncidenciaDetailPage({super.key, required this.incidenciaId});

  @override
  State<IncidenciaDetailPage> createState() => _IncidenciaDetailPageState();
}

class _IncidenciaDetailPageState extends State<IncidenciaDetailPage> {
  final _auth = AuthService.instance;
  IncidenciaDetalle? _detalle;
  bool _loading = true;
  String? _error;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detalle = await ApiClient.instance.obtenerDetalleIncidencia(
        widget.incidenciaId,
      );
      setState(() {
        _detalle = detalle;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _cambiarEstatus(String nuevoEstatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$nuevoEstatus incidencia'),
        content: Text(
          '¿Estás seguro de marcar esta incidencia como "$nuevoEstatus"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstatus == 'Aprobada'
                  ? Colors.green
                  : Colors.red,
            ),
            child: Text(nuevoEstatus),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _procesando = true);

    try {
      await ApiClient.instance.actualizarEstatusIncidencia(
        widget.incidenciaId,
        nuevoEstatus,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Incidencia $nuevoEstatus correctamente')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _procesando = false);
    }
  }

  Future<void> _eliminarIncidencia() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar incidencia'),
        content: const Text(
          '¿Estás seguro de eliminar esta incidencia? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _procesando = true);

    try {
      await ApiClient.instance.eliminarIncidencia(widget.incidenciaId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incidencia eliminada')));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      setState(() => _procesando = false);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de incidencia')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _detalle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de incidencia')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargarDetalle,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final inc = _detalle!.incidencia;
    final persona = _detalle!.personaAfectada;
    final reportante = _detalle!.reportante;
    final auto = _detalle!.auto;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de incidencia'),
        actions: [
          if (_auth.esAdmin && inc.estatus.toLowerCase() != 'pendiente')
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _procesando ? null : _eliminarIncidencia,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Estatus',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(inc.estatus),
                        backgroundColor: _getEstatusColor(
                          inc.estatus,
                        ).withOpacity(0.2),
                      ),
                    ],
                  ),
                  const Divider(),
                  _row('Fecha y Hora', '${inc.fecha} - ${inc.hora}'),
                  _row('Descripción', inc.descripcion),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (persona != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Persona Afectada',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Divider(),
                    _row('Nombre', persona.nombre),
                    _row('No. Control', persona.numeroControl),
                    _row('Correo', persona.correo),
                    _row('Estatus', persona.estatus),
                    _row(
                      'Incidencias totales',
                      persona.noIncidencias.toString(),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          if (reportante != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reportante',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Divider(),
                    _row('Nombre', reportante.nombre),
                    _row('No. Control', reportante.numeroControl),
                    _row('Correo', reportante.correo),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          if (auto != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehículo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Divider(),
                    _row('Placa', auto.placa),
                    _row('Marca', auto.marca),
                    _row('Modelo', auto.modelo),
                    _row('Color', auto.color),
                  ],
                ),
              ),
            ),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Imagenes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const Divider(),
                  Column(
                    children: inc.imagenes.map((imgUrl) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(
                              imgUrl,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 48),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (_auth.esAdmin && inc.estatus.toLowerCase() == 'pendiente')
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _procesando
                        ? null
                        : () => _cambiarEstatus('Aprobada'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Aprobar Incidencia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _procesando
                        ? null
                        : () => _cambiarEstatus('Rechazada'),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Rechazar Incidencia'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
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
