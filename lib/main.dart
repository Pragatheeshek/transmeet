import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TransMeetApp());
}

class TransMeetApp extends StatelessWidget {
  const TransMeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TransMeet',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('TransMeet'),
        ),
        body: const Center(
          child: Text(
            'Firebase Connected Successfully 🚀',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}