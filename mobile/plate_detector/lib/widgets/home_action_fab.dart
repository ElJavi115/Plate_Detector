import 'package:flutter/material.dart';

class HomeActionFab extends StatelessWidget {
  final int selectedIndex;
  final bool esAdmin;

  const HomeActionFab({
    super.key,
    required this.selectedIndex,
    required this.esAdmin,
  });

  @override
  Widget build(BuildContext context) {
    if (esAdmin) {
      switch (selectedIndex) {
        case 0:
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(context, '/usuarios/agregar');
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar usuario'),
          );

        case 1:
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(context, '/incidencias/agregar');
            },
            icon: const Icon(Icons.add),
            label: const Text('Crear incidencia'),
          );

        case 2:
          return const SizedBox.shrink();

        default:
          return const SizedBox.shrink();
      }
    } else {
      switch (selectedIndex) {
        case 0:
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(context, '/incidencias/agregar');
            },
            icon: const Icon(Icons.add),
            label: const Text('Crear incidencia'),
          );

        case 1:
          return const SizedBox.shrink();

        default:
          return const SizedBox.shrink();
      }
    }
  }
}