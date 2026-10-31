import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// REST client for the Vision Assistant backend.
class ApiClient {
  ApiClient({required this.baseUrl, required this.apiKey});

  final String baseUrl;
  final String apiKey;
  static const _timeout = Duration(seconds: 25);

  Map<String, String> get _headers => {if (apiKey.isNotEmpty) 'X-API-Key': apiKey};

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse(baseUrl).replace(path: path, queryParameters: q);

  Map<String, dynamic> _json(http.Response r) {
    if (r.statusCode == 401) throw const ApiException('Invalid API key');
    if (r.statusCode >= 400) throw ApiException('Server error ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> health() async =>
      _json(await http.get(_u('/health')).timeout(const Duration(seconds: 6)));

  Future<Map<String, dynamic>> describe(String sid) async => _json(await http
      .get(_u('/api/describe_scene', {'sid': sid}), headers: _headers)
      .timeout(_timeout));

  Future<Map<String, dynamic>> ask(String question, String sid) async => _json(await http
      .get(_u('/api/ask_question', {'q': question, 'sid': sid}), headers: _headers)
      .timeout(_timeout));

  Future<Map<String, dynamic>> registerFaceMulti(String name, List<Uint8List> frames) async {
    final req = http.MultipartRequest('POST', _u('/api/register_face_multi'))
      ..headers.addAll(_headers)
      ..fields['name'] = name;
    for (var i = 0; i < frames.length; i++) {
      req.files.add(http.MultipartFile.fromBytes('files', frames[i], filename: 'face_$i.jpg'));
    }
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    return _json(await http.Response.fromStream(streamed));
  }

  Future<List<String>> listFaces() async {
    final j = _json(await http.get(_u('/api/faces'), headers: _headers).timeout(_timeout));
    return ((j['faces'] as List?) ?? const []).map((e) => e.toString()).toList();
  }

  Future<bool> deleteFace(String name) async {
    final r = await http
        .delete(_u('/api/faces/${Uri.encodeComponent(name)}'), headers: _headers)
        .timeout(_timeout);
    return _json(r)['success'] == true;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
