import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p; // path paketini ekledik
import 'package:path_provider/path_provider.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({Key? key}) : super(key: key);

  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  XFile? _selectedImage;
  String apiKey = '';
  String analysisResult = '';

  Future<void> _pickImage() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _selectedImage = XFile(pickedFile.path);
        saveImageLocally(_selectedImage!);
        _analyzeImage(_selectedImage!.path);
        // Seçilen resmi kaydet
      }
    });
  }

  // Seçilen resmi kaydetmek için kullanılacak fonksiyon
  Future<void> saveImageLocally(XFile selectedImage) async {
    final directory = await getApplicationDocumentsDirectory();
    final newPath = p.join(directory.path, 'selected_image.jpg');
    final File newFile = File(newPath);
    await newFile.writeAsBytes(await selectedImage.readAsBytes());
  }

  Future<void> _analyzeImage(String imagePath) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {
                'content': base64Encode(File(imagePath).readAsBytesSync())
              },
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            // API Anahtarı Giriş Alanı
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
              child: TextFormField(
                decoration: const InputDecoration(
                    labelText: 'API Anahtarınızı giriniz'),
                onChanged: (value) {
                  setState(() {
                    apiKey = value;
                  });
                },
              ),
            ),

            // Resim Kutusu veya Mesaj
            _selectedImage == null
                ? const Text('Resim Seçilmedi')
                : CustomPaint(
                    painter: ImageTextPainter(
                      //imageFilePath: _selectedImage!.path,
                      imageFileBytes:
                          File(_selectedImage!.path).readAsBytesSync(),
                      analysisResult: analysisResult,
                    ),
                    child: Image.file(
                      File(_selectedImage!.path),
                      width: 200.0,
                      height: 200.0,
                    ),
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
      ),
    );
  }
}

class ImageTextPainter extends CustomPainter {
  final Uint8List imageFileBytes;
  final String analysisResult;

  ImageTextPainter({
    required this.imageFileBytes,
    required this.analysisResult,
  });

  @override
  void paint(Canvas canvas, Size size) async {
    try {
      final image = await loadImage(imageFileBytes);
      canvas.drawImage(image, Offset.zero, Paint());
    } catch (e) {
      print('Resim çizme hatası: $e');
    }
    final textStyle = ui.TextStyle(
      color: Colors.black,
      fontSize: 16.0,
    );

    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 16.0,
      ),
    )
      ..pushStyle(textStyle)
      ..addText(analysisResult);

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: size.width));

    canvas.drawParagraph(paragraph, const Offset(16.0, 16.0));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

  Future<ui.Image> loadImage(Uint8List imageFileBytes) async {
    final Completer<ui.Image> completer = Completer();

    ui.decodeImageFromList(imageFileBytes, (ui.Image img) {
      completer.complete(img);
    });

    return completer.future;
  }
}
