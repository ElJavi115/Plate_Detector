import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
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
  File? _capturedImage;

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

      final xfile = await _controller!.takePicture();
      final imageFile = File(xfile.path);

      setState(() {
        _capturedImage = imageFile;
      });

      final api = ApiClient.instance;
      final ocrResult = await api.ocrPlacaFromImage(imageFile);

      final placaReconocida = ocrResult.placaNormalizada;
      final matchBd = ocrResult.match;

      setState(() {
        _isProcessing = false;
      });

      if (!mounted) return;

      if (placaReconocida.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo decodificar una placa válida'),
          ),
        );
        return;
      }

      if (matchBd == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Placa leída: $placaReconocida (no registrada)'),
          ),
        );
        return;
      }


      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              UserDetailPage(placaReconocida: placaReconocida, data: matchBd, mostrarCoincidencia: true)
        ),
      );

      setState(() {
        _capturedImage = null;
      });
    } catch (e, st) {
      debugPrint('Error en _scanPlate: $e');
      debugPrint(st.toString());
      setState(() {
        _isProcessing = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar la placa')),
      );
    }
  }

  Widget _buildPreview() {
    if (_capturedImage != null && _isProcessing) {
      return SizedBox.expand(
        child: FittedBox(fit: BoxFit.cover, child: Image.file(_capturedImage!)),
      );
    }

    final controller = _controller;
    if (controller == null || _initializeControllerFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return CameraPreview(controller);
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cámara / Detector")),
      body: Stack(
        children: [
          _buildPreview(),

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

          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Procesando...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
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
