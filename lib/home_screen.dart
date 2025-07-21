import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart'; // EKLENDİ
import 'dart:io' show Platform; // EKLENDİ


class IrrigationPredictor {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model/irrigation_model.tflite');
      _isModelLoaded = true;
      print('Model başarıyla yüklendi.');
    } catch (e) {
      _isModelLoaded = false;
      print('Model yüklenirken hata: $e');
      throw Exception('Model yüklenemedi: $e');
    }
  }

  bool get isModelReady => _isModelLoaded;

  String predictIrrigation(double humidity, double temperature, double ph) {
    if (!_isModelLoaded) {
      return "Model henüz yüklenmedi veya yüklenirken hata oluştu.";
    }
    final input = [[
      (humidity - 50) / 15,
      (temperature - 22) / 5,
      (ph - 6.5) / 0.5
    ]];
    final output = List.filled(1 * 4, 0.0).reshape([1, 4]);
    try {
      _interpreter.run(input, output);
    } catch (e) {
      print('Model çalıştırılırken hata: $e');
      return "Tahmin sırasında model hatası: $e";
    }
    final List<dynamic> rawProbabilities = output[0];
    final List<double> probabilities = rawProbabilities.map((e) {
      if (e is num) {
        return e.toDouble();
      }
      print('Model çıktısında beklenmeyen tür veya null değer: $e');
      return 0.0;
    }).toList();

    print('Ham model girdisi: $input');
    print('Ham model çıktısı (output[0]): $rawProbabilities');
    print('Dönüştürülmüş olasılıklar: $probabilities');

    if (probabilities.isEmpty) {
      return "Tahmin yapılamadı (olasılıklar boş).";
    }
    final prediction = probabilities.argmax();
    switch(prediction) {
      case 0: return "Sulama gerekli değil";
      case 1: return "2 saat sonra sulama";
      case 2: return "1 saat sonra sulama";
      case 3: return "HEMEN SULAMA YAPIN";
      default: return "Bilinmeyen tahmin sonucu";
    }
  }

  void dispose() {
    if (_isModelLoaded) {
      _interpreter.close();
      _isModelLoaded = false;
      print('Model serbest bırakıldı.');
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late IrrigationPredictor _predictor;
  String _predictionResult = "Model henüz çalıştırılmadı.";
  bool _isProcessing = false;

  final double _sampleHumidity = 75.0;
  final double _sampleTemperature = 25.0;
  final double _samplePh = 6.0;

  @override
  void initState() {
    super.initState();
    _predictor = IrrigationPredictor();
    _loadModel();
    _initializeNotifications(); // Güncellenmiş metodu çağıracak
  }

  // _initializeNotifications METODU GÜNCELLENDİ VE ASYNC YAPILDI
  Future<void> _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) { // Android 13 (API 33) ve üzeri
        final bool? granted = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        print("Bildirim izni verildi: $granted");
        if (granted == null || !granted) {
          print("Kullanıcı bildirim iznini vermedi.");
          // İsteğe bağlı: Kullanıcıya neden bildirimlerin önemli olduğunu açıklayan bir mesaj gösterilebilir.
        }
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher'); // İkonunuzun doğru olduğundan emin olun

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      // iOS ayarları da buraya eklenebilir (gerekirse)
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        final String? payload = notificationResponse.payload;
        if (payload != null) {
          print('notification payload: $payload');
          // Payload'a göre farklı sayfalara yönlendirme vs. yapılabilir.
        }
      },
    );
    print("FlutterLocalNotificationsPlugin başlatıldı.");
  }

  Future<void> _loadModel() async {
    setState(() {
      _isProcessing = true;
      _predictionResult = "Model yükleniyor...";
    });
    try {
      await _predictor.loadModel();
      if (mounted) {
        setState(() {
          _predictionResult = "Model yüklendi. Tahmin için bir buton seçin.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _predictionResult = "Model yüklenirken hata oluştu: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // _showNotification METODU SINIF İÇİNE TAŞINDI
  Future<void> _showNotification(String message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'irrigation_channel', // kanal ID
      'Sulama Bildirimleri', // kanal adı
      channelDescription: 'Sulama zamanı bildirimleri', // kanal açıklaması
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0, // Bildirim ID
      'Sulama Tahmini', // Bildirim başlığı
      message, // Bildirim içeriği
      platformChannelSpecifics,
      payload: 'irrigation_payload', // Bildirime tıklandığında taşınacak veri
    );
    print("Bildirim gösterilmeye çalışıldı: $message");
  }

  Future<void> _runPredictionWithSampleData() async {
    if (!_predictor.isModelReady) {
      setState(() {
        _predictionResult = "Model henüz hazır değil!";
      });
      return;
    }
    setState(() {
      _isProcessing = true;
      _predictionResult = "Örnek veriyle tahmin yapılıyor...";
    });
    try {
      final result = _predictor.predictIrrigation(
          _sampleHumidity, _sampleTemperature, _samplePh);
      print("Tahmin sonucu: $result. Bildirim gönderiliyor...");
      await _showNotification(result); // Artık sınıfın metodunu çağırıyor
      if (mounted) {
        setState(() {
          _predictionResult = "Örnek Veriyle Tahmin: $result";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _predictionResult = "Örnek veriyle tahmin sırasında hata: $e";
        });
      }
      print("Örnek veriyle tahmin hatası: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _fetchSensorDataAndPredict() async {
    if (!_predictor.isModelReady) {
      setState(() {
        _predictionResult = "Model henüz hazır değil!";
      });
      return;
    }
    setState(() {
      _isProcessing = true;
      _predictionResult = "Firestore'dan veri alınıyor ve tahmin yapılıyor...";
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("sensor_verileri")
          .orderBy("timestamp", descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final double humidity = (data["nem"] as num?)?.toDouble() ?? 0.0;
        final double temperature = (data["sicaklik"] as num?)?.toDouble() ?? 0.0;
        final double ph = (data["ph"] as num?)?.toDouble() ?? 0.0;
        final result = _predictor.predictIrrigation(humidity, temperature, ph);

        print("Firestore Tahmin sonucu: $result. Bildirim gönderiliyor...");
        await _showNotification("Firestore Tahmini: $result (N:$humidity, S:$temperature, pH:$ph)");

        if (mounted) {
          setState(() {
            _predictionResult =
            "Firestore Verisiyle Tahmin: $result\n(Nem: $humidity, Sıcaklık: $temperature, pH: $ph)";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _predictionResult = "Firestore'da sensör verisi bulunamadı.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _predictionResult = "Firestore'dan veri alırken veya tahmin yaparken hata: $e";
        });
      }
      print("Firestore veri alma/tahmin hatası: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _predictor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akıllı Sulama Tahmini'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_predictor.isModelReady)
                Text(
                  'Örnek Veriler (Test için):\nNem: $_sampleHumidity%, Sıcaklık: $_sampleTemperature°C, pH: $_samplePh',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              const SizedBox(height: 20),
              if (_isProcessing)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                  ],
                )
              else if (!_predictor.isModelReady && !_isProcessing)
                ElevatedButton(
                  onPressed: _loadModel,
                  child: const Text('Modeli Yüklemeyi Tekrar Dene'),
                )
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _runPredictionWithSampleData,
                      child: const Text('Örnek Veriyle Tahmin Yap'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _fetchSensorDataAndPredict,
                      child: const Text("Firestore'dan Veri Al ve Tahmin Yap"),
                    ),
                  ],
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
} // _HomeScreenState sınıfının kapanışı

// Argmax extension'ı sınıf dışında kalabilir
extension Argmax on List<double> {
  int argmax() {
    if (isEmpty) {
      print("Argmax için boş liste geldi.");
      return -1;
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
