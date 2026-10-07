// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VisionOS client resolves full audio and streams past 1MB', () async {
    final client = HttpClient();

    // 1. Fetch visitorData from https://www.youtube.com/sw.js_data
    final swReq = await client.getUrl(Uri.parse('https://www.youtube.com/sw.js_data'));
    swReq.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
    final swResp = await swReq.close();
    final swBody = await utf8.decodeStream(swResp);
    final cleanJson = swBody.replaceFirst(RegExp(r"^\)\]\}'\s*"), '');
    final dynamic parsed = jsonDecode(cleanJson);
    final String visitorData = parsed[0][2][0][0][13] as String;
    print('Visitor data acquired: ${visitorData.substring(0, 30)}...');

    // 2. Request player info using VisionOS client payload
    final playerReq = await client.postUrl(Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'));
    playerReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    playerReq.headers.set('X-Youtube-Client-Name', '101');
    playerReq.headers.set('X-Youtube-Client-Version', '1.02');
    playerReq.headers.set('Origin', 'https://www.youtube.com');
    playerReq.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15');
    playerReq.headers.set('X-Goog-Visitor-Id', visitorData);

    final payload = {
      'context': {
        'client': {
          'clientName': 'VISIONOS',
          'clientVersion': '1.02',
          'deviceMake': 'Apple',
          'deviceModel': 'RealityDevice17,1',
          'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
          'osName': 'visionOS',
          'osVersion': '26.5.23O471',
          'hl': 'en',
          'visitorData': visitorData,
        }
      },
      'videoId': 'acYUqMd9k2I',
    };

    playerReq.write(jsonEncode(payload));
    final playerResp = await playerReq.close();
    final playerBody = await utf8.decodeStream(playerResp);
    final playerData = jsonDecode(playerBody) as Map<String, dynamic>;

    expect(playerData['playabilityStatus']?['status'], 'OK');

    final formats = (playerData['streamingData']?['adaptiveFormats'] as List<dynamic>?) ?? [];
    final audioFormats = formats.where((f) => (f['mimeType'] as String? ?? '').contains('audio')).toList();
    expect(audioFormats.isNotEmpty, isTrue);

    // Pick highest bitrate audio
    audioFormats.sort((a, b) => ((b['bitrate'] as int?) ?? 0).compareTo((a['bitrate'] as int?) ?? 0));
    final bestAudio = audioFormats.first;
    final streamUrl = Uri.parse(bestAudio['url'] as String);
    print('Resolved audio url: $streamUrl');

    // 3. Test range 1.5MB to 2.0MB (which previously returned 403)
    final rangeReq = await client.getUrl(streamUrl);
    rangeReq.headers.set(HttpHeaders.rangeHeader, 'bytes=1500000-2000000');
    rangeReq.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    final rangeResp = await rangeReq.close();

    expect(rangeResp.statusCode, HttpStatus.partialContent);
    int count = 0;
    await for (final chunk in rangeResp) {
      count += chunk.length;
    }
    print('Streamed $count bytes in range 1.5MB-2.0MB without 403!');
    expect(count, 500001);

    client.close();
  });
}
