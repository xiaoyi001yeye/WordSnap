import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wordsnap/features/study/paddle_ocr_service.dart';

void main() {
  test('recognizeImage extracts English words from PaddleOCR response',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('paddle-ocr-test');
    final imageFile = File('${tempDir.path}/sample.jpg');
    await imageFile.writeAsBytes(<int>[1, 2, 3, 4]);

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'http://127.0.0.1:8080/ocr');

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['fileType'], 1);
      expect(body['file'], isNotEmpty);

      return http.Response(
        jsonEncode(<String, dynamic>{
          'result': <String, dynamic>{
            'ocrResults': <Map<String, dynamic>>[
              <String, dynamic>{
                'prunedResult': <String, dynamic>{
                  'rec_texts': <String>[
                    'Natural disasters happen suddenly.',
                    'Wildfire damage and shelter plans.',
                  ],
                  'rec_scores': <double>[0.96, 0.83],
                },
              },
            ],
          },
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });

    final service = PaddleOcrService(client: client);
    final result = await service.recognizeImage(
      imagePath: imageFile.path,
      endpoint: Uri.parse('http://127.0.0.1:8080/ocr'),
    );

    expect(result.lines, hasLength(2));
    expect(result.words.map((item) => item.normalized), contains('natural'));
    expect(result.words.map((item) => item.normalized), contains('wildfire'));
    expect(result.fullText, contains('Natural disasters happen suddenly.'));
    expect(result.averageScore, closeTo(0.895, 0.001));
  });
}
