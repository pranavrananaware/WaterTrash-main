import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Required for rootBundle
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:trashhdetection/screens/login_screen.dart';

late Interpreter interpreter;
late List<String> labels;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await requestPermissions();

  try {
    // ✅ Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized!');

    // ✅ Load model
    interpreter = await Interpreter.fromAsset('assets/model_unquant.tflite');
    print('✅ TFLite model loaded!');

    // ✅ Load labels
    final rawLabels = await rootBundle.loadString('assets/wastelabels.txt');
    labels = rawLabels.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    print('✅ Labels loaded: $labels');
  } catch (e) {
    print('❌ Initialization error: $e');
  }

  runApp(MyApp());
}

Future<void> requestPermissions() async {
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    await Permission.camera.request();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    });

    return const Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_damage, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Water Trash Detection',
              style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
