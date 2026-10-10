import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const baseUrl = 'https://transmeet.onrender.com';
  
  try {
    print('Testing transcribe...');
    final uri = Uri.parse('$baseUrl/api/translation/transcribe');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'audio',
        Uint8List(60000), // fake audio
        filename: 'segment.m4a',
      ))
      ..fields['language'] = 'en';

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('Transcribe response: ${response.statusCode} - Body: ${response.body}');
  } catch (e) {
    print('Transcribe failed: $e');
  }
}
