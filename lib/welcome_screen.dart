import 'package:flutter/material.dart';
import 'auth_screen.dart'; // AuthScreen'i import edin


class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print("WelcomeScreen BUILD method CALLED");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoş Geldiniz'),
        centerTitle: true,
      ),
      body: Center(
        child: Column( // Butonları alt alta sıralamak için Column kullanabilirsiniz
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement( // Veya sadece push, geri dönülebilirlik durumuna göre
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen()), // AuthScreen'e yönlendir
                );
              },
              child: const Text('Giriş Yap / Kayıt Ol'), // Buton metnini güncelleyebilirsiniz
            ),
            // İsterseniz başka butonlar veya bilgiler de ekleyebilirsiniz
          ],
        ),
      ),
    );
  }
}