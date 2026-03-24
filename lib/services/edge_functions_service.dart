import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class EdgeFunctionsService {
  static const String functionsBaseUrl =
      'https://qjdgfsszmoftzwqabnjw.functions.supabase.co';

  static Future<Map<String, dynamic>> uploadAvatar({
    required String bucket,
    required String path,
    required String contentType,
    required String base64,
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session == null) {
      throw Exception('Sessão inválida. Faça login novamente.');
    }

    final uri = Uri.parse('$functionsBaseUrl/upload-avatar');

    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'bucket': bucket,
        'path': path,
        'contentType': contentType,
        'base64': base64,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Edge Function falhou (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Resposta inválida da Edge Function.');
    }
    return data;
  }
}
