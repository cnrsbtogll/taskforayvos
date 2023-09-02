import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  XFile? _selectedImage; // Kullanıcının seçtiği resim
  String apiKey = ''; // Kullanıcıdan alınacak API anahtarı
  String analysisResult = ''; // Analiz sonuçları

  Future<void> _pickImage() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _selectedImage = XFile(pickedFile.path);
        _analyzeImage(_selectedImage!.path); // Resmi analiz et
      }
    });
  }

  Future<void> _analyzeImage(String imagePath) async {
    try {
      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Encode(File(imagePath).readAsBytesSync())},
              'features': [
                {'type': 'LABEL_DETECTION', 'maxResults': 10},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        final labels = result['responses'][0]['labelAnnotations'];
        setState(() {
          analysisResult = '';
          for (var label in labels) {
            analysisResult += '${label['description']} - ${label['score']}\n';
          }
        });
      } else {
        setState(() {
          analysisResult = 'Analiz başarısız: ${response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        analysisResult = 'Analiz hatası: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiz Et'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          // API Anahtarı Giriş Alanı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal:32.0, vertical: 8.0),
            child: TextFormField(
              decoration: const InputDecoration(labelText: 'API Anahtarınızı giriniz'),
              onChanged: (value) {
                setState(() {
                  apiKey = value;
                });
              },
            ),
          ),

          // Resim Kutusu
          _selectedImage == null
              ? const Text('Resim Seçilmedi')
              : Image.file(
                  File(_selectedImage!.path),
                  width: 200.0,
                  height: 200.0,
                ),
          const SizedBox(height: 20.0),

          // Resim Yükle Düğmesi
          ElevatedButton(
            onPressed: _pickImage,
            child: const Text('Resim Yükle'),
          ),
          
          // Analiz Sonuçları
          Text(analysisResult),
        ],
      ),
    );
  }
}