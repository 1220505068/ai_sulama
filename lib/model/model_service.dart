import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';


class ModelService {
  late Interpreter _interpreter;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model/sulama_model.tflite');
      print('✅ Model başarıyla yüklendi.');
    } catch (e) {
      print('❌ Model yüklenirken hata oluştu: $e');
    }
  }

  // Örnek input: [nem, sıcaklık]
  Future<List<double>> tahminYap(List<double> input) async {
    var inputTensor = [input];
    var outputTensor = List.filled(1 * 1, 0.0).reshape([1, 1]);

    _interpreter.run(inputTensor, outputTensor);
    return outputTensor[0];
  }
}
