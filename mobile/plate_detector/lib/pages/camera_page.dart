// lib/pages/camera_page.dart
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../models/plate_model.dart';
import 'user_detail_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();
      setState(() {});
    } catch (e) {
      debugPrint('Error al inicializar cámara: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _scanPlate() async {
    if (_controller == null || _initializeControllerFuture == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _initializeControllerFuture!;

      // 1. Tomar foto
      final file = await _controller!.takePicture();
      final imageFile = File(file.path);

      // 2. Mandar imagen a la API (Python con PaddleOCR)
      final api = ApiClient.instance;
      final PlateData? placaInfo = await api.datosPorImagen(imageFile);

      setState(() {
        _isProcessing = false;
      });

      if (!mounted) return;

      if (placaInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Placa no registrada')),
        );
        return;
      }

      // 3. Navegar a la pantalla de detalles
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserDetailPage(
            placaReconocida: placaInfo.autoData.placa, // o la que detecte Python
            data: placaInfo,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error en _scanPlate: $e');
      setState(() {
        _isProcessing = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar la placa')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(title: const Text("Cámara / Detector")),
      body: controller == null || _initializeControllerFuture == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FutureBuilder(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return CameraPreview(controller);
                    } else {
                      return const Center(child: CircularProgressIndicator());
                    }
                  },
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 260,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.9),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _scanPlate,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt),
                        label: Text(
                          _isProcessing ? 'Procesando...' : 'Escanear placa',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
