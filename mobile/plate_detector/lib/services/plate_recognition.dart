import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class PlateRecognitionResult {
  final String plateText;
  final double? confidence;

  PlateRecognitionResult({
    required this.plateText,
    this.confidence,
  });
}
class PlateRecognitionPipeline {
  PlateRecognitionPipeline._internal();
  static final PlateRecognitionPipeline instance =
      PlateRecognitionPipeline._internal();

  tfl.Interpreter? _interpreter;
  List<int>? _inputShape;  // [1, H, W, C]
  List<int>? _outputShape; // p.ej. [1, T, numClasses]

  bool get isReady => _interpreter != null;

  Future<void> _ensureInterpreter() async {
    if (_interpreter != null) return;

    _interpreter = await tfl.Interpreter.fromAsset(
      'assets/models/plate_detector.tflite',
    );

    final inputT = _interpreter!.getInputTensor(0);
    final outputT = _interpreter!.getOutputTensor(0);

    _inputShape = inputT.shape;
    _outputShape = outputT.shape;
  }

  List _preprocessImage(File imageFile) {
    if (_inputShape == null) {
      throw StateError('Interprete no inicializado');
    }

    final h = _inputShape![1];
    final w = _inputShape![2];
    final c = _inputShape![3];

    final bytes = imageFile.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('No se pudo decodificar la imagen');
    }

    final resized = img.copyResize(
      decoded,
      width: w,
      height: h,
    );

    final inputSize = h * w * c;
    final buffer = List<double>.filled(inputSize, 0.0);

    int index = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = resized.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);

        buffer[index++] = r / 255.0;
        buffer[index++] = g / 255.0;
        buffer[index++] = b / 255.0;
      }
    }

    return buffer.reshape([1, h, w, c]);
  }

  Future<String> recognize(File imageFile) async {
    await _ensureInterpreter();

    final input = _preprocessImage(imageFile);

    if (_outputShape == null) {
      throw StateError('Output shape no inicializado');
    }

    final totalOutputSize =
        _outputShape!.reduce((value, element) => value * element);
    final flatOutput = List<double>.filled(totalOutputSize, 0.0);

    final output = flatOutput.reshape(_outputShape!);

    _interpreter!.run(input, output);

    final result = _decodeOutputToPlate(output);
    return result.plateText;
  }

  PlateRecognitionResult _decodeOutputToPlate(List<dynamic> output) {
    if (output.isEmpty) {
      throw Exception('Output vacío del modelo');
    }

    final seqOutputs = output[0] as List<dynamic>;

    const String charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-';
    const int blankIndex = 0;

    final buffer = StringBuffer();
    int? lastCharIdx;

    for (int t = 0; t < seqOutputs.length; t++) {
      final timeStep = seqOutputs[t] as List<dynamic>; 

      int bestIndex = 0;
      double bestScore = double.negativeInfinity;

      for (int c = 0; c < timeStep.length; c++) {
        final s = (timeStep[c] as num).toDouble();
        if (s > bestScore) {
          bestScore = s;
          bestIndex = c;
        }
      }

      if (bestIndex == blankIndex) {
        lastCharIdx = null;
        continue;
      }

      if (lastCharIdx != null && bestIndex == lastCharIdx) {
        continue;
      }

      final charIdx = bestIndex - 1; 
      if (charIdx >= 0 && charIdx < charset.length) {
        buffer.write(charset[charIdx]);
        lastCharIdx = bestIndex;
      }
    }

    final plateText = buffer.toString().trim();
    if (plateText.isEmpty) {
      throw Exception('No se pudo decodificar una placa válida');
    }

    return PlateRecognitionResult(
      plateText: plateText,
      confidence: null,
    );
  }
}

extension _ReshapeExtension<T> on List<T> {
  List reshape(List<int> dims) {
    if (dims.isEmpty) {
      throw ArgumentError('dims no puede ser vacío');
    }
    final total = dims.reduce((a, b) => a * b);
    if (total != length) {
      throw ArgumentError(
        'No se puede reshapear: length=$length, dims product=$total',
      );
    }

    dynamic reshape(List<T> data, List<int> dims) {
      if (dims.length == 1) return data;
      final size = dims.first;
      final rest = dims.sublist(1);
      final chunkSize = rest.reduce((a, b) => a * b);

      final result = <dynamic>[];
      for (int i = 0; i < size; i++) {
        final start = i * chunkSize;
        final end = start + chunkSize;
        result.add(reshape(data.sublist(start, end), rest));
      }
      return result;
    }

    return reshape(this, dims) as List;
  }
}
