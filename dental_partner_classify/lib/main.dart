import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/login_page.dart';
import 'features/auth/change_password_page.dart';
import 'services/push_notification_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.initialize();

  await Supabase.initialize(
    url: 'https://rcpmdwvzyfwwlpagetyn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJjcG1kd3Z6eWZ3d2xwYWdldHluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MjUzODcsImV4cCI6MjA5MDIwMTM4N30.sEJ50EkwKLo5P8nmTxJE82vmtzcTCzGHljOSVJDBU7Q',
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
        (_) => false,
      );
    }
  });

  runApp(const DentalNaraApp());
}

class DentalNaraApp extends StatelessWidget {
  const DentalNaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: '치아온 파트너',
      theme: ThemeData(
        primaryColor: const Color(0xFF005A9C),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      home: const LoginPage(),
    );
  }
}