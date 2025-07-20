import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class IrrigationPredictor {
  late Interpreter _interpreter;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model/irrigation_model.tflite');
    } catch (e) {
      print('Model yüklenirken hata: $e');
    }
  }

  String predictIrrigation(double humidity, double temperature, double ph) {
    // Girdiyi normalize et (eğitimde kullanılan scaler ile aynı parametreler)
    final input = [[
      (humidity - 50) / 15,   // Ortalama=50, Std=15
      (temperature - 22) / 5,  // Ortalama=22, Std=5
      (ph - 6.5) / 0.5        // Ortalama=6.5, Std=0.5
    ]];

    // 1. Değişiklik: output listesini double elemanlarla başlatın
    final output = List.filled(1 * 4, 0.0).reshape([1, 4]); // 0 yerine 0.0
    _interpreter.run(input, output);

    // 2. Değişiklik: output[0]'ı List<double>'a dönüştürün
    // Modelden gelen çıktının List<dynamic> olabileceğini varsayalım
    final List<dynamic> rawProbabilities = output[0];
    final List<double> probabilities = rawProbabilities.map((e) => (e as num).toDouble()).toList();
    // Alternatif olarak, eğer tüm elemanların zaten sayısal olduğu ve double'a
    // dönüştürülebilir olduğu kesinse daha kısa bir yol:
    // final List<double> probabilities = List<double>.from(output[0]);

    // Ham çıktıları ve dönüştürülmüş olasılıkları yazdırmak hata ayıklamada yardımcı olabilir:
    print('Ham model çıktısı (output[0]): $rawProbabilities');
    print('Dönüştürülmüş olasılıklar: $probabilities');

    final prediction = probabilities.argmax(); // Şimdi probabilities List<double> türünde

    switch(prediction) {
      case 0: return "Sulama gerekli değil";
      case 1: return "2 saat sonra sulama";
      case 2: return "1 saat sonra sulama";
      case 3: return "HEMEN SULAMA YAPIN";
      default: return "Bilinmeyen durum";
    }
  }


  void dispose() {
    _interpreter.close();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late IrrigationPredictor _predictor;
  String _predictionResult = "Model henüz çalıştırılmadı.";
  bool _modelLoaded = false;
  bool _isPredicting = false;

  // Test için örnek değerler
  final double _sampleHumidity = 75.0;
  final double _sampleTemperature = 25.0;
  final double _samplePh = 6.0;

  @override
  void initState() {
    super.initState();
    _predictor = IrrigationPredictor();
    _loadModelAndPredictor();
  }

  Future<void> _loadModelAndPredictor() async {
    await _predictor.loadModel();
    // Model yüklendikten sonra UI'ı güncellemek için
    if (mounted) {
      setState(() {
        _modelLoaded = true;
        _predictionResult = "Model yüklendi. Tahmin için butona basın.";
      });
    }
  }

  Future<void> _runPrediction() async {
    if (!_modelLoaded) {
      setState(() {
        _predictionResult = "Model henüz yüklenmedi!";
      });
      return;
    }

    setState(() {
      _isPredicting = true;
    });

    // Örnek girdi değerleri (bunları kullanıcıdan alabilir veya sensörlerden okuyabilirsiniz)
    try {
      final result = _predictor.predictIrrigation(
          _sampleHumidity, _sampleTemperature, _samplePh);
      setState(() {
        _predictionResult = "Tahmin: $result";
      });
    } catch (e) {
      setState(() {
        _predictionResult = "Tahmin sırasında hata: $e";
      });
      print("Tahmin hatası: $e");
    } finally {
      setState(() {
        _isPredicting = false;
      });
    }
  }

  @override
  void dispose() {
    _predictor.dispose(); // Interpreter'ı serbest bırakmayı unutmayın
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sulama Tahmini'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Örnek Veriler:\nNem: $_sampleHumidity%, Sıcaklık: $_sampleTemperature°C, pH: $_samplePh',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              if (!_modelLoaded)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("Model yükleniyor..."),
                  ],
                )
              else if (_isPredicting)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("Tahmin yapılıyor..."),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: _runPrediction,
                  child: const Text('Sulama Tahmini Yap'),
                ),
              const SizedBox(height: 30),
              Text(
                _predictionResult,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Argmax extension'ı eklemeyi unutmayın (eğer yoksa)
extension Argmax on List<double> {
  int argmax() {
    if (isEmpty) {
      throw ArgumentError("List is empty");
    }
    double maxVal = this[0];
    int maxIdx = 0;
    for (int i = 1; i < length; i++) {
      if (this[i] > maxVal) {
        maxVal = this[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }
}
