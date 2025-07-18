import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Firebase başlatılıyor
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Sulama',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const FirebaseCheckScreen(),
    );
  }
}

class FirebaseCheckScreen extends StatefulWidget {
  const FirebaseCheckScreen({super.key});

  @override
  State<FirebaseCheckScreen> createState() => _FirebaseCheckScreenState();
}

class _FirebaseCheckScreenState extends State<FirebaseCheckScreen> {
  String _status = "Firebase kontrol ediliyor...";

  @override
  void initState() {
    super.initState();
    _checkFirebaseConnection();
  }

  Future<void> _checkFirebaseConnection() async {
    try {
      await Firebase.initializeApp();
      setState(() {
        _status = "✅ Firebase bağlantısı başarılı!";
      });
    } catch (e) {
      setState(() {
        _status = "⛔ Firebase bağlantı hatası: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Firebase Bağlantı Testi")),
      body: Center(
        child: Text(
          _status,
          style: const TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
