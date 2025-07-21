import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase Core paketini import edin
import 'package:ai_sulama/home_screen.dart';      // HomeScreen'in doğru yolu
import 'welcome_screen.dart';                 // WelcomeScreen'in doğru yolu
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';
// Firebase yapılandırmasını platforma özel olarak yüklemek için FlutterFire CLI tarafından oluşturulan dosya
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("Main: WidgetsFlutterBinding initialized.");

  try {
    print("Main: Attempting to initialize Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Main: Firebase initialized successfully!"); // Bu mesajı görüyor musunuz?
  } catch (e) {
    print("Main: Firebase initialization FAILED: $e"); // Hata varsa bu mesajı ve hatayı görün
    // ÖNEMLİ: Hata durumunda kullanıcıya bilgi verin veya uygulamayı farklı yönetin
    // Şimdilik sadece print ile hata ayıklıyoruz.
  }

  print("Main: Firebase initialization complete (or failed). Running app...");
  runApp(const MyApp());
}
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    print("AuthWrapper: Build method called.");
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print("AuthWrapper StreamBuilder: Connection State - ${snapshot.connectionState}");
        print("AuthWrapper StreamBuilder: Has Data - ${snapshot.hasData}");
        print("AuthWrapper StreamBuilder: Data - ${snapshot.data}");
        print("AuthWrapper StreamBuilder: Has Error - ${snapshot.hasError}");

        if (snapshot.connectionState == ConnectionState.waiting) {
          print("AuthWrapper: Still waiting for Firebase auth state...");
          // Bu durumda WelcomeScreen veya basit bir yükleme ekranı gösterilmeli
          return const WelcomeScreen(); // Veya Scaffold(body: Center(child: CircularProgressIndicator()))
        }
        if (snapshot.hasError) {
          print("AuthWrapper: Firebase auth stream error: ${snapshot.error}");
          return Scaffold(body: Center(child: Text("Hata: ${snapshot.error}")));
        }
        if (snapshot.hasData && snapshot.data != null) {
          print("AuthWrapper: User is logged in. Navigating to HomeScreen.");
          return const HomeScreen();
        }
        print("AuthWrapper: User is not logged in. Navigating to AuthScreen.");
        return const AuthScreen();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print("MyApp BUILD method CALLED"); // Konsolda bu mesajı kontrol edin
    return MaterialApp(
      title: 'AI Sulama Sistemi Test',
      debugShowCheckedModeBanner: false, // İsteğe bağlı
      home: const WelcomeScreen(), // DOĞRUDAN WELCOMESCREEN'İ GÖSTER
    );
  }
}