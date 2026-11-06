import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

// Port 5001 matches our Express server (macOS reserves 5000 for AirPlay)
const String baseUrl = 'http://10.0.2.2:5001';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String message = 'Press the button to connect';

  Future<void> checkBackend() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      );

      setState(() {
        message = response.body;
      });
    } catch (e) {
      setState(() {
        message = 'Connection failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Backend Connection Test'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(message),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: checkBackend,
                child: const Text('Test API Connection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
