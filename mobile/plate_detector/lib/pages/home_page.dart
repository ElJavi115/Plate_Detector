import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/home_action_fab.dart';
import 'user_section_page.dart';
import 'incidence_section_page.dart';
import 'camera_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final _auth = AuthService.instance;

  @override
  void initState() {
    super.initState();
    if (_auth.esUsuario) {
      _selectedIndex = 1;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    if (_auth.esAdmin) {
      switch (_selectedIndex) {
        case 0:
          return const UsuariosSection();
        case 1:
          return const IncidenciasSection();
        case 2:
          return const CameraPage();
        default:
          return const Center(
            child: Text('Selecciona una opción en el menú de abajo'),
          );
      }
    } else {
      switch (_selectedIndex) {
        case 0:
          return const IncidenciasSection();
        case 1:
          return const CameraPage();
        default:
          return const Center(
            child: Text('Selecciona una opción en el menú de abajo'),
          );
      }
    }
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    if (_auth.esAdmin) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Usuarios',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.warning),
          label: 'Incidencias',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: 'Cámara',
        ),
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.warning),
          label: 'Mis Incidencias',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: 'Cámara',
        ),
      ];
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detector de Placas"),
        centerTitle: true,
        actions: [
          if (user != null)
            PopupMenuButton<String>(
              icon: CircleAvatar(
                child: Text(
                  user.nombre[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  value: 'info',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user.esAdmin ? 'Administrador' : 'Usuario',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        user.numeroControl,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Cerrar sesión'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                }
              },
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: HomeActionFab(
        selectedIndex: _selectedIndex,
        esAdmin: _auth.esAdmin,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: _buildNavItems(),
      ),
    );
  }
}