import 'package:flutter/material.dart';
import 'package:plate_detector/pages/user_section_page.dart';

import '../widgets/home_action_fab.dart';
import 'camera_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const UsuariosSection();   
      case 1:
        return Text('Autos Section');    
      case 2:
        return const CameraPage();
      default:
        return const Center(
          child: Text('Selecciona una opción en el menú de abajo'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detector de Placas"),
        centerTitle: true,
      ),

      body: _buildBody(),

      floatingActionButton: HomeActionFab(selectedIndex: _selectedIndex),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Usuarios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.car_crash),
            label: 'Autos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Cámara',
          ),
        ],
      ),
    );
  }
}

class AutosSection {
  const AutosSection();
}
